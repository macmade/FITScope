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
import SwiftUtilities
import SwiftXISF

/// Asynchronously parses an XISF file's bytes into one ``LoadedImage`` per contained
/// image, publishing the result or the failure for a view to observe. Mirrors
/// ``FITSImageLoader``.
///
/// Parsing happens off the main actor; only the `Sendable` per-image info and render
/// sources cross back, so the non-`Sendable` `XISFFile` never escapes the background
/// work.
@MainActor
public class XISFImageLoader: ObservableObject, ImageLoading
{
    /// The successfully loaded image, or `nil` before loading or after a failure.
    /// For a multi-image file this is the primary (first) image; ``frames`` holds the
    /// full list.
    @Published public private( set ) var image: LoadedImage?

    /// The frames the file decoded into, in document order — one per contained image.
    /// A single-image file vends exactly one; a multi-image file vends one per image,
    /// surfaced in the carousel. Empty before loading or after a failure. Overrides
    /// the ``ImageLoading`` single-frame default with the real, decoded frame list.
    @Published public private( set ) var frames: [ LoadedImage ] = []

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

    /// Creates a loader for the file at the given URL.
    ///
    /// - Parameters:
    ///   - url:  The URL the file is (or will be) read from.
    ///   - data: The file's raw bytes when already in memory; when `nil` (the
    ///          default) the loader reads them from `url` on load.
    public init( url: URL, data: Data? = nil )
    {
        self.url          = url
        self.providedData = data
        self.image        = nil
    }

    /// Parses the file's bytes and publishes the resulting images, or the error on
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
            let frames = try await withCheckedThrowingContinuation
            {
                ( continuation: CheckedContinuation< [ ( info: XISFImageInfo, source: Swift.Result< any ImageRenderSource, any Swift.Error > ) ], any Swift.Error > ) in DispatchQueue.global( qos: .userInitiated ).async
                {
                    do
                    {
                        // Build and consume the XISFFile entirely here: only the
                        // Sendable per-image info and render sources cross back to the
                        // main actor, so the non-Sendable file is released when this
                        // closure returns rather than living for the window.
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

                        let file = try XISFFile( data: data, options: .lenient )

                        guard file.images.isEmpty == false
                        else
                        {
                            throw RuntimeError( message: "XISF file contains no image" )
                        }

                        let frames = file.images.map
                        {
                            image -> ( info: XISFImageInfo, source: Swift.Result< any ImageRenderSource, any Swift.Error > ) in

                            let info = XISFImageInfo( url: self.url, file: file, image: image )

                            // Decode the pixels (and build the detection luminance)
                            // here, while the non-Sendable image is in scope; only the
                            // Sendable render source crosses back. A decode failure must
                            // not fail the load, so it is captured and surfaces at render.
                            let source = Swift.Result
                            {
                                () -> any ImageRenderSource in

                                let properties     = info.imageProperties
                                let bytes          = try image.data
                                let detectionImage = Self.detectionImage( bytes: bytes, properties: properties )

                                return XISFRenderSource( data: bytes, properties: properties, detectionImage: detectionImage )
                            }

                            return ( info: info, source: source )
                        }

                        continuation.resume( returning: frames )
                    }
                    catch
                    {
                        continuation.resume( throwing: error )
                    }
                }
            }

            await MainActor.run
            {
                // Each image is an independent LoadedImage over its own render source.
                // The primary frame is the first, and the loader forwards only its
                // changes — the owning OpenFile observes the selected frame separately.
                let loaded = frames.map
                {
                    frame -> LoadedImage in

                    let renderer = ImageRenderer( source: frame.source, defaults: Self.baseline( for: frame.info ) )

                    return LoadedImage( xisfInfo: frame.info, renderer: renderer )
                }

                let primary        = loaded.first
                self.frames        = loaded
                self.image         = primary
                self.error         = nil
                self.imageObserver = primary?.objectWillChange.sink
                {
                    [ weak self ] _ in self?.objectWillChange.send()
                }
            }
        }
        catch
        {
            self.image         = nil
            self.frames        = []
            self.error         = error
            self.imageObserver = nil
        }
    }

    /// The baseline settings an XISF image opens on.
    ///
    /// When the image carries a usable display function, that display function is
    /// mapped onto an editable Screen Transfer stretch and seeded as the baseline,
    /// so the image opens as authored and the stretch is pre-filled and editable in
    /// the inspector. An image with no display function — or one whose display
    /// function is the identity or otherwise unusable — opens on the default linear
    /// baseline instead.
    ///
    /// A stored display function is authored in the format's native, full-scale
    /// `[0, 1]` domain (a PixInsight display function's shadows / midtones /
    /// highlights are fractions of full scale), not the data's min/max range. The
    /// XISF render already scales integer samples by their full scale, so seeding
    /// ``Processors/Normalize/Mode/identity`` normalization makes the Screen
    /// Transfer act on exactly that domain, reproducing the authored rendering —
    /// rather than the default min/max normalization, which would pre-stretch the
    /// data and distort the display function.
    ///
    /// - Parameter info: The image's metadata snapshot.
    /// - Returns: The baseline settings to open the image with.
    private static func baseline( for info: XISFImageInfo ) -> ImageProcessor.Settings
    {
        guard let displayFunction = info.imageProperties.displayFunction,
              let stf             = Processors.Stretch.STFParameters( displayFunction: displayFunction, colorSpace: info.imageProperties.colorSpace )
        else
        {
            return ImageProcessor.Settings()
        }

        return ImageProcessor.Settings( normalize: .identity, stretch: stf )
    }

    /// Builds the detection-ready single-channel linear image for an XISF image,
    /// mirroring `SwiftAstro.FITSImageDecoder.detectionImage`: a colour-filter-array
    /// frame is demosaiced to a luminance channel via `BayerGrayscaleConverter`
    /// (feeding a raw mosaic to the detector would inject the Bayer grid as false
    /// structure), while a grayscale or RGB frame is already luminance and is used
    /// directly. Best-effort: any failure returns `nil`, so the load still succeeds
    /// and detection is simply skipped.
    ///
    /// - Parameters:
    ///   - bytes:      The image's raw pixel bytes.
    ///   - properties: The image's pixel layout.
    /// - Returns: The detection image, or `nil` when it cannot be built.
    private nonisolated static func detectionImage( bytes: Data, properties: XISFImageProperties ) -> PixelBuffer?
    {
        guard let luminance = ImageProcessor.xisfLinearLuminance( data: bytes, properties: properties ),
              let buffer    = try? PixelBuffer( width: luminance.width, height: luminance.height, channels: 1, pixels: luminance.samples, isNormalized: false )
        else
        {
            return nil
        }

        // A colour-filter-array frame is demosaiced to a luminance channel before
        // detection, as the FITS path does; a grayscale or RGB frame is already a
        // single luminance channel and needs no demosaicing.
        guard let cfaPattern = properties.colorFilterArrayPattern,
              let pattern     = try? ImageProcessor.debayerPattern( named: cfaPattern )
        else
        {
            return buffer
        }

        return ( try? BayerGrayscaleConverter( pattern: pattern ).grayscale( from: buffer ) ) ?? buffer
    }
}
