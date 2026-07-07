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

import CoreGraphics
import Foundation
import SwiftFITS
import SwiftPixel
import SwiftUtilities

/// Turns an image's raw bytes into a displayable `CGImage`, driving the
/// `SwiftPixel` pipeline.
///
/// A namespace of static functions and the value types describing the user's
/// render choices; it holds no state. The current input entry,
/// ``render(data:properties:settings:)``, is FITS-facing (it takes the header
/// keywords as `[FITSPropertySnapshot]`) and delegates to a private,
/// format-agnostic core that consumes only the decoded bytes and pipeline config.
public enum ImageProcessor
{
    /// The user's debayering choice, independent of the file's `BAYERPAT`.
    public enum DebayerSelection: Sendable, Equatable
    {
        /// Do not debayer; treat the image as monochrome.
        case none

        /// Use the Bayer pattern declared in the file header, if any.
        case auto

        /// Force a specific Bayer pattern, overriding the header.
        case pattern( Processors.Debayer.Pattern )
    }

    /// The user-tunable pipeline parameters, as a `Sendable` snapshot.
    ///
    /// The defaults render the file as captured: a linear min/max normalization
    /// so the data is visible, with no stretch or white balance. Only debayering
    /// (when the file is a colour-filter array) is applied.
    public struct Settings: Sendable, Equatable
    {
        /// How to normalize pixel values, or `nil` to skip normalization.
        public var normalize: Processors.Normalize.Mode?

        /// The non-linear stretch, or `nil` for a linear image.
        public var stretch: Processors.Stretch.Algorithm?

        /// How to white-balance the channels, or `nil` to leave them untouched.
        public var whiteBalance: Processors.WhiteBalance.Mode?

        /// Whether to invert the image (photographic negative).
        public var invert: Bool

        /// The additive brightness offset (`0` is neutral).
        public var brightness: Double

        /// The multiplicative contrast factor about the midpoint (`1` is
        /// neutral).
        public var contrast: Double

        /// The levels remap to apply. An identity mapping is omitted from the
        /// pipeline configuration.
        public var levels: Processors.Levels.Channels

        /// The tone curve to apply. An identity curve is omitted from the
        /// pipeline configuration.
        public var curves: Processors.Curves.Channels

        /// The tonal-range colour balance. A neutral balance is omitted from the
        /// pipeline configuration.
        public var colorBalance: Processors.ColorBalance.Ranges

        /// The hue-rotation angle in degrees (`0` is neutral).
        public var hue: Double

        /// The colour-saturation factor (`1` is neutral).
        public var saturation: Double

        /// How to debayer a colour-filter-array image.
        public var debayer: DebayerSelection

        /// The demosaic algorithm used when debayering.
        public var debayerMode: Processors.Debayer.Mode

        /// The net orientation (rotation + optional mirror) applied to the
        /// rendered image. Defaults to the captured orientation.
        public var orientation: Processors.Orient.Orientation

