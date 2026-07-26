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
import ImageIO
import SwiftAstro
import SwiftPixel
import SwiftUtilities

/// Asynchronously decodes a photographic image (TIFF, PNG, JPEG, and — through the
/// same ImageIO path — RAW and HEIC) into one ``LoadedImage`` per contained image,
/// publishing the result or the failure for a view to observe. Mirrors
/// ``XISFImageLoader`` / ``FITSImageLoader``.
///
/// Decoding happens off the main actor through the shared ``BitmapImageDecoder``,
/// which enumerates the source's frames and draws each non-`Sendable` `CGImage` into
/// a canonical bitmap there, so only the `Sendable` per-image info and render sources
/// cross back.
///
/// Because photographic images are already display-encoded, each frame's renderer
/// is seeded with an *as-authored* baseline (the identity normalization), so it
/// opens showing the image exactly as stored rather than range-stretched like the
/// linear FITS/XISF paths.
@MainActor
public class ImageIOImageLoader: ObservableObject, ImageLoading
{
    /// The successfully loaded image, or `nil` before loading or after a failure.
    /// For a multi-image file this is the primary (first) image; ``frames`` holds the
    /// full list.
    @Published public private( set ) var image: LoadedImage?

    /// The frames the file decoded into, in document order — one per contained image.
    /// A single-image file (the common case) vends exactly one; a multi-image file
    /// (e.g. a multi-page TIFF) vends one per image, surfaced in the carousel. Empty
    /// before loading or after a failure. Overrides the ``ImageLoading`` single-frame
    /// default with the real, decoded frame list.
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

    /// The as-authored baseline seeded into each photographic frame's renderer:
    /// the identity normalization, so the image opens showing its stored values
    /// unchanged rather than range-stretched.
    private static let asAuthoredDefaults: ImageProcessor.Settings =
    {
        // A photographic image is already-processed content, not raw sensor data,
        // so cosmetic correction (a hot/cold pixel repair) is off by default here —
        // it stays on by default only for FITS / XISF / RAW. The user can still turn
        // it on for a photo; the conservative default thresholds are preserved.
        var cosmeticCorrection = Processors.CosmeticCorrection.Parameters.default

        cosmeticCorrection.isEnabled = false

        return ImageProcessor.Settings( normalize: .identity, cosmeticCorrection: cosmeticCorrection )
    }()

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
                ( continuation: CheckedContinuation< [ ( info: ImageIOImageInfo, source: Swift.Result< any ImageRenderSource, any Swift.Error > ) ], any Swift.Error > ) in DispatchQueue.global( qos: .userInitiated ).async
                {
                    do
                    {
                        // Decode entirely here: only the Sendable per-image info and
                        // render sources cross back to the main actor, so the
                        // non-Sendable CGImageSource/CGImage are released when this
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

                        guard let source = CGImageSourceCreateWithData( data as CFData, nil )
                        else
                        {
                            throw RuntimeError( message: "The image could not be read." )
                        }

                        let frames = try BitmapImageDecoder.frames( in: source ).map
                        {
                            frame -> ( info: ImageIOImageInfo, source: Swift.Result< any ImageRenderSource, any Swift.Error > ) in

                            let properties = CGImageSourceCopyPropertiesAtIndex( source, frame.index, nil ) as? [ String: Any ] ?? [ : ]
                            let info       = ImageIOImageInfo( url: self.url, properties: properties, frameTitle: nil )

                            // Decode the pixels (and build the detection luminance)
                            // here, while the non-Sendable CGImageSource is in scope;
                            // only the Sendable render source crosses back. A decode
                            // failure must not fail the load, so it is captured and
                            // surfaces at render.
                            let renderSource = Swift.Result
                            {
                                () -> any ImageRenderSource in

                                let ( bytes, layout ) = try BitmapImageDecoder.contents( of: frame )
                                let detectionImage    = BitmapImageDecoder.detectionImage( bytes: bytes, properties: layout )

                                return BitmapRenderSource( data: bytes, properties: layout, detectionImage: detectionImage )
                            }

                            return ( info: info, source: renderSource )
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
                // Each image is an independent LoadedImage over its own render source,
                // seeded with the as-authored baseline. The primary frame is the
                // first, and the loader forwards only its changes — the owning
                // OpenFile observes the selected frame separately.
                let loaded = frames.map
                {
                    frame -> LoadedImage in

                    let renderer = ImageRenderer( source: frame.source, defaults: Self.asAuthoredDefaults )

                    return LoadedImage( imageIOInfo: frame.info, renderer: renderer )
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
}
