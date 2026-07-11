/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the Software), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import Combine
import Foundation
import SwiftAstro
import SwiftPixel
import SwiftRAW
import SwiftUtilities

/// Asynchronously decodes a camera RAW file (CR3, CR2, NEF, ARW, DNG, …) into a
/// single ``LoadedImage``, publishing the result or the failure for a view to
/// observe. Mirrors ``XISFImageLoader`` / ``ImageIOImageLoader``.
///
/// Decoding happens off the main actor via SwiftRAW's `RAWFile` (LibRAW); the
/// non-`Sendable` file is opened, unpacked, cropped and released entirely in the
/// background, so only the `Sendable` per-image info and render source cross back.
///
/// A RAW file is a linear, undemosaiced sensor mosaic — an astro light frame — so,
/// unlike the photographic ImageIO path, each frame opens with the default (min/max)
/// baseline and is displayed exactly as a colour-filter-array FITS sub: debayered,
/// then stretched by the user.
@MainActor
public class RAWImageLoader: ObservableObject, ImageLoading
{
    /// The successfully loaded image, or `nil` before loading or after a failure.
    @Published public private( set ) var image: LoadedImage?

    /// The error from the most recent failed load, or `nil` on success.
    @Published public private( set ) var error: ( any Swift.Error )?

    /// Emits the loaded image on every change, bridging the `@Published` ``image``
    /// projection to the ``ImageLoading`` protocol so it can be observed through
    /// `any ImageLoading`.
    public var imagePublisher: AnyPublisher< LoadedImage?, Never >
    {
        self.$image.eraseToAnyPublisher()
    }

    /// The URL the file is (or will be) read from, retained for metadata.
    private let url: URL

    /// The file's raw bytes when supplied already in memory (e.g. by tests). `nil`
    /// when the loader reads them from ``url`` itself.
    private let providedData: Data?

    /// Forwards the loaded image's change notifications to this object's observers.
    private var imageObserver: AnyCancellable?

    /// Whether the image opens with an auto Screen Transfer applied on open — as an
    /// editable adjustment over the unstretched baseline (the per-format "auto-stretch
    /// on open" preference for RAW).
    private let autoStretch: Bool

    /// Creates a loader for the file at the given URL.
    ///
    /// - Parameters:
    ///   - url:         The URL the file is (or will be) read from.
    ///   - data:        The file's raw bytes when already in memory; when `nil` (the
    ///                 default) the loader reads them from `url` on load.
    ///   - autoStretch: Whether to open the image with an auto Screen Transfer applied
    ///                 as an editable adjustment over the unstretched baseline.
    ///                 Defaults to `false`.
    public init( url: URL, data: Data? = nil, autoStretch: Bool = false )
    {
        self.url          = url
        self.providedData = data
        self.autoStretch  = autoStretch
        self.image        = nil
    }