        /// Creates a settings snapshot. The defaults render the file as
        /// captured: linear normalization only, with no stretch or white balance.
        ///
        /// - Parameters:
        ///   - normalize:    How to normalize pixel values.
        ///   - stretch:      The non-linear stretch.
        ///   - whiteBalance: How to white-balance the channels.
        ///   - invert:       Whether to invert the image.
        ///   - brightness:   The additive brightness offset (`0` is neutral).
        ///   - contrast:     The contrast factor about the midpoint (`1` is neutral).
        ///   - levels:       The levels remap (an identity mapping is neutral).
        ///   - curves:       The tone curve (an identity curve is neutral).
        ///   - colorBalance: The tonal-range colour balance (a neutral balance is neutral).
        ///   - hue:          The hue-rotation angle in degrees (`0` is neutral).
        ///   - saturation:   The colour-saturation factor (`1` is neutral).
        ///   - debayer:      How to debayer the image.
        ///   - debayerMode:  The demosaic algorithm used when debayering.
        ///   - orientation:  The net orientation applied to the rendered image.
        public init( normalize: Processors.Normalize.Mode? = .minMax, stretch: Processors.Stretch.Algorithm? = nil, whiteBalance: Processors.WhiteBalance.Mode? = nil, invert: Bool = false, brightness: Double = 0, contrast: Double = 1, levels: Processors.Levels.Channels = .uniform( .identity ), curves: Processors.Curves.Channels = .uniform( .identity ), colorBalance: Processors.ColorBalance.Ranges = .identity, hue: Double = 0, saturation: Double = 1, debayer: DebayerSelection = .auto, debayerMode: Processors.Debayer.Mode = .bilinear, orientation: Processors.Orient.Orientation = .identity )
        {
            self.normalize    = normalize
            self.stretch      = stretch
            self.whiteBalance = whiteBalance
            self.invert       = invert
            self.brightness   = brightness
            self.contrast     = contrast
            self.levels       = levels
            self.curves       = curves
            self.colorBalance = colorBalance
            self.hue          = hue
            self.saturation   = saturation
            self.debayer      = debayer
            self.debayerMode  = debayerMode
            self.orientation  = orientation
        }

        /// Builds the pipeline configuration, combining these tunables with the
        /// header-derived affine scaling and Bayer pattern.
        ///
        /// - Parameters:
        ///   - scale:         The multiplicative scale from `BSCALE`.
        ///   - offset:        The additive offset from `BZERO`.
        ///   - headerPattern: The Bayer pattern from `BAYERPAT`, or `nil`. Used
        ///                    only when the debayer selection is `.auto`.
        /// - Returns: The configured `PixelPipeline.Config`.
        public func config( scale: Double, offset: Double, headerPattern: Processors.Debayer.Pattern? ) -> PixelPipeline.Config
        {
            let pattern: Processors.Debayer.Pattern? = switch self.debayer
            {
                case .none:             nil
                case .auto:             headerPattern
                case .pattern( let p ): p
            }

            // A resolved Bayer pattern means a colour-filter-array source to
            // demosaic; its absence means a monochrome source expanded to RGB.
            let inputFormat: PixelPipeline.Config.InputFormat = pattern.map { .cfa( pattern: $0, mode: self.debayerMode ) } ?? .mono

            return PixelPipeline.Config(
                scale:              ( scale, offset ),
                inputFormat:        inputFormat,
                normalize:          self.normalize,
                stretch:            self.stretch,
                correctGamma:       nil,
                whiteBalance:       self.whiteBalance,
                invert:             self.invert,
                brightnessContrast: ( self.brightness.isApproximatelyEqual( to: 0 ) && self.contrast.isApproximatelyEqual( to: 1 ) ) ? nil : ( brightness: self.brightness, contrast: self.contrast ),
                levels:             self.levels.isIdentity ? nil : self.levels,
                curves:             self.curves.isIdentity ? nil : self.curves,
                colorBalance:       self.colorBalance.isIdentity ? nil : self.colorBalance,
                hue:                self.hue.isApproximatelyEqual( to: 0 ) ? nil : self.hue,
                saturation:         self.saturation.isApproximatelyEqual( to: 1 ) ? nil : self.saturation,
                orient:             self.orientation.isIdentity ? nil : self.orientation
            )
        }
    }

