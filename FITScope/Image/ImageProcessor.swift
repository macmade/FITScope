/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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

/// A `Sendable` snapshot of a FITS header property.
///
/// `FITSProperty` is a reference type and not `Sendable`, so it cannot cross
/// the render concurrency boundary. This value type captures the keyword name
/// and its (already `Sendable`) value, which is all the renderer needs.
public struct FITSPropertySnapshot: Sendable
{
    /// The keyword name (e.g. `NAXIS1`).
    public let name:  String

    /// The keyword's value.
    public let value: FITSValue

    /// Creates a snapshot.
    ///
    /// - Parameters:
    ///   - name:  The keyword name.
    ///   - value: The keyword's value.
    public init( name: String, value: FITSValue )
    {
        self.name  = name
        self.value = value
    }
}

/// Turns a FITS image HDU's raw bytes and header keywords into a displayable
/// `CGImage`, driving the `SwiftPixel` pipeline.
///
/// A namespace of static functions and the value types describing the user's
/// render choices; it holds no state.
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
    /// The defaults reproduce the values the pipeline used when they were
    /// hard-coded, so a render with default settings is unchanged.
    public struct Settings: Sendable, Equatable
    {
        /// How to normalize pixel values, or `nil` to skip normalization.
        public var normalize:    Processors.Normalize.Mode?

        /// The non-linear stretch, or `nil` for a linear image.
        public var stretch:      Processors.Stretch.Algorithm?

        /// The gamma-correction exponent, or `nil` to leave gamma uncorrected.
        public var gamma:        Double?

        /// How to white-balance the channels, or `nil` to leave them untouched.
        public var whiteBalance: Processors.WhiteBalance.Mode?

        /// How to debayer a colour-filter-array image.
        public var debayer:      DebayerSelection

        /// Creates a settings snapshot. Defaults reproduce the pipeline's
        /// formerly hard-coded values.
        ///
        /// - Parameters:
        ///   - normalize:    How to normalize pixel values.
        ///   - stretch:      The non-linear stretch.
        ///   - gamma:        The gamma-correction exponent.
        ///   - whiteBalance: How to white-balance the channels.
        ///   - debayer:      How to debayer the image.
        public init( normalize: Processors.Normalize.Mode? = .minMax, stretch: Processors.Stretch.Algorithm? = .log( 50 ), gamma: Double? = 1.8, whiteBalance: Processors.WhiteBalance.Mode? = .auto, debayer: DebayerSelection = .auto )
        {
            self.normalize    = normalize
            self.stretch      = stretch
            self.gamma        = gamma
            self.whiteBalance = whiteBalance
            self.debayer      = debayer
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

            return PixelPipeline.Config(
                scale:        ( scale, offset ),
                debayer:      pattern.map { ( pattern: $0, mode: .bilinear ) },
                normalize:    self.normalize,
                stretch:      self.stretch,
                correctGamma: self.gamma,
                whiteBalance: self.whiteBalance
            )
        }
    }

    /// Renders an image HDU into a `CGImage`, validating the geometry keywords
    /// and running the configured pixel pipeline.
    ///
    /// Reads `BITPIX`, `NAXIS`/`NAXIS1`/`NAXIS2`, the optional `BAYERPAT` and the
    /// `BSCALE`/`BZERO` scaling from the header, then debayers (if applicable),
    /// normalizes, stretches, gamma-corrects and white-balances the pixels.
    ///
    /// - Parameters:
    ///   - data:       The image HDU's raw pixel bytes.
    ///   - properties: The owning header's property snapshots.
    ///   - settings:   The user-tunable render settings.
    /// - Returns: The rendered image, its 8-bit bytes and its channel count
    ///   (the bytes and channel count feed histogram computation).
    /// - Throws: ``RuntimeError`` for a missing or unsupported `BITPIX`, a
    ///   non-2-D image, invalid dimensions, truncated data, or an unsupported
    ///   `BAYERPAT`.
    public static func render( data: Data, properties: [ FITSPropertySnapshot ], settings: Settings = Settings() ) throws -> ( image: CGImage, bytes: [ UInt8 ], channels: Int )
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

        let bayerPattern: Processors.Debayer.Pattern? = if let pattern = properties.first( where: { $0.name == "BAYERPAT" } )?.value.string
        {
            switch pattern
            {
                case "BGGR": .bggr
                case "RGBG": .rgbg
                case "GRBG": .grbg
                case "RGGB": .rggb
                default:     throw RuntimeError( message: "Unsupported BAYERPAT value \( pattern )" )
            }
        }
        else
        {
            nil
        }

        let ( scale, offset ) = ImageProcessor.scaling( from: properties )

        let config   = settings.config( scale: scale, offset: offset, headerPattern: bayerPattern )
        let pipeline = PixelPipeline( config: config )

        return try Benchmark.run( label: "Rendering Image", output: Benchmarking.log )
        {
            let buffer = try pipeline.run( data: pixelData, width: width, height: height, bitsPerPixel: bitsPerPixel )
            let bytes  = try buffer.convertTo8Bits()
            let image  = try PixelBuffer.createCGImage( bytes: bytes, width: buffer.width, height: buffer.height, channels: buffer.channels )

            return ( image, bytes, buffer.channels )
        }
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
}