    /// Parses the file's bytes and publishes the resulting image, or the error on
    /// failure.
    ///
    /// Successful loads are cached: a repeated call once an image exists is a no-op,
    /// while a prior failure still retries.
    public func load() async
    {
        if self.image != nil, self.error == nil
        {
            return
        }

        do
        {
            let frame = try await withCheckedThrowingContinuation
            {
                ( continuation: CheckedContinuation< ( info: RAWImageInfo, source: Swift.Result< any ImageRenderSource, any Swift.Error >, opened: ImageProcessor.Settings? ), any Swift.Error > ) in DispatchQueue.global( qos: .userInitiated ).async
                {
                    do
                    {
                        // Open, unpack, crop and release the RAWFile entirely here: only
                        // the Sendable info and render source cross back to the main
                        // actor, so the non-Sendable file never escapes the background.
                        let data: Data

                        if let providedData = self.providedData
                        {
                            data = providedData
                        }
                        else
                        {
                            let didAccess = self.url.startAccessingSecurityScopedResource()

                            defer
                            {
                                if didAccess
                                {
                                    self.url.stopAccessingSecurityScopedResource()
                                }
                            }

                            data = try Data( contentsOf: self.url )
                        }

                        let file = try RAWFile( data: data )
                        let info = RAWImageInfo( url: self.url, file: file )

                        // Build the render source while the file is in scope; a decode
                        // failure (an unsupported sensor layout) must not fail the load,
                        // so it is captured and surfaces at render, leaving the metadata.
                        let source = Swift.Result
                        {
                            () -> any ImageRenderSource in

                            try Self.renderSource( file: file, info: info )
                        }

                        // The state the image opens in: an auto Screen Transfer when the
                        // preference is on, else `nil` (opens on the unstretched linear
                        // baseline). Derived here, off the main actor, from the source's
                        // per-channel colour input.
                        let opened = Self.openedSettings( for: info, colorSource: ( try? source.get() )?.autoStretchColorSource, autoStretch: self.autoStretch )

                        continuation.resume( returning: ( info: info, source: source, opened: opened ) )
                    }
                    catch
                    {
                        continuation.resume( throwing: error )
                    }
                }
            }

            await MainActor.run
            {
                let renderer = ImageRenderer( source: frame.source, opened: frame.opened )
                let loaded   = LoadedImage( rawInfo: frame.info, renderer: renderer )

                self.image         = loaded
                self.error         = nil
                self.imageObserver = loaded.objectWillChange.sink
                {
                    [ weak self ] _ in self?.objectWillChange.send()
                }
            }
        }
        catch
        {
            self.image         = nil
            self.error         = error
            self.imageObserver = nil
        }
    }

    /// The state a RAW image opens in, layered over its unstretched baseline, or
    /// `nil` when it opens unstretched.
    ///
    /// When the auto-stretch-on-open preference is on and the sensor reports a white
    /// level, an auto Screen Transfer is derived from the detection image — in the
    /// native full-scale `[0, 1]` domain the render scales the sensor counts into —
    /// so the image opens stretched with the parameters pre-filled and editable in
    /// the inspector, while still resetting to the unstretched linear view. Returns
    /// `nil` (opens linear) when the preference is off, the sensor has no white level,
    /// or the derivation fails.
    ///
    /// - Parameters:
    ///   - info:        The image's metadata snapshot.
    ///   - colorSource: The image's per-channel colour input (a colour-filter-array
    ///                  sensor derives a per-channel STF, a monochrome sensor a
    ///                  uniform one).
    ///   - autoStretch: Whether auto-stretch on open is enabled.
    /// - Returns: The opened settings, or `nil` to open on the unstretched baseline.
    private nonisolated static func openedSettings( for info: RAWImageInfo, colorSource: ImageProcessor.AutoStretchColorSource?, autoStretch: Bool ) -> ImageProcessor.Settings?
    {
        guard autoStretch, let whiteLevel = info.imageProperties.whiteLevel
        else
        {
            return nil
        }

        return ImageProcessor.autoStretchSettings( colorSource: colorSource, fullScale: whiteLevel )
    }

    /// Builds the render source for an unpacked RAW file: crops the sensor's 16-bit
    /// Bayer buffer to the visible area and builds the detection image.
    ///
    /// - Parameters:
    ///   - file: The opened, unpacked RAW file.
    ///   - info: The file's metadata snapshot (holding the cropped layout).
    /// - Returns: The RAW render source.
    /// - Throws: ``RuntimeError`` for an unsupported sensor layout (a non-Bayer
    ///   buffer, or an X-Trans mosaic the 2×2 debayer cannot describe), or truncated
    ///   sensor data.
    private nonisolated static func renderSource( file: RAWFile, info: RAWImageInfo ) throws -> any ImageRenderSource
    {
        guard file.sensorData.layout == .bayer
        else
        {
            throw RuntimeError( message: "Unsupported RAW sensor layout: \( file.sensorData.layout ). Only a 16-bit Bayer/monochrome mosaic can be rendered." )
        }

        guard file.cfaPattern.kind != .xTrans
        else
        {
            throw RuntimeError( message: "X-Trans RAW sensors are not supported." )
        }

        guard let bytes = Self.croppedMosaic( file: file, sizes: file.imageSizes )
        else
        {
            throw RuntimeError( message: "The RAW sensor mosaic could not be read." )
        }

        let detectionImage = Self.detectionImage( bytes: bytes, properties: info.imageProperties )

        return RAWRenderSource( data: bytes, properties: info.imageProperties, detectionImage: detectionImage )
    }

