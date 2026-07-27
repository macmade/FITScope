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

import Foundation
import SwiftAstro
import SwiftFITS
import SwiftPixel
import SwiftUtilities

/// FITS-specific rendering for ``ImageProcessor``: the FITS-facing render entry,
/// the RGB-planes and multi-image-cube paths, and the header-keyword helpers that
/// interpret `[FITSPropertySnapshot]`.
public extension ImageProcessor
{
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
    /// (`NAXIS = 3` with a third axis of 3 — where
    /// ``SwiftAstro/FITSImageDecoder/channelCount(from:)`` answers `3`),
    /// whose planes are combined into one colour image. A multi-image cube is split
    /// into per-plane 2-D sources by the loader, so each plane reaches here as a 2-D
    /// image; any remaining `NAXIS = 3`
    /// geometry (a physical data cube) is rejected.
    ///
    /// - Parameters:
    ///   - data:       The image HDU's raw pixel bytes.
    ///   - properties: The owning header's property snapshots.
    ///   - settings:   The user-tunable render settings.
    /// - Returns: The ``RenderResult`` with the display image, its 8-bit bytes,
    ///   and the input/output pixel formats (the bytes and formats feed histogram
    ///   computation and the mono-vs-colour display choice).
    /// - Throws: An error for a missing or unsupported `BITPIX`, an unsupported
    ///   geometry (a non-2-D image that is not an RGB colour-planes cube), invalid
    ///   dimensions, truncated data, an image byte size that overflows `Int`, or an
    ///   unsupported `BAYERPAT`. The geometry validation throws ``RuntimeError``;
    ///   the shared decoder's decode throws ``SwiftAstro/Error``.
    static func render( data: Data, properties: [ FITSPropertySnapshot ], settings: Settings = Settings() ) throws -> RenderResult
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
        if nAxis == 3, FITSImageDecoder.channelCount( from: properties ) == 3
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

        // The single-channel decode is the shared decoder's; the app no longer
        // interprets BITPIX / BSCALE / BZERO / BLANK to produce samples. A 2-D frame
        // yields exactly one plane.
        guard let raw = try FITSImageDecoder.planeSamples( bytes: data, properties: properties ).first
        else
        {
            throw RuntimeError( message: "FITS image could not be decoded" )
        }