    /// Renders an image HDU into a `CGImage`, validating the geometry keywords
    /// and running the configured pixel pipeline.
    ///
    /// Reads `BITPIX`, `NAXIS`/`NAXIS1`/`NAXIS2`, the optional `BAYERPAT` and the
    /// `BSCALE`/`BZERO` scaling from the header, then debayers (if applicable),
    /// normalizes, applies the pre-stretch linear adjustments (white balance,
    /// brightness/contrast), stretches, and applies the display-referred tone,
    /// colour and geometry stages.
    ///
    /// - Parameters:
    ///   - data:       The image HDU's raw pixel bytes.
    ///   - properties: The owning header's property snapshots.
    ///   - settings:   The user-tunable render settings.
    /// - Returns: The ``RenderResult`` with the display image, its 8-bit bytes,
    ///   and the input/output pixel formats (the bytes and formats feed histogram
    ///   computation and the mono-vs-colour display choice).
    /// - Throws: ``RuntimeError`` for a missing or unsupported `BITPIX`, a
    ///   non-2-D image, invalid dimensions, truncated data, or an unsupported
    ///   `BAYERPAT`.
    public static func render( data: Data, properties: [ FITSPropertySnapshot ], settings: Settings = Settings() ) throws -> RenderResult
    {
        guard let bitPix = properties.first( where: { $0.name == "BITPIX" } )?.value.integer
        else
        {
            throw RuntimeError( message: "Missing BITPIX property" )
        }

        guard let bitsPerPixel = BitsPerPixel.from( value: bitPix )
        else
        {
            throw RuntimeError( message: "Unsupported pixel format: BITPIX \( bitPix ) is not supported (supported values: 8, 16, 32, -32, -64)." )
        }

        guard let nAxis = properties.first( where: { $0.name == "NAXIS" } )?.value.integer
        else
        {
            throw RuntimeError( message: "Missing NAXIS property" )
        }

        guard nAxis == 2
        else
        {
            throw RuntimeError( message: "Unsupported image geometry: only 2-dimensional images are supported, but this file has NAXIS = \( nAxis ). 3-D cubes and multi-plane images are not yet supported." )
        }

        guard let nAxis1 = properties.first( where: { $0.name == "NAXIS1" } )?.value.integer
        else
        {
            throw RuntimeError( message: "Missing NAXIS1 property" )
        }

        guard let width = Int( exactly: nAxis1 ), width > 0
        else
        {
            throw RuntimeError( message: "Invalid NAXIS1 value \( nAxis1 )" )
        }

        guard let nAxis2 = properties.first( where: { $0.name == "NAXIS2" } )?.value.integer
        else
        {
            throw RuntimeError( message: "Missing NAXIS2 property" )
        }

        guard let height = Int( exactly: nAxis2 ), height > 0
        else
        {
            throw RuntimeError( message: "Invalid NAXIS2 value \( nAxis2 )" )
        }

        let size      = bitsPerPixel.size( numberOfPixels: width * height )
        let pixelData = Data( data.prefix( size ) ) // re-wrap: startIndex may be non-zero

        guard pixelData.count == size
        else
        {
            throw RuntimeError( message: "Data too small: \( data.count ) < \( size )" )
        }

        let bayerPattern = try Self.bayerPattern( from: properties )

        let ( scale, offset ) = ImageProcessor.scaling( from: properties )

        let config = settings.config( scale: scale, offset: offset, headerPattern: bayerPattern )

        return try Self.render( data: pixelData, width: width, height: height, bitsPerPixel: bitsPerPixel, config: config )
    }

