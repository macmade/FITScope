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
import SwiftPixel
import SwiftUtilities

/// Turns an image's decoded samples into a displayable `CGImage`, driving the
/// `SwiftPixel` pipeline.
///
/// A namespace of static functions and the value types describing the user's
/// render choices; it holds no state. This file holds the format-agnostic core —
/// the `Settings`, the pipeline render entries that consume decoded bytes or
/// channel planes, and the shared value types; the format-specific entries that
/// read a file's own metadata live in the per-format extensions
/// (`ImageProcessor+FITS.swift`, `ImageProcessor+XISF.swift`).
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

        /// The Screen Transfer parameters, or `nil` for a linear image.
        public var stretch: Processors.Stretch.STFParameters?

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
        public init( normalize: Processors.Normalize.Mode? = .minMax, stretch: Processors.Stretch.STFParameters? = nil, whiteBalance: Processors.WhiteBalance.Mode? = nil, invert: Bool = false, brightness: Double = 0, contrast: Double = 1, levels: Processors.Levels.Channels = .uniform( .identity ), curves: Processors.Curves.Channels = .uniform( .identity ), colorBalance: Processors.ColorBalance.Ranges = .identity, hue: Double = 0, saturation: Double = 1, debayer: DebayerSelection = .auto, debayerMode: Processors.Debayer.Mode = .bilinear, orientation: Processors.Orient.Orientation = .identity )
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
    public static func render( data: Data, width: Int, height: Int, bitsPerPixel: BitsPerPixel, config: PixelPipeline.Config ) throws -> RenderResult
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
    public static func render( planes: [ [ Double ] ], width: Int, height: Int, bitsPerPixel: BitsPerPixel, config: PixelPipeline.Config ) throws -> RenderResult
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
    public static func result( from buffer: PixelBuffer, config: PixelPipeline.Config ) throws -> RenderResult
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

    /// Maps a colour-filter-array pattern name (e.g. `"RGGB"`) to a debayer
    /// pattern, shared by the FITS `BAYERPAT` path and the XISF colour-filter-array
    /// path so both formats accept identical patterns.
    ///
    /// - Parameter name: The pattern name.
    /// - Returns: The matching debayer pattern.
    /// - Throws: ``RuntimeError`` for an unsupported pattern name.
    public static func debayerPattern( named name: String ) throws -> Processors.Debayer.Pattern
    {
        switch name
        {
            case "BGGR": return .bggr
            case "RGBG": return .rgbg
            case "GRBG": return .grbg
            case "RGGB": return .rggb
            case "GBRG": return .gbrg
            default:     throw RuntimeError( message: "Unsupported colour-filter-array pattern \( name )" )
        }
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
}
