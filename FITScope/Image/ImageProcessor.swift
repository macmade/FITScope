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

            return self.config( scale: scale, offset: offset, inputFormat: inputFormat )
        }

        /// Builds the pipeline configuration for an explicit input layout, combining
        /// these tunables with the header-derived affine scaling.
        ///
        /// Used by the format paths that already know their channel layout — e.g.
        /// an RGB `NAXIS=3` image, whose interleaved planes are passed through as
        /// ``PixelPipeline/Config/InputFormat/rgb`` regardless of the debayer
        /// selection (which only concerns colour-filter-array sources).
        ///
        /// - Parameters:
        ///   - scale:       The multiplicative scale from `BSCALE`.
        ///   - offset:      The additive offset from `BZERO`.
        ///   - inputFormat: The channel layout of the samples fed to the pipeline.
        /// - Returns: The configured `PixelPipeline.Config`.
        public func config( scale: Double, offset: Double, inputFormat: PixelPipeline.Config.InputFormat ) -> PixelPipeline.Config
        {
            PixelPipeline.Config(
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
    /// Supports a two-dimensional image (`NAXIS = 2`) and an RGB colour-planes cube
    /// (`NAXIS = 3` with a third axis of 3 — see ``isRGBPlanes(properties:)``),
    /// whose planes are combined into one colour image. A multi-image cube (see
    /// ``isMultiImageCube(properties:)``) is split into per-plane 2-D sources by the
    /// loader, so each plane reaches here as a 2-D image; any remaining `NAXIS = 3`
    /// geometry (a physical data cube) is rejected.
    ///
    /// - Parameters:
    ///   - data:       The image HDU's raw pixel bytes.
    ///   - properties: The owning header's property snapshots.
    ///   - settings:   The user-tunable render settings.
    /// - Returns: The ``RenderResult`` with the display image, its 8-bit bytes,
    ///   and the input/output pixel formats (the bytes and formats feed histogram
    ///   computation and the mono-vs-colour display choice).
    /// - Throws: ``RuntimeError`` for a missing or unsupported `BITPIX`, an
    ///   unsupported geometry (a non-2-D image that is not an RGB colour-planes
    ///   cube), invalid dimensions, truncated data, or an unsupported `BAYERPAT`.
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

        // A three-dimensional HDU whose third axis holds separate red, green and
        // blue planes is combined into a single colour image; any other NAXIS=3
        // shape (a multi-plane cube) is left for a later milestone.
        if nAxis == 3, Self.isRGBPlanes( properties: properties )
        {
            return try Self.renderRGBPlanes( data: data, properties: properties, bitsPerPixel: bitsPerPixel, settings: settings )
        }

        guard nAxis == 2
        else
        {
            // `render` handles only a single image directly: a 2-D image or an RGB
            // colour cube. A multi-image cube is split into per-plane 2-D sources by
            // the loader before reaching here, so a cube arriving whole (e.g. the
            // QuickLook path) is not renderable directly. A present CTYPE3 identifies
            // a physical data cube specifically.
            let detail = Self.trimmedString( named: "CTYPE3", in: properties ) != nil
                ? "it is a data cube with a physical third axis (CTYPE3), which is not supported"
                : "only a single 2-D image or an RGB colour cube can be rendered directly"

            throw RuntimeError( message: "Unsupported image geometry: this file has NAXIS = \( nAxis ); \( detail )." )
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

        return try Benchmark.run( label: "Rendering Image", output: Benchmarking.log )
        {
            let buffer = try pipeline.run( data: data, width: width, height: height, bitsPerPixel: bitsPerPixel )

            return try Self.result( from: buffer, config: config )
        }
    }

    /// Renders already-decoded channel planes through the configured pixel
    /// pipeline — the counterpart of ``render(data:width:height:bitsPerPixel:config:)``
    /// for formats that decode their own channels into separate planes (e.g. the
    /// band-sequential red, green and blue planes of a `NAXIS=3` colour image).
    /// SwiftPixel interleaves the planes internally.
    ///
    /// - Parameters:
    ///   - planes:       The decoded channel planes, in channel order, all the same
    ///                   length; the plane count must match `config.inputFormat`.
    ///   - width:        The image width in pixels.
    ///   - height:       The image height in pixels.
    ///   - bitsPerPixel: The original sample format (informational).
    ///   - config:       The configured pipeline stages.
    /// - Returns: The ``RenderResult`` with the display image, its 8-bit bytes and
    ///   the input/output pixel formats.
    /// - Throws: Any error thrown by the pixel pipeline.
    private static func render( planes: [ [ Double ] ], width: Int, height: Int, bitsPerPixel: BitsPerPixel, config: PixelPipeline.Config ) throws -> RenderResult
    {
        let pipeline = PixelPipeline( config: config )

        return try Benchmark.run( label: "Rendering Image", output: Benchmarking.log )
        {
            let buffer = try pipeline.run( planes: planes, width: width, height: height, bitsPerPixel: bitsPerPixel )

            return try Self.result( from: buffer, config: config )
        }
    }

    /// Converts a processed pixel buffer into a ``RenderResult``, tagging it with
    /// the input layout the pipeline consumed. Shared by both render cores.
    ///
    /// - Parameters:
    ///   - buffer: The processed pixel buffer.
    ///   - config: The configuration the buffer was produced with.
    /// - Returns: The render result.
    /// - Throws: Any error thrown while converting the buffer to 8-bit bytes or a
    ///   `CGImage`.
    private static func result( from buffer: PixelBuffer, config: PixelPipeline.Config ) throws -> RenderResult
    {
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

        let bytes = try buffer.convertTo8Bits()
        let image = try PixelBuffer.createCGImage( bytes: bytes, width: buffer.width, height: buffer.height, channels: buffer.channels )

        return RenderResult( image: image, bytes: bytes, inputPixelFormat: inputPixelFormat, outputPixelFormat: .rgb )
    }

    /// Whether the header describes a three-dimensional HDU whose third axis holds
    /// separate red, green and blue image planes.
    ///
    /// The rule: `NAXIS = 3`, the third axis `NAXIS3 = 3`, and no present, non-empty
    /// `CTYPE3` (whose presence would mark the third axis as a genuine physical
    /// coordinate — a data cube, not colour planes). The spatial coordinate types
    /// `CTYPE1`/`CTYPE2` are deliberately *not* required: many real RGB FITS files
    /// carry no world-coordinate system, so a bare three-plane cube is still colour.
    /// Distinguishing three planes (colour) from any other plane count (a stack of
    /// separate images, see ``isMultiImageCube(properties:)``) is the plane count.
    ///
    /// - Parameter properties: The image HDU's header properties.
    /// - Returns: `true` when the header matches the RGB-planes shape.
    public static func isRGBPlanes( properties: [ FITSPropertySnapshot ] ) -> Bool
    {
        guard properties.first( where: { $0.name == "NAXIS"  } )?.value.integer == 3,
              properties.first( where: { $0.name == "NAXIS3" } )?.value.integer == 3
        else
        {
            return false
        }

        // A present, non-empty CTYPE3 marks the third axis as its own coordinate —
        // that is a multi-plane cube, not colour planes.
        return Self.trimmedString( named: "CTYPE3", in: properties ) == nil
    }

    /// Whether the header describes a `NAXIS = 3` cube whose third axis holds
    /// multiple distinct images (a stack), rather than RGB colour planes or a
    /// physical data cube.
    ///
    /// The rule: `NAXIS = 3`, the plane count `NAXIS3 ≥ 2` and `≠ 3` (a count of 3
    /// with no physical third axis is claimed as colour by ``isRGBPlanes(properties:)``),
    /// and no present, non-empty `CTYPE3` (whose presence marks the third axis as a
    /// physical coordinate — a spectral / velocity data cube, which is not a set of
    /// separate images and is rejected). The two rules are mutually exclusive over
    /// every `NAXIS = 3` shape.
    ///
    /// - Parameter properties: The image HDU's header properties.
    /// - Returns: `true` when the header matches the multi-image cube shape.
    public static func isMultiImageCube( properties: [ FITSPropertySnapshot ] ) -> Bool
    {
        guard properties.first( where: { $0.name == "NAXIS" } )?.value.integer == 3,
              let nAxis3 = properties.first( where: { $0.name == "NAXIS3" } )?.value.integer,
              nAxis3 >= 2, nAxis3 != 3
        else
        {
            return false
        }

        // A present, non-empty CTYPE3 marks the third axis as a physical coordinate —
        // a data cube, not a stack of separate images.
        return Self.trimmedString( named: "CTYPE3", in: properties ) == nil
    }

    /// Splits a multi-image `NAXIS = 3` cube into one two-dimensional image HDU per
    /// plane, in third-axis order, so each plane feeds the existing 2-D render path
    /// unchanged (as its own frame).
    ///
    /// Each returned HDU carries the plane's own contiguous byte slice and a header
    /// synthesised from the cube's — `NAXIS` set to 2 and `NAXIS3` dropped, every
    /// other keyword (dimensions, scaling, Bayer pattern, WCS) preserved. Planes are
    /// returned only for the data actually present: a cube truncated below its
    /// declared `NAXIS3` yields the fully present planes rather than broken frames,
    /// so the caller can fall back gracefully when none are.
    ///
    /// - Parameters:
    ///   - data:       The cube HDU's raw pixel bytes (band-sequential planes).
    ///   - properties: The cube HDU's header properties.
    /// - Returns: One 2-D HDU per fully present plane, empty when the geometry is
    ///   missing/invalid or no whole plane is present.
    public static func cubePlanes( data: Data, properties: [ FITSPropertySnapshot ] ) -> [ ( data: Data, properties: [ FITSPropertySnapshot ] ) ]
    {
        guard let bitPix       = properties.first( where: { $0.name == "BITPIX" } )?.value.integer,
              let bitsPerPixel = BitsPerPixel.from( value: bitPix ),
              let ( width, height ) = Self.imageDimensions( from: properties ),
              let nAxis3       = properties.first( where: { $0.name == "NAXIS3" } )?.value.integer,
              let planeCount   = Int( exactly: nAxis3 ), planeCount > 0
        else
        {
            return []
        }

        let planeSize = bitsPerPixel.size( numberOfPixels: width * height )

        guard planeSize > 0
        else
        {
            return []
        }

        // Only whole planes actually present in the data become frames; a truncated
        // cube drops its incomplete tail rather than surfacing broken frames.
        let availablePlanes = min( planeCount, data.count / planeSize )

        // The per-plane header is the cube's, made two-dimensional: NAXIS = 2 and the
        // third-axis length removed, so the 2-D render path accepts it.
        let planeProperties = properties.compactMap
        {
            property -> FITSPropertySnapshot? in

            switch property.name
            {
                case "NAXIS":  return FITSPropertySnapshot( name: "NAXIS", value: .integer( 2 ) )
                case "NAXIS3": return nil
                default:       return property
            }
        }

        return ( 0 ..< availablePlanes ).map
        {
            plane in

            // Re-wrap each plane slice into a fresh, zero-based Data so the downstream
            // readers index it in isolation.
            let slice = Data( data.dropFirst( plane * planeSize ).prefix( planeSize ) )

            return ( data: slice, properties: planeProperties )
        }
    }

    /// Decodes a two-dimensional image HDU into its scaled-linear samples (raw values
    /// with `BSCALE`/`BZERO` applied), for building a single-channel detection image.
    ///
    /// - Parameters:
    ///   - data:       The image HDU's raw pixel bytes.
    ///   - properties: The image HDU's header properties.
    /// - Returns: The dimensions and scaled-linear samples, or `nil` for a missing /
    ///   unsupported `BITPIX`, invalid dimensions, or truncated data.
    public static func linearImage( data: Data, properties: [ FITSPropertySnapshot ] ) -> ( width: Int, height: Int, samples: [ Double ] )?
    {
        guard let bitPix       = properties.first( where: { $0.name == "BITPIX" } )?.value.integer,
              let bitsPerPixel = BitsPerPixel.from( value: bitPix ),
              let ( width, height ) = Self.imageDimensions( from: properties ),
              let raw          = try? PixelUtilities.readRawPixels( data: data, width: width, height: height, bitsPerPixel: bitsPerPixel )
        else
        {
            return nil
        }

        let ( scale, offset ) = ImageProcessor.scaling( from: properties )
        let samples           = raw.map { $0 * scale + offset }

        return ( width: width, height: height, samples: samples )
    }

    /// Renders an RGB `NAXIS=3` image HDU: the three band-sequential colour planes
    /// are decoded and passed through the pipeline as a genuine colour (`.rgb`)
    /// input (SwiftPixel interleaves them), so the colour-aware stretch, curves and
    /// histogram apply.
    ///
    /// - Parameters:
    ///   - data:         The image HDU's raw pixel bytes (three stacked planes).
    ///   - properties:   The owning header's property snapshots.
    ///   - bitsPerPixel: The sample format of `data`.
    ///   - settings:     The user-tunable render settings.
    /// - Returns: The rendered colour result.
    /// - Throws: ``RuntimeError`` for invalid dimensions or truncated data.
    private static func renderRGBPlanes( data: Data, properties: [ FITSPropertySnapshot ], bitsPerPixel: BitsPerPixel, settings: Settings ) throws -> RenderResult
    {
        let planes            = try Self.rgbPlaneSamples( data: data, properties: properties, bitsPerPixel: bitsPerPixel )
        let ( scale, offset ) = ImageProcessor.scaling( from: properties )
        let config            = settings.config( scale: scale, offset: offset, inputFormat: .rgb )

        return try Self.render( planes: [ planes.red, planes.green, planes.blue ], width: planes.width, height: planes.height, bitsPerPixel: bitsPerPixel, config: config )
    }

    /// Decodes the three band-sequential colour planes of an RGB `NAXIS=3` image
    /// HDU into raw (unscaled) sample arrays, one per plane.
    ///
    /// The `BSCALE`/`BZERO` rescaling is left to the caller (the pipeline's scale
    /// stage for rendering, an explicit rescale for the detection luminance), so
    /// this returns the samples at their stored values.
    ///
    /// - Parameters:
    ///   - data:         The image HDU's raw pixel bytes.
    ///   - properties:   The owning header's property snapshots.
    ///   - bitsPerPixel: The sample format of `data`.
    /// - Returns: The plane dimensions and the raw red, green and blue samples.
    /// - Throws: ``RuntimeError`` for invalid dimensions or truncated data.
    private static func rgbPlaneSamples( data: Data, properties: [ FITSPropertySnapshot ], bitsPerPixel: BitsPerPixel ) throws -> ( width: Int, height: Int, red: [ Double ], green: [ Double ], blue: [ Double ] )
    {
        guard let ( width, height ) = Self.imageDimensions( from: properties )
        else
        {
            throw RuntimeError( message: "Invalid or missing NAXIS1 / NAXIS2 for an RGB image" )
        }

        let planeSize = bitsPerPixel.size( numberOfPixels: width * height )
        let total     = planeSize * 3
        let pixelData = Data( data.prefix( total ) ) // re-wrap: startIndex may be non-zero, and trim block padding

        guard pixelData.count == total
        else
        {
            throw RuntimeError( message: "Data too small: \( data.count ) < \( total )" )
        }

        // Each plane is a contiguous single channel; re-wrap each slice into a fresh
        // Data (zero-based indices) so readRawPixels reads it in isolation.
        let planes = try ( 0 ..< 3 ).map
        {
            plane -> [ Double ] in

            let slice = Data( pixelData.dropFirst( plane * planeSize ).prefix( planeSize ) )

            return try PixelUtilities.readRawPixels( data: slice, width: width, height: height, bitsPerPixel: bitsPerPixel )
        }

        return ( width: width, height: height, red: planes[ 0 ], green: planes[ 1 ], blue: planes[ 2 ] )
    }

    /// The per-channel decoded samples of an RGB `NAXIS=3` image at coordinates
    /// `(x, y)` — one ``PixelValue`` per plane in red, green, blue order — for the
    /// cursor read-out over a colour image.
    ///
    /// - Parameters:
    ///   - data:       The image HDU's raw pixel bytes.
    ///   - properties: The owning header's property snapshots.
    ///   - x:          The zero-based column, left to right.
    ///   - y:          The zero-based row, top to bottom.
    /// - Returns: The three channel values, or `nil` for a non-RGB header,
    ///   out-of-bounds coordinates or truncated data.
    public static func rgbPixelValues( data: Data, properties: [ FITSPropertySnapshot ], x: Int, y: Int ) -> [ PixelValue ]?
    {
        guard Self.isRGBPlanes( properties: properties ),
              let bitPix       = properties.first( where: { $0.name == "BITPIX" } )?.value.integer,
              let bitsPerPixel = BitsPerPixel.from( value: bitPix ),
              let ( width, height ) = Self.imageDimensions( from: properties ),
              x >= 0, x < width, y >= 0, y < height
        else
        {
            return nil
        }

        let bytesPerSample    = bitsPerPixel.size( numberOfPixels: 1 )
        let planeSampleCount  = width * height
        let ( scale, offset ) = ImageProcessor.scaling( from: properties )

        let values = ( 0 ..< 3 ).compactMap
        {
            plane -> PixelValue? in

            let sampleIndex = plane * planeSampleCount + y * width + x
            let byteOffset  = sampleIndex * bytesPerSample

            return Self.sampleValue( data: data, byteOffset: byteOffset, bitsPerPixel: bitsPerPixel, scale: scale, offset: offset )
        }

        return values.count == 3 ? values : nil
    }

    /// The per-pixel luminance (mean of the three colour planes, with
    /// `BSCALE`/`BZERO` applied) of an RGB `NAXIS=3` image, as a single-channel
    /// linear image for star detection and the sky-background measurement.
    ///
    /// Returns `nil` for a non-RGB header or when the planes cannot be decoded, so
    /// the caller falls back to the mono/CFA detection path (or none).
    ///
    /// - Parameters:
    ///   - data:       The image HDU's raw pixel bytes.
    ///   - properties: The owning header's property snapshots.
    /// - Returns: The image dimensions and the scaled-linear luminance samples, or
    ///   `nil`.
    public static func rgbLinearLuminance( data: Data, properties: [ FITSPropertySnapshot ] ) -> ( width: Int, height: Int, samples: [ Double ] )?
    {
        guard Self.isRGBPlanes( properties: properties ),
              let bitPix       = properties.first( where: { $0.name == "BITPIX" } )?.value.integer,
              let bitsPerPixel = BitsPerPixel.from( value: bitPix ),
              let planes       = try? Self.rgbPlaneSamples( data: data, properties: properties, bitsPerPixel: bitsPerPixel )
        else
        {
            return nil
        }

        let ( scale, offset ) = ImageProcessor.scaling( from: properties )
        let samples           = ( 0 ..< planes.red.count ).map
        {
            index -> Double in

            let sum     = planes.red[ index ] + planes.green[ index ] + planes.blue[ index ]
            let average = sum / 3

            return average * scale + offset
        }

        return ( width: planes.width, height: planes.height, samples: samples )
    }

    /// The first non-empty, whitespace-trimmed string value for a keyword.
    ///
    /// - Parameters:
    ///   - name:       The keyword name.
    ///   - properties: The header properties to search.
    /// - Returns: The trimmed string, or `nil` when absent, non-string or empty.
    private static func trimmedString( named name: String, in properties: [ FITSPropertySnapshot ] ) -> String?
    {
        guard let text = properties.first( where: { $0.name == name } )?.value.string?.trimmingCharacters( in: .whitespaces ), text.isEmpty == false
        else
        {
            return nil
        }

        return text
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
    public struct PixelValue: Equatable, Sendable
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

        let bytesPerSample    = bitsPerPixel.size( numberOfPixels: 1 )
        let byteOffset        = ( y * width + x ) * bytesPerSample
        let ( scale, offset ) = ImageProcessor.scaling( from: properties )

        return Self.sampleValue( data: data, byteOffset: byteOffset, bitsPerPixel: bitsPerPixel, scale: scale, offset: offset )
    }

    /// Decodes a single sample at a byte offset into the HDU bytes and applies the
    /// affine `BSCALE`/`BZERO` scaling, returning the scaled value and its fraction
    /// of the format's full scale.
    ///
    /// Shared by the single-channel ``rawPixelValue(data:properties:x:y:)`` and the
    /// per-plane ``rgbPixelValues(data:properties:x:y:)`` read-outs.
    ///
    /// - Parameters:
    ///   - data:         The image HDU's raw pixel bytes.
    ///   - byteOffset:   The sample's byte offset, relative to the data's contents.
    ///   - bitsPerPixel: The sample format.
    ///   - scale:        The multiplicative `BSCALE`.
    ///   - offset:       The additive `BZERO`.
    /// - Returns: The decoded value, or `nil` when the offset runs past the data.
    private static func sampleValue( data: Data, byteOffset: Int, bitsPerPixel: BitsPerPixel, scale: Double, offset: Double ) -> PixelValue?
    {
        let bytesPerSample = bitsPerPixel.size( numberOfPixels: 1 )

        guard byteOffset >= 0, byteOffset + bytesPerSample <= data.count
        else
        {
            return nil
        }

        // `data` may have a non-zero startIndex; index relative to it.
        let start    = data.startIndex + byteOffset
        let raw      = Self.decodeSample( data: data, at: start, bitsPerPixel: bitsPerPixel )
        let scaled   = raw * scale + offset
        let fraction = Self.fullScale( for: bitsPerPixel ).map { scaled / $0 }

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