    /// Renders decoded samples through the configured pixel pipeline, independent
    /// of any source file format.
    ///
    /// This is the format-agnostic core: the FITS-facing
    /// ``render(data:properties:settings:)`` builds the ``PixelPipeline/Config``
    /// from the header keywords and delegates here, and other formats can build
    /// their own configuration and reuse this same core.
    ///
    /// - Parameters:
    ///   - data:         The raw sample bytes to decode and process.
    ///   - width:        The image width in pixels.
    ///   - height:       The image height in pixels.
    ///   - bitsPerPixel: The sample format of `data`.
    ///   - config:       The configured pipeline stages, including the input
    ///                   format that selects the channel-forming step.
    /// - Returns: The ``RenderResult`` with the display image, its 8-bit bytes
    ///   and the input/output pixel formats.
    /// - Throws: Any error thrown by the pixel pipeline.
    private static func render( data: Data, width: Int, height: Int, bitsPerPixel: BitsPerPixel, config: PixelPipeline.Config ) throws -> RenderResult
    {
        let pipeline = PixelPipeline( config: config )

        // The result's colour interpretation follows the input layout: a mono
        // source is replicated across three channels (shown as mono), while a CFA
        // or RGB source is genuine colour.
        let inputPixelFormat: RenderResult.InputPixelFormat = switch config.inputFormat
        {
            case .mono:       .mono
            case .cfa:        .cfa
            case .rgb:        .rgb

            // `InputFormat` is a non-frozen enum in a separate module, so a future
            // case must be handled. Treat any unknown layout as genuine colour —
            // the only behavioural effect is that it is not shown as monochrome.
            @unknown default: .rgb
        }

        return try Benchmark.run( label: "Rendering Image", output: Benchmarking.log )
        {
            let buffer = try pipeline.run( data: data, width: width, height: height, bitsPerPixel: bitsPerPixel )
            let bytes  = try buffer.convertTo8Bits()
            let image  = try PixelBuffer.createCGImage( bytes: bytes, width: buffer.width, height: buffer.height, channels: buffer.channels )

            return RenderResult( image: image, bytes: bytes, inputPixelFormat: inputPixelFormat, outputPixelFormat: .rgb )
        }
    }

    /// Maps the header's `BAYERPAT` keyword to a debayer pattern.
    ///
    /// - Parameter properties: The image HDU's header properties.
    /// - Returns: The colour-filter-array pattern, or `nil` when the header has
    ///   no `BAYERPAT` keyword (i.e. the frame is monochrome).
    /// - Throws: ``RuntimeError`` when `BAYERPAT` holds an unsupported value.
    public static func bayerPattern( from properties: [ FITSPropertySnapshot ] ) throws -> Processors.Debayer.Pattern?
    {
        guard let pattern = properties.first( where: { $0.name == "BAYERPAT" } )?.value.string
        else
        {
            return nil
        }

        switch pattern
        {
            case "BGGR": return .bggr
            case "RGBG": return .rgbg
            case "GRBG": return .grbg
            case "RGGB": return .rggb
            default:     throw RuntimeError( message: "Unsupported BAYERPAT value \( pattern )" )
        }
    }

    /// Reads the image dimensions from the header's `NAXIS1` / `NAXIS2`
    /// keywords.
    ///
    /// - Parameter properties: The image HDU's header properties.
    /// - Returns: The source `width` and `height`, or `nil` if either keyword is
    ///   missing or non-positive.
    public static func imageDimensions( from properties: [ FITSPropertySnapshot ] ) -> ( width: Int, height: Int )?
    {
        guard let nAxis1 = properties.first( where: { $0.name == "NAXIS1" } )?.value.integer,
              let nAxis2 = properties.first( where: { $0.name == "NAXIS2" } )?.value.integer,
              let width  = Int( exactly: nAxis1 ), width  > 0,
              let height = Int( exactly: nAxis2 ), height > 0
        else
        {
            return nil
        }

        return ( width, height )
    }

    /// Reads the linear pixel-scaling keywords `BSCALE` and `BZERO`.
    ///
    /// - Parameter properties: The image HDU's header properties.
    /// - Returns: The multiplicative `scale` (`BSCALE`, default 1) and additive
    ///   `offset` (`BZERO`, default 0) to apply to raw pixel values.
    static func scaling( from properties: [ FITSPropertySnapshot ] ) -> ( scale: Double, offset: Double )
    {
        let bZero  = properties.first { $0.name == "BZERO"  }
        let bScale = properties.first { $0.name == "BSCALE" }

        let offset = bZero?.value.float  ?? bZero?.value.integer.map( Double.init )  ?? 0
        let scale  = bScale?.value.float ?? bScale?.value.integer.map( Double.init ) ?? 1

        return ( scale: scale, offset: offset )
    }

    /// A decoded pixel sample: the scaled raw value and its fraction of the
    /// sample format's full scale.
    public struct PixelValue: Equatable
    {
        /// The decoded, scaled sample value.
        public let value: Double

