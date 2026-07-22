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
import CoreGraphics
import CoreImage
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
/// Decoding happens off the main actor via `CGImageSource`; the non-`Sendable`
/// `CGImage` is drawn into a canonical bitmap there, and only the `Sendable`
/// per-image info and render sources cross back.
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

                        guard let source = CGImageSourceCreateWithData( data as CFData, nil ), CGImageSourceGetCount( source ) > 0
                        else
                        {
                            throw RuntimeError( message: "The image could not be read." )
                        }

                        let frames = ( 0 ..< CGImageSourceGetCount( source ) ).map
                        {
                            index -> ( info: ImageIOImageInfo, source: Swift.Result< any ImageRenderSource, any Swift.Error > ) in

                            let properties = CGImageSourceCopyPropertiesAtIndex( source, index, nil ) as? [ String: Any ] ?? [ : ]
                            let info       = ImageIOImageInfo( url: self.url, properties: properties, frameTitle: nil )

                            // Decode the pixels (and build the detection luminance)
                            // here, while the non-Sendable CGImage is in scope; only
                            // the Sendable render source crosses back. A decode failure
                            // must not fail the load, so it is captured and surfaces at
                            // render.
                            let renderSource = Swift.Result
                            {
                                () -> any ImageRenderSource in

                                guard let cgImage = CGImageSourceCreateImageAtIndex( source, index, nil )
                                else
                                {
                                    throw RuntimeError( message: "The image could not be decoded." )
                                }

                                let orientation    = ( properties[ kCGImagePropertyOrientation as String ] as? NSNumber )?.intValue ?? 1
                                let decoded        = try Self.decode( cgImage, orientation: orientation )
                                let detectionImage = Self.detectionImage( bytes: decoded.bytes, properties: decoded.properties )

                                return ImageIORenderSource( data: decoded.bytes, properties: decoded.properties, detectionImage: detectionImage )
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

    /// Draws a decoded `CGImage` into a canonical, tightly-packed bitmap and captures
    /// its layout, so the non-`Sendable` image need not cross the render concurrency
    /// boundary.
    ///
    /// A grayscale image is drawn as a single channel; any other colour model is
    /// drawn as `RGBX` in the sRGB space (the fourth component is unused padding
    /// CoreGraphics requires). A source deeper than 8 bits per component is preserved
    /// at 16 bits, stored little-endian to match the host byte order the decoder
    /// reads. Alpha is not composited — the raw colour components are taken — so an
    /// opaque image (the common case) is reproduced exactly.
    ///
    /// - Parameters:
    ///   - cgImage:     The decoded image.
    ///   - orientation: The image's EXIF orientation (`1`...`8`); the image is rotated
    ///                 or flipped to upright before it is drawn, so a portrait phone
    ///                 photo displays the right way up.
    /// - Returns: The canonical layout and its bytes.
    /// - Throws: ``RuntimeError`` for invalid dimensions or a bitmap context that
    ///   cannot be created.
    private nonisolated static func decode( _ cgImage: CGImage, orientation: Int = 1 ) throws -> ( properties: BitmapImageProperties, bytes: Data )
    {
        let image  = Self.upright( cgImage, orientation: orientation )
        let width  = image.width
        let height = image.height

        guard width > 0, height > 0
        else
        {
            throw RuntimeError( message: "Invalid image dimensions: \( width ) × \( height )." )
        }

        let isColor            = ( image.colorSpace?.model ?? .rgb ) != .monochrome
        let bytesPerComponent  = image.bitsPerComponent > 8 ? 2 : 1
        let channelCount       = isColor ? 3 : 1
        let componentsPerPixel = isColor ? 4 : 1
        let bitsPerComponent   = bytesPerComponent * 8
        let bytesPerRow        = width * componentsPerPixel * bytesPerComponent
        let colorSpace         = isColor ? ( CGColorSpace( name: CGColorSpace.sRGB ) ?? CGColorSpaceCreateDeviceRGB() ) : CGColorSpaceCreateDeviceGray()
        var bitmapInfo         = ( isColor ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.none ).rawValue

        if bytesPerComponent >= 2
        {
            bitmapInfo |= CGBitmapInfo.byteOrder16Little.rawValue
        }

        var buffer = [ UInt8 ]( repeating: 0, count: bytesPerRow * height )
        let drew   = buffer.withUnsafeMutableBytes
        {
            ( raw: UnsafeMutableRawBufferPointer ) -> Bool in

            guard let base = raw.baseAddress,
                  let context = CGContext( data: base, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo )
            else
            {
                return false
            }

            context.draw( image, in: CGRect( x: 0, y: 0, width: width, height: height ) )

            return true
        }

        guard drew
        else
        {
            throw RuntimeError( message: "The image could not be drawn into a bitmap context." )
        }

        let properties = BitmapImageProperties( width: width, height: height, channelCount: channelCount, componentsPerPixel: componentsPerPixel, bytesPerComponent: bytesPerComponent )

        return ( properties, Data( buffer ) )
    }

    /// Returns the image rotated/flipped to upright per its EXIF orientation, so a
    /// portrait phone photo (a non-`1` orientation, common in HEIC and JPEG) displays
    /// the right way up rather than sideways.
    ///
    /// An orientation of `1` (the default and overwhelmingly common case) is returned
    /// unchanged, so ordinary images take the exact same path as before. Any other
    /// orientation is applied via Core Image's canonical `oriented(forExifOrientation:)`,
    /// preserving the source's bit depth (a deeper-than-8-bit source stays 16-bit). If
    /// the transform cannot be rendered, the original image is returned unchanged.
    ///
    /// - Parameters:
    ///   - cgImage:     The decoded image, in its stored pixel orientation.
    ///   - orientation: The EXIF orientation (`1`...`8`).
    /// - Returns: The uprighted image, or `cgImage` when no transform applies.
    private nonisolated static func upright( _ cgImage: CGImage, orientation: Int ) -> CGImage
    {
        guard ( 2 ... 8 ).contains( orientation )
        else
        {
            return cgImage
        }

        let oriented   = CIImage( cgImage: cgImage ).oriented( forExifOrientation: Int32( orientation ) )
        let colorSpace = cgImage.colorSpace ?? ( CGColorSpace( name: CGColorSpace.sRGB ) ?? CGColorSpaceCreateDeviceRGB() )
        let format     = cgImage.bitsPerComponent > 8 ? CIFormat.RGBA16 : CIFormat.RGBA8

        guard let uprighted = CIContext().createCGImage( oriented, from: oriented.extent, format: format, colorSpace: colorSpace )
        else
        {
            return cgImage
        }

        return uprighted
    }

    /// Builds the detection-ready single-channel linear image for a photographic
    /// image (the mean of its channels), mirroring the FITS/XISF detection input so
    /// star detection and the sky-background measurement run identically. Best-effort:
    /// any failure returns `nil`, so the load still succeeds and detection is skipped.
    ///
    /// - Parameters:
    ///   - bytes:      The image's decoded pixel bytes.
    ///   - properties: The image's pixel layout.
    /// - Returns: The detection image, or `nil` when it cannot be built.
    private nonisolated static func detectionImage( bytes: Data, properties: BitmapImageProperties ) -> PixelBuffer?
    {
        guard let luminance = ImageProcessor.imageIOLinearLuminance( data: bytes, properties: properties )
        else
        {
            return nil
        }

        return try? PixelBuffer( width: luminance.width, height: luminance.height, channels: 1, pixels: luminance.samples, isNormalized: false )
    }
}
