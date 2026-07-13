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
    /// The colour data an auto Screen Transfer is derived from, tagging a source's
    /// retained linear samples with how they yield per-channel statistics.
    ///
    /// A colour source derives an unlinked ``Processors/Stretch/STFParameters/perChannel(red:green:blue:)``
    /// (each channel clipping only its own darkest tail); a monochrome source
    /// derives a ``Processors/Stretch/STFParameters/uniform(_:)``. The three cases
    /// mirror the forms the loaders retain: a single-channel luminance, a raw
    /// colour-filter-array mosaic (split per channel by ``Processors/Debayer/deinterleave(mosaic:width:height:pattern:)``,
    /// no demosaic), or a co-located 3-channel buffer (RGB planes or a photographic
    /// image).
    public enum AutoStretchColorSource: Sendable
    {
        /// A single-channel linear buffer, yielding a uniform (linked) STF.
        case mono( PixelBuffer )

        /// A single-channel Bayer mosaic and its pattern, yielding a per-channel
        /// (unlinked) STF by deinterleaving the mosaic into its colour sites.
        case mosaic( PixelBuffer, pattern: Processors.Debayer.Pattern )

        /// A co-located 3-channel buffer (RGB planes or a photographic image),
        /// yielding a per-channel (unlinked) STF from its channels directly.
        case channels( PixelBuffer )
    }

    /// The normalization domain an auto Screen Transfer is derived and applied in.
    ///
    /// The choice depends only on whether the format has a fixed full scale, not on
    /// whether it is colour: a colour image derives a per-channel STF in either domain,
    /// a mono image a uniform one.
    public enum AutoStretchDomain: Sendable, Equatable
    {
        /// The native full-scale `[0, 1]` domain of a format with a fixed full scale
        /// (an integer FITS / XISF / RAW): samples are scaled by `1 / fullScale` and
        /// clamped by identity normalization. The associated value is that full scale.
        case fullScale( Double )

        /// The min/max domain, for a format with no fixed full scale (a floating-point
        /// FITS / XISF, or a RAW without a white level): samples are rescaled by their
        /// own minimum and maximum. This is the same domain the render falls back to,
        /// so the derivation and the render agree.
        case minMax
    }

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

        /// The cosmetic-correction (hot/cold pixel repair) parameters. Applied to
        /// the raw samples before the channel-forming stage; a disabled value is
        /// omitted from the pipeline configuration.
        public var cosmeticCorrection: Processors.CosmeticCorrection.Parameters

        /// The net orientation (rotation + optional mirror) applied to the
        /// rendered image. Defaults to the captured orientation.
        public var orientation: Processors.Orient.Orientation

        /// The largest dimension the rendered image may take, or `nil` to render
        /// at full resolution. This is a render-target cap, not a user-tunable
        /// adjustment: only the preview/thumbnail renderers set it, so a Finder
        /// thumbnail is produced from a downsampled image (a box-averaging pass
        /// runs after channel-forming). The app's interactive render leaves it
        /// `nil`.
        public var maxDimension: Int?

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
        ///   - cosmeticCorrection: The hot/cold pixel repair applied to the raw samples (a disabled value is omitted from the configuration).
        ///   - orientation:  The net orientation applied to the rendered image.
        ///   - maxDimension: The largest dimension the rendered image may take, or `nil` for a full-resolution render (the preview/thumbnail renderers set it).
        public init( normalize: Processors.Normalize.Mode? = .minMax, stretch: Processors.Stretch.STFParameters? = nil, whiteBalance: Processors.WhiteBalance.Mode? = nil, invert: Bool = false, brightness: Double = 0, contrast: Double = 1, levels: Processors.Levels.Channels = .uniform( .identity ), curves: Processors.Curves.Channels = .uniform( .identity ), colorBalance: Processors.ColorBalance.Ranges = .identity, hue: Double = 0, saturation: Double = 1, debayer: DebayerSelection = .auto, debayerMode: Processors.Debayer.Mode = .bilinear, cosmeticCorrection: Processors.CosmeticCorrection.Parameters = .default, orientation: Processors.Orient.Orientation = .identity, maxDimension: Int? = nil )
        {
            self.normalize          = normalize
            self.stretch            = stretch
            self.whiteBalance       = whiteBalance
            self.invert             = invert
            self.brightness         = brightness
            self.contrast           = contrast
            self.levels             = levels
            self.curves             = curves
            self.colorBalance       = colorBalance
            self.hue                = hue
            self.saturation         = saturation
            self.debayer            = debayer
            self.debayerMode        = debayerMode
            self.cosmeticCorrection = cosmeticCorrection
            self.orientation        = orientation
            self.maxDimension       = maxDimension
        }

        /// Builds the pipeline configuration, combining these tunables with the
        /// header-derived affine scaling and Bayer pattern.
        ///
        /// - Parameters:
        ///   - scale:         The multiplicative scale from `BSCALE`.
        ///   - offset:        The additive offset from `BZERO`.
        ///   - headerPattern: The Bayer pattern from `BAYERPAT`, or `nil`. Used
        ///                    only when the debayer selection is `.auto`.
        ///   - binFactor:     The factor to bin the mosaic before the demosaic.
        ///                    Defaults to one (no binning); set above one only for a
        ///                    heavily downsampled mosaic preview.
        /// - Returns: The configured `PixelPipeline.Config`.
        public func config( scale: Double, offset: Double, headerPattern: Processors.Debayer.Pattern?, binFactor: Int = 1 ) -> PixelPipeline.Config
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

            return self.config( scale: scale, offset: offset, inputFormat: inputFormat, binFactor: binFactor )
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
        ///   - binFactor:   The factor to bin a single-channel mosaic before the demosaic. Defaults to one (no binning); set above one only for a heavily downsampled mosaic preview.
        /// - Returns: The configured `PixelPipeline.Config`.
        public func config( scale: Double, offset: Double, inputFormat: PixelPipeline.Config.InputFormat, binFactor: Int = 1 ) -> PixelPipeline.Config
        {
            PixelPipeline.Config(
                scale:              ( scale, offset ),
                inputFormat:        inputFormat,
                maxDimension:       self.maxDimension,
                binFactor:          binFactor,
                cosmeticCorrection: self.cosmeticCorrection.isEnabled ? self.cosmeticCorrection : nil,
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
                orient:             self.orientation.isIdentity ? nil : self.orientation,
                measure:            { label, stage in try Benchmark.run( label: label, output: Benchmarking.log, action: stage ) }
            )
        }
    }

    /// Derives the settings an image opens with when auto-stretch-on-open is enabled:
    /// a uniform auto Screen Transfer seeded over identity normalization, or `nil`
    /// when it cannot be derived.
    ///
    /// These become the image's *opened* state (layered over the unstretched
    /// baseline), not its reset baseline — the user can reset the auto-stretch away.
    ///
    /// The Screen Transfer is authored in — and applied in — the native full-scale
    /// `[0, 1]` domain (the loaders scale their samples by `1 / fullScale`, so an
    /// ``Processors/Normalize/Mode/identity`` normalization acts on that domain). To
    /// keep the derived parameters in step with how they are applied, the derivation
    /// runs over the same domain: the single-channel `detectionImage` (in
    /// scaled-linear units) is divided by `fullScale` into `[0, 1]`, clamped by
    /// identity normalization, then reduced to a uniform STF. The inspector's and
    /// editor's "Auto" actions call through here too (via
    /// ``ImageRenderer/autoScreenTransferSettings(shadowClipFactor:targetBackground:)``),
    /// so opening the image and clicking Auto derive in the same domain and agree.
    /// Per-channel balancing stays available by hand in the Screen Transfer editor.
    ///
    /// - Parameters:
    ///   - detectionImage:   The image's single-channel linear detection buffer, or
    ///                       `nil` when none could be built.
    ///   - fullScale:        The format's full-scale maximum, used to bring the
    ///                       detection samples into `[0, 1]`. Must be positive.
    ///   - shadowClipFactor: How many median-absolute-deviations below the median to
    ///                       clip the shadows. Defaults to `2.8`.
    ///   - targetBackground: The value the median should map to. Defaults to `0.25`.
    /// - Returns: The `{ normalize: .identity, stretch: <auto STF> }` opened settings,
    ///   or `nil` when no detection image is available, the full scale is not
    ///   positive, or the derivation fails.
    static func autoStretchSettings( detectionImage: PixelBuffer?, fullScale: Double, shadowClipFactor: Double = 2.8, targetBackground: Double = 0.25 ) -> Settings?
    {
        guard let buffer = detectionImage, buffer.pixels.isEmpty == false, fullScale > 0
        else
        {
            return nil
        }

        let scaled = buffer.pixels.map { $0 / fullScale }

        guard let input   = try? PixelBuffer( width: buffer.width, height: buffer.height, channels: buffer.channels, pixels: scaled, isNormalized: false ),
              let stretch = try? Processors.Stretch.STFParameters.computed( normalizing: input, using: .identity, shadowClipFactor: shadowClipFactor, targetBackground: targetBackground )
        else
        {
            return nil
        }

        return Settings( normalize: .identity, stretch: stretch )
    }

    /// Derives the auto Screen Transfer settings for a source's colour data:
    /// a per-channel (unlinked) STF for a colour source, a uniform (linked) STF for
    /// a monochrome one — the single shared derivation the on-open path, the
    /// inspector and the Screen Transfer editor all reach.
    ///
    /// Like ``autoStretchSettings(detectionImage:fullScale:shadowClipFactor:targetBackground:)``,
    /// the STF is authored — and applied — in the native full-scale `[0, 1]` domain
    /// over ``Processors/Normalize/Mode/identity``: the source's linear samples are
    /// scaled by `1 / fullScale`, clamped by the identity normalization, then reduced
    /// to per-channel or uniform parameters, so opening the image and clicking Auto
    /// agree. A colour-filter-array mosaic is split per channel with
    /// ``Processors/Debayer/deinterleave(mosaic:width:height:pattern:)`` and reduced
    /// by ``Processors/Stretch/STFParameters/computed(fromMosaic:pattern:shadowClipFactor:targetBackground:)``;
    /// a co-located 3-channel buffer by
    /// ``Processors/Stretch/STFParameters/computed(from:shadowClipFactor:targetBackground:)``;
    /// a mono buffer by the uniform derivation.
    ///
    /// - Parameters:
    ///   - colorSource:      The source's colour data, or `nil` when none is
    ///                       available.
    ///   - fullScale:        The format's full-scale maximum, used to bring the
    ///                       samples into `[0, 1]`. Must be positive.
    ///   - shadowClipFactor: How many median-absolute-deviations below the median to
    ///                       clip the shadows. Defaults to `2.8`.
    ///   - targetBackground: The value the median should map to. Defaults to `0.25`.
    /// - Returns: The `{ normalize: .identity, stretch: <auto STF> }` opened settings,
    ///   or `nil` when no colour source is available, the full scale is not positive,
    ///   or the derivation fails.
    static func autoStretchSettings( colorSource: AutoStretchColorSource?, domain: AutoStretchDomain, shadowClipFactor: Double = 2.8, targetBackground: Double = 0.25 ) -> Settings?
    {
        guard let colorSource
        else
        {
            return nil
        }

        switch colorSource
        {
            case .mono( let buffer ):

                return Self.stretchSettings( buffer, domain: domain )
                {
                    try Processors.Stretch.STFParameters.computed( from: $0, shadowClipFactor: shadowClipFactor, targetBackground: targetBackground )
                }

            case .mosaic( let buffer, let pattern ):

                return Self.stretchSettings( buffer, domain: domain )
                {
                    try Processors.Stretch.STFParameters.computed( fromMosaic: $0, pattern: pattern, shadowClipFactor: shadowClipFactor, targetBackground: targetBackground )
                }

            case .channels( let buffer ):

                return Self.stretchSettings( buffer, domain: domain )
                {
                    try Processors.Stretch.STFParameters.computed( from: $0, shadowClipFactor: shadowClipFactor, targetBackground: targetBackground )
                }
        }
    }

    /// The full-scale overload of ``autoStretchSettings(colorSource:domain:shadowClipFactor:targetBackground:)``,
    /// for a format with a fixed full scale — colour → per-channel, mono → uniform, in
    /// the native full-scale `[0, 1]` domain.
    ///
    /// - Parameters:
    ///   - colorSource:      The source's colour data, or `nil` when none is available.
    ///   - fullScale:        The format's full-scale maximum. Must be positive.
    ///   - shadowClipFactor: How many median-absolute-deviations below the median to
    ///                       clip the shadows. Defaults to `2.8`.
    ///   - targetBackground: The value the median should map to. Defaults to `0.25`.
    /// - Returns: The `{ normalize: .identity, stretch: <auto STF> }` opened settings,
    ///   or `nil` when no colour source is available, the full scale is not positive,
    ///   or the derivation fails.
    static func autoStretchSettings( colorSource: AutoStretchColorSource?, fullScale: Double, shadowClipFactor: Double = 2.8, targetBackground: Double = 0.25 ) -> Settings?
    {
        Self.autoStretchSettings( colorSource: colorSource, domain: .fullScale( fullScale ), shadowClipFactor: shadowClipFactor, targetBackground: targetBackground )
    }

    /// Builds `{ normalize, stretch }` settings from a source buffer, normalizing it
    /// into the derivation domain before deriving so the parameters and the render
    /// agree.
    ///
    /// Shared by every case of ``autoStretchSettings(colorSource:domain:shadowClipFactor:targetBackground:)``:
    /// in the ``AutoStretchDomain/fullScale(_:)`` domain the samples are scaled by
    /// `1 / fullScale` and clamped by identity normalization; in the
    /// ``AutoStretchDomain/minMax`` domain they are rescaled by their own min/max
    /// (unless already normalized). The result is then handed to `derive`.
    ///
    /// - Parameters:
    ///   - buffer: The source's linear buffer.
    ///   - domain: The normalization domain to derive in.
    ///   - derive: Reduces the normalized buffer to STF parameters.
    /// - Returns: The settings, or `nil` when the buffer is empty, the full scale is
    ///   not positive, or normalization or derivation fails.
    private static func stretchSettings( _ buffer: PixelBuffer, domain: AutoStretchDomain, derive: ( PixelBuffer ) throws -> Processors.Stretch.STFParameters ) -> Settings?
    {
        guard buffer.pixels.isEmpty == false
        else
        {
            return nil
        }

        switch domain
        {
            case .fullScale( let fullScale ):

                guard fullScale > 0,
                      var input = try? PixelBuffer( width: buffer.width, height: buffer.height, channels: buffer.channels, pixels: buffer.pixels.map { $0 / fullScale }, isNormalized: false )
                else
                {
                    return nil
                }

                do
                {
                    try Processors.Normalize( mode: .identity ).process( buffer: &input )

                    return Settings( normalize: .identity, stretch: try derive( input ) )
                }
                catch
                {
                    return nil
                }

            case .minMax:

                var input = buffer

                do
                {
                    // The colour input is raw (not normalized); rescale it by its own
                    // min/max, the same normalization the render applies for a format
                    // with no fixed full scale. An already-normalized buffer is left as
                    // is, matching the previous min/max derivation.
                    if input.isNormalized == false
                    {
                        try Processors.Normalize( mode: .minMax ).process( buffer: &input )
                    }

                    return Settings( normalize: .minMax, stretch: try derive( input ) )
                }
                catch
                {
                    return nil
                }
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

    /// Renders already-decoded raw samples through the configured pixel pipeline —
    /// the counterpart of ``render(data:width:height:bitsPerPixel:config:)`` that
    /// skips the decode, so a caller that has already decoded the raw samples (e.g.
    /// to derive the auto-stretch statistics) can render from them without decoding
    /// the frame a second time.
    ///
    /// The samples are the raw, unscaled values in the same layout
    /// ``render(data:width:height:bitsPerPixel:config:)`` would decode; the pipeline
    /// applies the configured affine scaling itself, so the two entries produce
    /// identical results for the same bytes.
    ///
    /// - Parameters:
    ///   - pixels:       The already-decoded raw samples, in row-major order.
    ///   - width:        The image width in pixels.
    ///   - height:       The image height in pixels.
    ///   - bitsPerPixel: The original sample format (informational).
    ///   - config:       The configured pipeline stages.
    /// - Returns: The ``RenderResult``.
    /// - Throws: Any error thrown by the pixel pipeline.
    public static func render( pixels: [ Double ], width: Int, height: Int, bitsPerPixel: BitsPerPixel, config: PixelPipeline.Config ) throws -> RenderResult
    {
        let pipeline = PixelPipeline( config: config )

        return try Benchmark.run( label: "Rendering Image", output: Benchmarking.log )
        {
            let buffer = try pipeline.run( pixels: pixels, width: width, height: height, bitsPerPixel: bitsPerPixel )

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

    /// The factor to bin a colour-filter-array mosaic before the demosaic when
    /// rendering a downsampled preview, or `nil` to skip binning.
    ///
    /// Binning halves the mosaic (averaging same-colour sites), so it is applied
    /// only when the source is a mosaic being downsampled to at most half its size:
    /// then the half-resolution binned mosaic still exceeds the target — the final
    /// downsample discards that resolution anyway — while the expensive debayer runs
    /// on a quarter of the samples, with no visible loss. A full-resolution render
    /// (no `maxDimension`), a non-mosaic source, or a smaller reduction returns `1`
    /// (the identity — no binning).
    ///
    /// - Parameters:
    ///   - maxSide:      The source's larger dimension, in pixels.
    ///   - maxDimension: The rendered image's dimension cap, or `nil` for full resolution.
    ///   - isMosaic:     Whether the source is a colour-filter-array mosaic.
    /// - Returns: The bin factor (`2`), or `1` when binning does not apply.
    public static func previewBinFactor( maxSide: Int, maxDimension: Int?, isMosaic: Bool ) -> Int
    {
        guard isMosaic, let maxDimension, maxDimension > 0, maxSide >= 2 * maxDimension
        else
        {
            return 1
        }

        return 2
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