        /// The value as a fraction (`0...1`) of the integer format's full scale,
        /// or `nil` for floating-point formats which have no fixed full scale.
        public let fraction: Double?
    }

    /// Decodes the raw sample at image coordinates `(x, y)` from the HDU bytes,
    /// applying `BSCALE`/`BZERO`. Coordinates use a top-left origin matching the
    /// displayed image (the pipeline does not flip rows).
    ///
    /// - Parameters:
    ///   - data:       The image HDU's raw pixel bytes.
    ///   - properties: The owning header's property snapshots.
    ///   - x:          The zero-based column, left to right.
    ///   - y:          The zero-based row, top to bottom.
    /// - Returns: The decoded value, or `nil` for missing/unsupported geometry,
    ///   out-of-bounds coordinates, or truncated data.
    public static func rawPixelValue( data: Data, properties: [ FITSPropertySnapshot ], x: Int, y: Int ) -> PixelValue?
    {
        guard let bitPix       = properties.first( where: { $0.name == "BITPIX" } )?.value.integer,
              let bitsPerPixel = BitsPerPixel.from( value: bitPix ),
              let nAxis1       = properties.first( where: { $0.name == "NAXIS1" } )?.value.integer,
              let nAxis2       = properties.first( where: { $0.name == "NAXIS2" } )?.value.integer,
              let width        = Int( exactly: nAxis1 ), width > 0,
              let height       = Int( exactly: nAxis2 ), height > 0,
              x >= 0, x < width, y >= 0, y < height
        else
        {
            return nil
        }

        let bytesPerSample = bitsPerPixel.size( numberOfPixels: 1 )
        let sampleIndex    = y * width + x
        let byteOffset     = sampleIndex * bytesPerSample

        guard byteOffset + bytesPerSample <= data.count
        else
        {
            return nil
        }

        // `data` may have a non-zero startIndex; index relative to it.
        let start = data.startIndex + byteOffset
        let raw   = Self.decodeSample( data: data, at: start, bitsPerPixel: bitsPerPixel )

        let ( scale, offset ) = ImageProcessor.scaling( from: properties )
        let scaled            = raw * scale + offset
        let fraction          = Self.fullScale( for: bitsPerPixel ).map { scaled / $0 }

        return PixelValue( value: scaled, fraction: fraction )
    }

    /// Decodes a single big-endian sample at the given absolute data index.
    private static func decodeSample( data: Data, at index: Data.Index, bitsPerPixel: BitsPerPixel ) -> Double
    {
        switch bitsPerPixel
        {
            case .uint8:

                return Double( data[ index ] )

            case .int16:

                let raw = ( UInt16( data[ index ] ) << 8 ) | UInt16( data[ index + 1 ] )

                return Double( Int16( bitPattern: raw ) )

            case .int32:

                var raw: UInt32 = 0

                for offset in 0 ..< 4
                {
                    raw = ( raw << 8 ) | UInt32( data[ index + offset ] )
                }

                return Double( Int32( bitPattern: raw ) )

            case .float32:

                var raw: UInt32 = 0

                for offset in 0 ..< 4
                {
                    raw = ( raw << 8 ) | UInt32( data[ index + offset ] )
                }

                return Double( Float32( bitPattern: raw ) )

            case .float64:

                var raw: UInt64 = 0

                for offset in 0 ..< 8
                {
                    raw = ( raw << 8 ) | UInt64( data[ index + offset ] )
                }

                return Double( bitPattern: raw )

            @unknown default:

                return 0
        }
    }

    /// The full-scale maximum used for the displayed fraction, or `nil` for
    /// floating-point formats.
    private static func fullScale( for bitsPerPixel: BitsPerPixel ) -> Double?
    {
        switch bitsPerPixel
        {
            case .uint8:             return 255
            case .int16:             return 65535
            case .int32:             return 4294967295
            case .float32,
                 .float64: return nil
            @unknown default:        return nil
        }
    }
}