    /// Crops the sensor's full 16-bit Bayer buffer to the visible area, dropping the
    /// optical-black margins, into a tightly-packed row-major mosaic in host byte
    /// order.
    ///
    /// - Parameters:
    ///   - file:  The unpacked RAW file.
    ///   - sizes: The image geometry (visible dimensions, margins, and row pitch).
    /// - Returns: The cropped mosaic bytes, or `nil` for an invalid geometry or a
    ///   buffer too small to hold the visible area.
    private nonisolated static func croppedMosaic( file: RAWFile, sizes: RAWImageSizes ) -> Data?
    {
        let width         = sizes.width
        let height        = sizes.height
        let samplesPerRow = sizes.rawPitch / 2

        guard width > 0, height > 0, sizes.leftMargin >= 0, sizes.topMargin >= 0, samplesPerRow >= sizes.leftMargin + width
        else
        {
            return nil
        }

        // The vertical bound is enforced against the real buffer length below, once
        // the zero-copy sensor buffer is in scope.

        return file.withRawImage
        {
            ( buffer: UnsafeBufferPointer< UInt16 > ) -> Data? in

            let lastSample = ( sizes.topMargin + height - 1 ) * samplesPerRow + sizes.leftMargin + width

            guard lastSample <= buffer.count, let base = buffer.baseAddress
            else
            {
                return nil
            }

            var mosaic = [ UInt16 ]()

            mosaic.reserveCapacity( width * height )

            ( 0 ..< height ).forEach
            {
                row in

                let start = ( sizes.topMargin + row ) * samplesPerRow + sizes.leftMargin

                mosaic.append( contentsOf: UnsafeBufferPointer( start: base + start, count: width ) )
            }

            return mosaic.withUnsafeBytes { Data( $0 ) }
        } ?? nil
    }

    /// Builds the detection-ready single-channel linear image for a RAW mosaic,
    /// mirroring the XISF/FITS detection input: a colour-filter-array mosaic is
    /// demosaiced to a luminance channel via `BayerGrayscaleConverter` (feeding a raw
    /// mosaic to the detector would inject the Bayer grid as false structure), while a
    /// monochrome sensor is already a single luminance channel and is used directly.
    /// Best-effort: any failure returns `nil`, so the load still succeeds and detection
    /// is simply skipped.
    ///
    /// - Parameters:
    ///   - bytes:      The cropped mosaic's raw bytes.
    ///   - properties: The image's pixel layout.
    /// - Returns: The detection image, or `nil` when it cannot be built.
    private nonisolated static func detectionImage( bytes: Data, properties: RAWImageProperties ) -> PixelBuffer?
    {
        guard let luminance = ImageProcessor.rawImageLinearLuminance( data: bytes, properties: properties ),
              let buffer    = try? PixelBuffer( width: luminance.width, height: luminance.height, channels: 1, pixels: luminance.samples, isNormalized: false )
        else
        {
            return nil
        }

        guard let cfaPattern = properties.colorFilterArrayPattern,
              let pattern     = try? ImageProcessor.debayerPattern( named: cfaPattern )
        else
        {
            return buffer
        }

        return ( try? BayerGrayscaleConverter( pattern: pattern ).grayscale( from: buffer ) ) ?? buffer
    }
}
