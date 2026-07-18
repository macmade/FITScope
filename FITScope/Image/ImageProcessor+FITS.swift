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
    ///   cube), invalid dimensions, truncated data, an image byte size that
    ///   overflows `Int`, or an unsupported `BAYERPAT`.
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

        guard let size = bitsPerPixel.size( numberOfPixels: width * height )
        else
        {
            throw RuntimeError( message: "FITS image byte size overflows Int" )
        }

        let pixelData = Data( data.prefix( size ) ) // re-wrap: startIndex may be non-zero

        guard pixelData.count == size
        else
        {
            throw RuntimeError( message: "Data too small: \( data.count ) < \( size )" )
        }

        let raw = try PixelUtilities.readRawPixels( data: pixelData, width: width, height: height, bitsPerPixel: bitsPerPixel, blank: Self.blankValue( from: properties ) )

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
        let bayerPattern = try Self.bayerPattern( from: properties )

        let ( scale, offset ) = ImageProcessor.scaling( from: properties )
        let fullScale         = Self.fullScaleScaling( scale: scale, offset: offset, bitsPerPixel: bitsPerPixel )

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
        guard let bitPix       = properties.first( where: { $0.name == "BITPIX" } )?.value.integer,
              let bitsPerPixel = BitsPerPixel.from( value: bitPix ),
              let nAxis        = properties.first( where: { $0.name == "NAXIS" } )?.value.integer,
              nAxis == 2,
              Self.isRGBPlanes( properties: properties ) == false,
              let ( width, height ) = Self.imageDimensions( from: properties )
        else
        {
            return nil
        }

        guard let size = bitsPerPixel.size( numberOfPixels: width * height )
        else
        {
            return nil
        }

        let pixelData = Data( data.prefix( size ) )

        guard pixelData.count == size,
              let raw = try? PixelUtilities.readRawPixels( data: pixelData, width: width, height: height, bitsPerPixel: bitsPerPixel, blank: Self.blankValue( from: properties ) )
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
        let ( scale, offset ) = ImageProcessor.scaling( from: properties )
        let scaled            = samples.map { $0 * scale + offset }

        guard let buffer = try? PixelBuffer( width: width, height: height, channels: 1, pixels: scaled, isNormalized: false )
        else
        {
            return nil
        }

        if let pattern = ( try? Self.bayerPattern( from: properties ) ) ?? nil
        {
            return .mosaic( buffer, pattern: pattern )
        }

        return .mono( buffer )
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
    static func isRGBPlanes( properties: [ FITSPropertySnapshot ] ) -> Bool
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
    static func isMultiImageCube( properties: [ FITSPropertySnapshot ] ) -> Bool
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
    static func cubePlanes( data: Data, properties: [ FITSPropertySnapshot ] ) -> [ ( data: Data, properties: [ FITSPropertySnapshot ] ) ]
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

        guard let planeSize = bitsPerPixel.size( numberOfPixels: width * height ), planeSize > 0
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
    static func linearImage( data: Data, properties: [ FITSPropertySnapshot ] ) -> ( width: Int, height: Int, samples: [ Double ] )?
    {
        guard let bitPix       = properties.first( where: { $0.name == "BITPIX" } )?.value.integer,
              let bitsPerPixel = BitsPerPixel.from( value: bitPix ),
              let ( width, height ) = Self.imageDimensions( from: properties )
        else
        {
            return nil
        }

        // Trim any FITS block padding to the exact sample-data size (and re-wrap so a
        // non-zero start index reads from zero), as `render` and `rgbPlaneSamples` do —
        // `readRawPixels` requires an exact byte count, so the padded section data must
        // not be passed through whole.
        guard let size = bitsPerPixel.size( numberOfPixels: width * height )
        else
        {
            return nil
        }

        let pixelData = Data( data.prefix( size ) )

        guard pixelData.count == size,
              let raw = try? PixelUtilities.readRawPixels( data: pixelData, width: width, height: height, bitsPerPixel: bitsPerPixel, blank: Self.blankValue( from: properties ) )
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
    /// - Throws: ``RuntimeError`` for invalid dimensions, truncated data, or an image byte size that overflows `Int`.
    private static func renderRGBPlanes( data: Data, properties: [ FITSPropertySnapshot ], bitsPerPixel: BitsPerPixel, settings: Settings ) throws -> RenderResult
    {
        let planes            = try Self.rgbPlaneSamples( data: data, properties: properties, bitsPerPixel: bitsPerPixel )
        let ( scale, offset ) = ImageProcessor.scaling( from: properties )
        let fullScale         = Self.fullScaleScaling( scale: scale, offset: offset, bitsPerPixel: bitsPerPixel )
        let config            = settings.config( scale: fullScale.scale, offset: fullScale.offset, inputFormat: .rgb )

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
    /// - Throws: ``RuntimeError`` for invalid dimensions, truncated data, or an image byte size that overflows `Int`.
    private static func rgbPlaneSamples( data: Data, properties: [ FITSPropertySnapshot ], bitsPerPixel: BitsPerPixel ) throws -> ( width: Int, height: Int, red: [ Double ], green: [ Double ], blue: [ Double ] )
    {
        guard let ( width, height ) = Self.imageDimensions( from: properties )
        else
        {
            throw RuntimeError( message: "Invalid or missing NAXIS1 / NAXIS2 for an RGB image" )
        }

        guard let planeSize = bitsPerPixel.size( numberOfPixels: width * height )
        else
        {
            throw RuntimeError( message: "FITS image byte size overflows Int" )
        }

        guard let total = Self.checkedProduct( planeSize, 3 )
        else
        {
            throw RuntimeError( message: "FITS image byte size overflows Int" )
        }

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

            return try PixelUtilities.readRawPixels( data: slice, width: width, height: height, bitsPerPixel: bitsPerPixel, blank: Self.blankValue( from: properties ) )
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
        guard Self.isRGBPlanes( properties: properties ),
              let bitPix       = properties.first( where: { $0.name == "BITPIX" } )?.value.integer,
              let bitsPerPixel = BitsPerPixel.from( value: bitPix ),
              let ( width, height ) = Self.imageDimensions( from: properties ),
              x >= 0, x < width, y >= 0, y < height
        else
        {
            return nil
        }

        guard let bytesPerSample = bitsPerPixel.size( numberOfPixels: 1 )
        else
        {
            return nil
        }

        guard let planeSampleCount = Self.checkedProduct( width, height )
        else
        {
            return nil
        }

        let ( scale, offset ) = ImageProcessor.scaling( from: properties )

        let values = ( 0 ..< 3 ).compactMap
        {
            plane -> PixelValue? in

            guard let planeStart  = Self.checkedProduct( plane, planeSampleCount ),
                  let rowStart    = Self.checkedProduct( y, width ),
                  let pixelIndex  = Self.checkedSum( planeStart, rowStart ),
                  let sampleIndex = Self.checkedSum( pixelIndex, x ),
                  let byteOffset  = Self.checkedProduct( sampleIndex, bytesPerSample )
            else
            {
                return nil
            }

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
    static func rgbLinearLuminance( data: Data, properties: [ FITSPropertySnapshot ] ) -> ( width: Int, height: Int, samples: [ Double ] )?
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
    /// The samples are in the same scaled-linear domain as ``linearImage(data:properties:)``
    /// and ``rgbLinearLuminance(data:properties:)``, so the shared derivation's
    /// `1 / fullScale` scaling lands them in the same `[0, 1]` domain the render applies
    /// the STF over.
    ///
    /// - Parameters:
    ///   - data:       The image HDU's raw pixel bytes.
    ///   - properties: The owning header's property snapshots.
    /// - Returns: The per-channel colour input, or `nil` for a mono / undecodable frame.
    static func autoStretchColorSource( forImageHDU data: Data, properties: [ FITSPropertySnapshot ] ) -> AutoStretchColorSource?
    {
        guard let bitPix       = properties.first( where: { $0.name == "BITPIX" } )?.value.integer,
              let bitsPerPixel = BitsPerPixel.from( value: bitPix )
        else
        {
            return nil
        }

        let ( scale, offset ) = ImageProcessor.scaling( from: properties )

        if Self.isRGBPlanes( properties: properties ),
           let planes      = try? Self.rgbPlaneSamples( data: data, properties: properties, bitsPerPixel: bitsPerPixel ),
           let interleaved = try? PixelUtilities.interleave( planes: [ planes.red, planes.green, planes.blue ].map { $0.map { $0 * scale + offset } } ),
           let buffer      = try? PixelBuffer( width: planes.width, height: planes.height, channels: 3, pixels: interleaved, isNormalized: false )
        {
            return .channels( buffer )
        }

        if let pattern = ( try? Self.bayerPattern( from: properties ) ) ?? nil,
           let mosaic  = Self.linearImage( data: data, properties: properties ),
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

    /// Maps the header's `BAYERPAT` keyword to a debayer pattern.
    ///
    /// - Parameter properties: The image HDU's header properties.
    /// - Returns: The colour-filter-array pattern, or `nil` when the header has
    ///   no `BAYERPAT` keyword (i.e. the frame is monochrome).
    /// - Throws: ``RuntimeError`` when `BAYERPAT` holds an unsupported value.
    static func bayerPattern( from properties: [ FITSPropertySnapshot ] ) throws -> Processors.Debayer.Pattern?
    {
        guard let pattern = properties.first( where: { $0.name == "BAYERPAT" } )?.value.string
        else
        {
            return nil
        }

        return try ImageProcessor.debayerPattern( named: pattern )
    }

    /// Reads the image dimensions from the header's `NAXIS1` / `NAXIS2`
    /// keywords.
    ///
    /// - Parameter properties: The image HDU's header properties.
    /// - Returns: The source `width` and `height`, or `nil` if either keyword is
    ///   missing or non-positive.
    static func imageDimensions( from properties: [ FITSPropertySnapshot ] ) -> ( width: Int, height: Int )?
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

    /// Reads the integer `BLANK` undefined-pixel sentinel (FITS 4.0 §5.4.2.2),
    /// which `PixelUtilities.readRawPixels` maps to NaN for an integer image so
    /// blanks are dropped by the non-finite-filtering statistics, exactly as a
    /// float image's NaN blanks are.
    ///
    /// - Parameter properties: The image HDU's header properties.
    /// - Returns: The `BLANK` value, or `nil` when the keyword is absent or not an
    ///   integer (a floating-point image marks blanks with NaN directly).
    static func blankValue( from properties: [ FITSPropertySnapshot ] ) -> Int64?
    {
        properties.first { $0.name == "BLANK" }?.value.integer
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

        guard let bytesPerSample = bitsPerPixel.size( numberOfPixels: 1 )
        else
        {
            return nil
        }

        guard let rowStart    = Self.checkedProduct( y, width ),
              let sampleIndex = Self.checkedSum( rowStart, x ),
              let byteOffset  = Self.checkedProduct( sampleIndex, bytesPerSample )
        else
        {
            return nil
        }

        let ( scale, offset ) = ImageProcessor.scaling( from: properties )

        return Self.sampleValue( data: data, byteOffset: byteOffset, bitsPerPixel: bitsPerPixel, scale: scale, offset: offset )
    }

    /// Multiplies two counts, returning `nil` instead of trapping when the product
    /// overflows `Int` — so a FITS header that declares an enormous geometry cannot
    /// trap the byte-offset arithmetic.
    ///
    /// - Parameters:
    ///   - a: The first factor.
    ///   - b: The second factor.
    /// - Returns: `a × b`, or `nil` on overflow.
    private static func checkedProduct( _ a: Int, _ b: Int ) -> Int?
    {
        let ( product, overflow ) = a.multipliedReportingOverflow( by: b )

        return overflow ? nil : product
    }

    /// Adds two counts, returning `nil` instead of trapping when the sum overflows
    /// `Int`.
    ///
    /// - Parameters:
    ///   - a: The first term.
    ///   - b: The second term.
    /// - Returns: `a + b`, or `nil` on overflow.
    private static func checkedSum( _ a: Int, _ b: Int ) -> Int?
    {
        let ( sum, overflow ) = a.addingReportingOverflow( b )

        return overflow ? nil : sum
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
        guard let bytesPerSample = bitsPerPixel.size( numberOfPixels: 1 ),
              byteOffset >= 0, byteOffset + bytesPerSample <= data.count
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

    /// The full-scale maximum of an image HDU, derived from its `BITPIX`, or `nil`
    /// for a floating-point format or a missing / unsupported `BITPIX`.
    ///
    /// The auto-stretch-on-open path uses this to bring the scaled-linear detection
    /// samples into the native full-scale `[0, 1]` domain the Screen Transfer is
    /// applied in, matching the render configuration.
    ///
    /// - Parameter properties: The image HDU's header properties.
    /// - Returns: The full-scale maximum, or `nil`.
    static func fullScale( forImageHDU properties: [ FITSPropertySnapshot ] ) -> Double?
    {
        guard let bitPix       = properties.first( where: { $0.name == "BITPIX" } )?.value.integer,
              let bitsPerPixel = BitsPerPixel.from( value: bitPix )
        else
        {
            return nil
        }

        return Self.fullScale( for: bitsPerPixel )
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
    ///   - scale:        The multiplicative scale from `BSCALE`.
    ///   - offset:       The additive offset from `BZERO`.
    ///   - bitsPerPixel: The sample format.
    /// - Returns: The full-scale-folded scale and offset.
    private static func fullScaleScaling( scale: Double, offset: Double, bitsPerPixel: BitsPerPixel ) -> ( scale: Double, offset: Double )
    {
        guard let fullScale = Self.fullScale( for: bitsPerPixel ), fullScale > 0
        else
        {
            return ( scale: scale, offset: offset )
        }

        return ( scale: scale / fullScale, offset: offset / fullScale )
    }
}