        return try Self.render( rawSamples: raw, width: width, height: height, bitsPerPixel: bitsPerPixel, properties: properties, settings: settings )
    }

    /// Renders a 2-D image HDU from its already-decoded raw samples — the decode-free
    /// core the byte-based ``render(data:properties:settings:)`` delegates to after
    /// decoding, and which the preview renderer calls directly so a one-shot preview
    /// decodes the frame only once (sharing the samples with the auto-stretch
    /// statistics).
    ///
    /// - Parameters:
    ///   - rawSamples:   The image HDU's raw, unscaled samples, in row-major order.
    ///   - width:        The image width in pixels.
    ///   - height:       The image height in pixels.
    ///   - bitsPerPixel: The sample format the samples were decoded from.
    ///   - properties:   The owning header's property snapshots (scaling, `BAYERPAT`).
    ///   - settings:     The render settings.
    /// - Returns: The render result.
    /// - Throws: Any error building the configuration or running the pipeline.
    static func render( rawSamples: [ Double ], width: Int, height: Int, bitsPerPixel: BitsPerPixel, properties: [ FITSPropertySnapshot ], settings: Settings ) throws -> RenderResult
    {
        let bayerPattern = try FITSImageDecoder.cfaPattern( from: properties )

        let ( scale, offset ) = FITSImageDecoder.scaling( from: properties )
        let fullScale         = Self.fullScaleScaling( scale: scale, offset: offset, properties: properties )

        // Bin the mosaic before the demosaic when heavily downsampling a colour-
        // filter-array preview, so the expensive debayer runs on a smaller mosaic.
        let binFactor = ImageProcessor.previewBinFactor( maxSide: Swift.max( width, height ), maxDimension: settings.maxDimension, isMosaic: bayerPattern != nil )
        let config    = settings.config( scale: fullScale.scale, offset: fullScale.offset, headerPattern: bayerPattern, binFactor: binFactor )

        return try Self.render( pixels: rawSamples, width: width, height: height, bitsPerPixel: bitsPerPixel, config: config )
    }

    /// Decodes a 2-D image HDU's raw, unscaled samples once, for a caller that will
    /// feed them to both the auto-stretch statistics and ``render(rawSamples:width:height:bitsPerPixel:properties:settings:)``.
    ///
    /// Returns `nil` for anything that is not a directly-decodable 2-D image (an RGB
    /// colour-plane frame, a data cube, or a truncated / unsupported HDU); the caller
    /// then falls back to the byte-based path.
    ///
    /// - Parameters:
    ///   - data:       The image HDU's raw pixel bytes.
    ///   - properties: The owning header's property snapshots.
    /// - Returns: The raw samples with their geometry and sample format, or `nil`.
    static func decodedImageHDU( data: Data, properties: [ FITSPropertySnapshot ] ) -> ( samples: [ Double ], width: Int, height: Int, bitsPerPixel: BitsPerPixel )?
    {
        guard let bitsPerPixel = FITSImageDecoder.bitsPerPixel( from: properties ),
              properties.first( where: { $0.name == "NAXIS" } )?.value.integer == 2,
              let ( width, height ) = FITSImageDecoder.dimensions( from: properties ),
              let raw = try? FITSImageDecoder.planeSamples( bytes: data, properties: properties ).first
        else
        {
            return nil
        }

        return ( samples: raw, width: width, height: height, bitsPerPixel: bitsPerPixel )
    }

    /// The auto-stretch colour source for a 2-D image HDU built from already-decoded
    /// raw samples, so the statistics reuse the render's decode instead of decoding a
    /// second time.
    ///
    /// Applies the header's affine scaling and tags the single channel by its layout:
    /// a colour-filter-array frame becomes a ``AutoStretchColorSource/mosaic(_:pattern:)``
    /// (split per channel by the derivation), any other 2-D frame a
    /// ``AutoStretchColorSource/mono(_:)``. Matches the byte-based
    /// ``autoStretchColorSource(forImageHDU:properties:)`` / mono-luminance fallback
    /// for the same bytes.
    ///
    /// - Parameters:
    ///   - samples:    The raw, unscaled samples.
    ///   - width:      The image width in pixels.
    ///   - height:     The image height in pixels.
    ///   - properties: The owning header's property snapshots.
    /// - Returns: The colour source, or `nil` when it cannot be built or the pattern
    ///   is unsupported.
    static func autoStretchColorSource( fromSamples samples: [ Double ], width: Int, height: Int, properties: [ FITSPropertySnapshot ] ) -> AutoStretchColorSource?
    {
        let ( scale, offset ) = FITSImageDecoder.scaling( from: properties )
        let scaled            = samples.map { $0 * scale + offset }

        guard let buffer = try? PixelBuffer( width: width, height: height, channels: 1, pixels: scaled, isNormalized: false )
        else
        {
            return nil
        }

        if let pattern = ( try? FITSImageDecoder.cfaPattern( from: properties ) ) ?? nil
        {
            return .mosaic( buffer, pattern: pattern )
        }

        return .mono( buffer )
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
    /// - Throws: ``RuntimeError`` for invalid dimensions, truncated data, or an image byte size that overflows `Int`.
    private static func renderRGBPlanes( data: Data, properties: [ FITSPropertySnapshot ], bitsPerPixel: BitsPerPixel, settings: Settings ) throws -> RenderResult
    {
        let planes            = try Self.rgbPlaneSamples( data: data, properties: properties )
        let ( scale, offset ) = FITSImageDecoder.scaling( from: properties )
        let fullScale         = Self.fullScaleScaling( scale: scale, offset: offset, properties: properties )
        let config            = settings.config( scale: fullScale.scale, offset: fullScale.offset, inputFormat: .rgb )

        return try Self.render( planes: [ planes.red, planes.green, planes.blue ], width: planes.width, height: planes.height, bitsPerPixel: bitsPerPixel, config: config )
    }

    /// Decodes the three band-sequential colour planes of an RGB `NAXIS=3` image
    /// HDU into raw (unscaled) sample arrays, one per plane, through the shared
    /// decoder.
    ///
    /// The `BSCALE`/`BZERO` rescaling is left to the caller (the pipeline's scale
    /// stage for rendering, an explicit rescale for the detection luminance), so
    /// this returns the samples at their stored values.
    ///
    /// - Parameters:
    ///   - data:       The image HDU's raw pixel bytes.
    ///   - properties: The owning header's property snapshots.
    /// - Returns: The plane dimensions and the raw red, green and blue samples.
    /// - Throws: ``RuntimeError`` for invalid dimensions or a frame that is not
    ///   three-plane; ``SwiftAstro/Error`` for truncated data or an image byte size
    ///   that overflows `Int`.
    private static func rgbPlaneSamples( data: Data, properties: [ FITSPropertySnapshot ] ) throws -> ( width: Int, height: Int, red: [ Double ], green: [ Double ], blue: [ Double ] )
    {
        guard let ( width, height ) = FITSImageDecoder.dimensions( from: properties )
        else
        {
            throw RuntimeError( message: "Invalid or missing NAXIS1 / NAXIS2 for an RGB image" )
        }

        let planes = try FITSImageDecoder.planeSamples( bytes: data, properties: properties )

        guard planes.count == 3
        else
        {
            throw RuntimeError( message: "Expected three colour planes for an RGB image, found \( planes.count )" )
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
    static func rgbPixelValues( data: Data, properties: [ FITSPropertySnapshot ], x: Int, y: Int ) -> [ PixelValue ]?
    {
        guard FITSImageDecoder.channelCount( from: properties ) == 3,
              let offsets = FITSImageDecoder.sampleByteOffsets( x: x, y: y, properties: properties )
        else
        {
            return nil
        }

        let ( scale, offset ) = FITSImageDecoder.scaling( from: properties )
        let fullScale         = FITSImageDecoder.fullScale( from: properties )

        let values = offsets.compactMap
        {
            byteOffset -> PixelValue? in

            guard let raw = FITSImageDecoder.decodeSample( bytes: data, at: data.startIndex + byteOffset, properties: properties )
            else
            {
                return nil
            }

            let scaled = raw * scale + offset

            return PixelValue( value: scaled, fraction: fullScale.map { scaled / $0 } )
        }

        return values.count == 3 ? values : nil
    }

    /// Builds the colour input an auto Screen Transfer derives a *per-channel*
    /// (unlinked) STF from, for a FITS image HDU — or `nil` for a monochrome frame,
    /// which the caller resolves to its own mono luminance.
    ///
    /// An RGB `NAXIS=3` image yields ``AutoStretchColorSource/channels(_:)`` from its
    /// three scaled-linear planes (interleaved); a colour-filter-array frame yields
    /// ``AutoStretchColorSource/mosaic(_:pattern:)`` from its raw scaled-linear mosaic
    /// and `BAYERPAT` pattern (split per channel by the derivation, no demosaic). A
    /// mono frame — or one whose colour data cannot be decoded — returns `nil`, so a
    /// caller can fall back to the single-channel luminance and derive a uniform STF.
    /// The samples are in the same scaled-linear domain as the shared decoder's linear
    /// image and luminance, so the shared derivation's
    /// `1 / fullScale` scaling lands them in the same `[0, 1]` domain the render applies
    /// the STF over.
    ///
    /// - Parameters:
    ///   - data:       The image HDU's raw pixel bytes.
    ///   - properties: The owning header's property snapshots.
    /// - Returns: The per-channel colour input, or `nil` for a mono / undecodable frame.
    static func autoStretchColorSource( forImageHDU data: Data, properties: [ FITSPropertySnapshot ] ) -> AutoStretchColorSource?
    {
        let ( scale, offset ) = FITSImageDecoder.scaling( from: properties )

        if FITSImageDecoder.channelCount( from: properties ) == 3,
           let ( width, height ) = FITSImageDecoder.dimensions( from: properties ),
           let planes      = try? FITSImageDecoder.planeSamples( bytes: data, properties: properties ),
           let interleaved = try? PixelUtilities.interleave( planes: planes.map { $0.map { $0 * scale + offset } } ),
           let buffer      = try? PixelBuffer( width: width, height: height, channels: 3, pixels: interleaved, isNormalized: false )
        {
            return .channels( buffer )
        }

        if let pattern = ( try? FITSImageDecoder.cfaPattern( from: properties ) ) ?? nil,
           let mosaic  = FITSImageDecoder.linearImage( bytes: data, properties: properties ),
           let buffer  = try? PixelBuffer( width: mosaic.width, height: mosaic.height, channels: 1, pixels: mosaic.samples, isNormalized: false )
        {
            return .mosaic( buffer, pattern: pattern )
        }

        return nil
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
    static func rawPixelValue( data: Data, properties: [ FITSPropertySnapshot ], x: Int, y: Int ) -> PixelValue?
    {
        guard let byteOffset = FITSImageDecoder.sampleByteOffsets( x: x, y: y, properties: properties )?.first,
              let raw        = FITSImageDecoder.decodeSample( bytes: data, at: data.startIndex + byteOffset, properties: properties )
        else
        {
            return nil
        }

        let ( scale, offset ) = FITSImageDecoder.scaling( from: properties )
        let scaled            = raw * scale + offset

        return PixelValue( value: scaled, fraction: FITSImageDecoder.fullScale( from: properties ).map { scaled / $0 } )
    }

    /// Folds the format's full scale into the affine `BSCALE`/`BZERO` scaling, so
    /// integer samples render in their native full-scale `[0, 1]` domain — the same
    /// `1 / fullScale` scaling the XISF path applies.
    ///
    /// A value `raw` renders as `(raw · scale + offset) / fullScale`, i.e.
    /// `raw · (scale / fullScale) + (offset / fullScale)`. This is transparent to the
    /// default min/max normalization (min/max is invariant under a positive affine
    /// transform), while letting an ``Processors/Normalize/Mode/identity`` baseline —
    /// used when opening with a Screen Transfer — act on the true full-scale domain.
    /// Floating-point formats have no fixed full scale and pass through unchanged.
    ///
    /// - Parameters:
    ///   - scale:      The multiplicative scale from `BSCALE`.
    ///   - offset:     The additive offset from `BZERO`.
    ///   - properties: The frame's header — its `BITPIX` gives the full-scale span,
    ///                 through the shared decoder.
    /// - Returns: The full-scale-folded scale and offset.
    private static func fullScaleScaling( scale: Double, offset: Double, properties: [ FITSPropertySnapshot ] ) -> ( scale: Double, offset: Double )
    {
        guard let fullScale = FITSImageDecoder.fullScale( from: properties ), fullScale > 0
        else
        {
            return ( scale: scale, offset: offset )
        }

        return ( scale: scale / fullScale, offset: offset / fullScale )
    }
}
