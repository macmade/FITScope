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

    /// Whether an image with no display function opens with an auto Screen Transfer
    /// applied on open — as an editable adjustment over the unstretched baseline (the
    /// per-format "auto-stretch on open" preference for XISF). A stored display
    /// function always takes priority over auto-stretch.
    private let autoStretch: Bool

    /// Creates a loader for the file at the given URL.
    ///
    /// - Parameters:
    ///   - url:         The URL the file is (or will be) read from.
    ///   - data:        The file's raw bytes when already in memory; when `nil` (the
    ///                 default) the loader reads them from `url` on load.
    ///   - autoStretch: Whether to open an image with no display function with an auto
    ///                 Screen Transfer applied as an editable adjustment over the
    ///                 unstretched baseline. Defaults to `false`.
    public init( url: URL, data: Data? = nil, autoStretch: Bool = false )
    {
        self.url          = url
        self.providedData = data
        self.autoStretch  = autoStretch
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
                ( continuation: CheckedContinuation< [ ( info: XISFImageInfo, source: Swift.Result< any ImageRenderSource, any Swift.Error >, opened: ImageProcessor.Settings? ) ], any Swift.Error > ) in DispatchQueue.global( qos: .userInitiated ).async
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
                            image -> ( info: XISFImageInfo, source: Swift.Result< any ImageRenderSource, any Swift.Error >, opened: ImageProcessor.Settings? ) in

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

                            // The state the image opens in: the display function when
                            // present, else an auto Screen Transfer when the preference is
                            // on, else `nil` (opens unstretched). Derived here, off the
                            // main actor.
                            let opened = Self.openedSettings( for: info, colorSource: ( try? source.get() )?.autoStretchColorSource, autoStretch: self.autoStretch )

                            return ( info: info, source: source, opened: opened )
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

                    let renderer = ImageRenderer( source: frame.source, opened: frame.opened )

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

    /// The state an XISF image opens in, layered over its unstretched baseline, or
    /// `nil` when it opens unstretched.
    ///
    /// The display function takes priority: when the image carries a usable one, it
    /// is mapped onto an editable Screen Transfer stretch, so the image opens as
    /// authored. Otherwise, when the auto-stretch-on-open preference is on, an auto
    /// Screen Transfer is derived from the detection image instead. Returns `nil`
    /// (opens on the unstretched linear baseline) when there is neither — no display
    /// function (or an identity / unusable one) and auto-stretch off — or when the
    /// derivation fails. Either way the image still resets to the unstretched view.
    ///
    /// Both Screen Transfer sources are authored in — and applied in — the format's
    /// native, full-scale `[0, 1]` domain (a PixInsight display function's
    /// shadows / midtones / highlights are fractions of full scale, and the auto-STF
    /// derivation runs over the same full-scale-normalized data). The XISF render
    /// already scales integer samples by their full scale, so ``Processors/Normalize/Mode/identity``
    /// normalization makes the Screen Transfer act on exactly that domain — rather
    /// than the default min/max normalization, which would pre-stretch the data and
    /// distort the stretch.
    ///
    /// - Parameters:
    ///   - info:        The image's metadata snapshot.
    ///   - colorSource: The image's per-channel colour input, for the auto-stretch
    ///                  fallback (a colour frame derives a per-channel STF, a mono
    ///                  frame a uniform one).
    ///   - autoStretch: Whether auto-stretch on open is enabled.
    /// - Returns: The opened settings, or `nil` to open on the unstretched baseline.
    private nonisolated static func openedSettings( for info: XISFImageInfo, colorSource: ImageProcessor.AutoStretchColorSource?, autoStretch: Bool ) -> ImageProcessor.Settings?
    {
        // A stored display function always wins over auto-stretch (Milestone 4).
        if let displayFunction = info.imageProperties.displayFunction,
           let stf             = Processors.Stretch.STFParameters( displayFunction: displayFunction, colorSpace: info.imageProperties.colorSpace )
        {
            return ImageProcessor.Settings( normalize: .identity, stretch: stf )
        }

        // Otherwise fall back to an auto Screen Transfer when enabled — a per-channel
        // one for colour, uniform for mono — in the format's own domain: full-scale for
        // an integer sample format, min/max for a floating-point one (no fixed full
        // scale).
        guard autoStretch
        else
        {
            return nil
        }

        let domain = ImageProcessor.xisfFullScale( info.imageProperties.sampleFormat ).map { ImageProcessor.AutoStretchDomain.fullScale( $0 ) } ?? .minMax

        return ImageProcessor.autoStretchSettings( colorSource: colorSource, domain: domain )
    }

    /// Builds the detection-ready single-channel linear image for an XISF image,
    /// matching the FITS and RAW loaders: a colour-filter-array frame is
    /// demosaiced to a luminance channel via `BayerGrayscaleConverter`
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
              let pattern     = try? ColorFilterArray.pattern( named: cfaPattern )
        else
        {
            return buffer
        }

        return ( try? BayerGrayscaleConverter( pattern: pattern ).grayscale( from: buffer ) ) ?? buffer
    }
}
