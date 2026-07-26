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

                            try Self.renderSource( file: file )
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
    /// When the auto-stretch-on-open preference is on, an auto Screen Transfer is
    /// derived — a per-channel one for a colour-filter-array sensor, uniform for a
    /// monochrome one — so the image opens stretched with the parameters pre-filled and
    /// editable in the inspector, while still resetting to the unstretched linear view.
    /// It is derived in the sensor's own domain: the native full-scale `[0, 1]` domain
    /// when a white level is known, or the min/max domain otherwise. Returns `nil`
    /// (opens linear) when the preference is off or the derivation fails.
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
        guard autoStretch
        else
        {
            return nil
        }

        let domain = info.imageProperties.whiteLevel.map { ImageProcessor.AutoStretchDomain.fullScale( $0 ) } ?? .minMax

        return ImageProcessor.autoStretchSettings( colorSource: colorSource, domain: domain )
    }

    /// Builds the render source for an unpacked RAW file through the shared
    /// ``RAWImageDecoder``: it enumerates the single frame (rejecting a sensor layout
    /// it cannot read), crops the 16-bit Bayer buffer to the visible area, and builds
    /// the detection image — so the rendered bytes and the detection input are exactly
    /// the ones the library's star detection validates against.
    ///
    /// - Parameter file: The opened, unpacked RAW file.
    /// - Returns: The RAW render source.
    /// - Throws: ``SwiftAstro/Error`` for an unsupported sensor layout (a non-Bayer
    ///   buffer, or an X-Trans mosaic the 2×2 debayer cannot describe), or truncated
    ///   sensor data.
    private nonisolated static func renderSource( file: RAWFile ) throws -> any ImageRenderSource
    {
        // `frames( in: )` yields exactly one frame or throws (an unsupported sensor
        // layout throws there); the guard is a defensive unwrap of `first`.
        guard let frame = try RAWImageDecoder.frames( in: file ).first
        else
        {
            throw RuntimeError( message: "The RAW file holds no decodable image." )
        }

        let ( bytes, properties ) = try RAWImageDecoder.contents( of: frame )
        let detectionImage        = RAWImageDecoder.detectionImage( bytes: bytes, properties: properties )

        return RAWRenderSource( data: bytes, properties: properties, detectionImage: detectionImage )
    }
}
