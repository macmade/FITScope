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
import SwiftPixel
import SwiftUtilities

/// Camera-RAW rendering for ``ImageProcessor``: decodes a cropped 16-bit sensor
/// mosaic and drives the shared pixel pipeline, plus the per-pixel read-out and
/// detection luminance.
public extension ImageProcessor
{
    /// Renders a decoded RAW file's cropped mosaic into a displayable `CGImage`,
    /// mirroring the FITS/XISF-facing render entries for the RAW format.
    ///
    /// The bytes are the cropped, visible sensor mosaic — one 16-bit sample per pixel
    /// in host byte order, linear and undemosaiced. This decodes them into a single
    /// plane, forms the pipeline input from the colour-filter array (a CFA mosaic is
    /// debayered exactly as the FITS `BAYERPAT` path is, a monochrome sensor is
    /// expanded to RGB), and runs the very same pipeline the FITS/XISF paths use. The
    /// samples are raw sensor values, so no scaling applies; the display normalization
    /// maps their range exactly as for a FITS light frame.
    ///
    /// - Parameters:
    ///   - data:       The cropped mosaic's raw bytes.
    ///   - properties: The image's pixel layout.
    ///   - settings:   The user-tunable render settings.
    /// - Returns: The ``RenderResult`` with the display image, its 8-bit bytes and
    ///   the input/output pixel formats.
    /// - Throws: ``RuntimeError`` for invalid dimensions, truncated data, or an
    ///   unsupported colour-filter-array pattern.
    static func render( data: Data, raw properties: RAWImageProperties, settings: Settings = Settings() ) throws -> RenderResult
    {
        try Self.render( plane: Self.rawImageSamples( data: data, properties: properties ), raw: properties, settings: settings )
    }

    /// Renders a camera-RAW image from its already-decoded mosaic plane — the
    /// decode-free core the byte-based ``render(data:raw:settings:)`` delegates to
    /// after decoding, and which the decode-once render path calls directly so the
    /// mosaic is decoded only once.
    ///
    /// - Parameters:
    ///   - plane:      The already-decoded raw mosaic samples, in row-major order.
    ///   - properties: The image's pixel layout.
    ///   - settings:   The render settings.
    /// - Returns: The render result.
    /// - Throws: Any error building the configuration or running the pipeline.
    static func render( plane: [ Double ], raw properties: RAWImageProperties, settings: Settings ) throws -> RenderResult
    {
        let config = try Self.rawImageConfig( properties: properties, settings: settings )

        return try Self.render( planes: [ plane ], width: properties.width, height: properties.height, bitsPerPixel: .int16, config: config )
    }

    /// Builds the pipeline configuration for a RAW image, selecting the input layout
    /// from the colour-filter array (a CFA mosaic is debayered, a monochrome sensor is
    /// expanded to RGB) and leaving the samples at their raw sensor values (scale 1,
    /// offset 0).
    ///
    /// - Parameters:
    ///   - properties: The image's pixel layout.
    ///   - settings:   The user-tunable render settings.
    /// - Returns: The configured `PixelPipeline.Config`.
    /// - Throws: ``RuntimeError`` for an unsupported colour-filter-array pattern.
    private static func rawImageConfig( properties: RAWImageProperties, settings: Settings ) throws -> PixelPipeline.Config
    {
        // Scale the raw sensor counts into the native full-scale [0, 1] domain by
        // their white level (e.g. 1 / 16383 for a 14-bit sensor), mirroring the XISF
        // 1 / fullScale scaling. This is transparent to the default min/max path
        // (min/max is scale-invariant), while letting an identity baseline — used
        // when opening with an auto Screen Transfer — act on that full-scale domain.
        // A sensor with no reported white level passes through unscaled.
        let scale = properties.whiteLevel.map { $0 > 0 ? 1 / $0 : 1 } ?? 1

        guard let cfaPattern = properties.colorFilterArrayPattern
        else
        {
            return settings.config( scale: scale, offset: 0, inputFormat: .mono )
        }

        let bayer = try ImageProcessor.debayerPattern( named: cfaPattern )

        return settings.config( scale: scale, offset: 0, headerPattern: bayer )
    }

    /// Decodes a RAW image's cropped mosaic into a single plane of raw sample values.
    ///
    /// - Parameters:
    ///   - data:       The cropped mosaic's raw bytes.
    ///   - properties: The image's pixel layout.
    /// - Returns: The `width × height` samples, in row-major order.
    /// - Throws: ``RuntimeError`` for an invalid geometry or truncated data.
    ///
    /// Exposed (not private) so ``RAWRenderSource/decoded()`` can decode the mosaic
    /// once and render it without decoding the bytes a second time.
    static func rawImageSamples( data: Data, properties: RAWImageProperties ) throws -> [ Double ]
    {
        guard properties.width > 0, properties.height > 0
        else
        {
            throw RuntimeError( message: "Invalid RAW image geometry: \( properties.width ) × \( properties.height )." )
        }

        let count    = properties.width * properties.height
        let required = count * MemoryLayout< UInt16 >.size
        let bytes    = Data( data.prefix( required ) ) // re-wrap: startIndex may be non-zero, and trim trailing bytes

        guard bytes.count == required
        else
        {
            throw RuntimeError( message: "RAW pixel data too small: \( data.count ) < \( required )." )
        }

        // The mosaic bytes are produced and consumed in-process (the loader crops the
        // sensor buffer to this Data), so they carry the host byte order and need no
        // endianness swap.
        return bytes.withUnsafeBytes
        {
            ( raw: UnsafeRawBufferPointer ) -> [ Double ] in

            ( 0 ..< count ).map
            {
                Double( raw.loadUnaligned( fromByteOffset: $0 * MemoryLayout< UInt16 >.size, as: UInt16.self ) )
            }
        }
    }

    /// The decoded sample at image coordinates `(x, y)` as a single-element array (a
    /// RAW mosaic is single-channel), for the cursor read-out, mirroring
    /// ``xisfPixelValues`` / ``imageIOPixelValues``.
    ///
    /// - Parameters:
    ///   - data:       The cropped mosaic's raw bytes.
    ///   - properties: The image's pixel layout.
    ///   - x:          The zero-based column, left to right.
    ///   - y:          The zero-based row, top to bottom.
    /// - Returns: A single-element value array, or `nil` for out-of-bounds coordinates
    ///   or truncated data.
    static func rawImagePixelValues( data: Data, properties: RAWImageProperties, x: Int, y: Int ) -> [ PixelValue ]?
    {
        guard properties.width > 0, properties.height > 0,
              x >= 0, x < properties.width, y >= 0, y < properties.height
        else
        {
            return nil
        }

        let byteOffset = ( y * properties.width + x ) * MemoryLayout< UInt16 >.size

        guard byteOffset >= 0, byteOffset + MemoryLayout< UInt16 >.size <= data.count
        else
        {
            return nil
        }

        let value = data.withUnsafeBytes
        {
            ( raw: UnsafeRawBufferPointer ) in Double( raw.loadUnaligned( fromByteOffset: byteOffset, as: UInt16.self ) )
        }

        return [ PixelValue( value: value, fraction: properties.whiteLevel.map { value / $0 } ) ]
    }

    /// The per-pixel linear image of a RAW mosaic — the raw single-channel samples —
    /// as the basis for the detection input, mirroring ``xisfLinearLuminance``. The
    /// loader demosaics this to a luminance channel for a CFA sensor before detection.
    ///
    /// - Parameters:
    ///   - data:       The cropped mosaic's raw bytes.
    ///   - properties: The image's pixel layout.
    /// - Returns: The image dimensions and the linear samples, or `nil` when the plane
    ///   cannot be decoded.
    static func rawImageLinearLuminance( data: Data, properties: RAWImageProperties ) -> ( width: Int, height: Int, samples: [ Double ] )?
    {
        guard let samples = try? Self.rawImageSamples( data: data, properties: properties )
        else
        {
            return nil
        }

        return ( width: properties.width, height: properties.height, samples: samples )
    }

    /// Builds the colour input an auto Screen Transfer derives a *per-channel*
    /// (unlinked) STF from, for a camera-RAW image — or `nil` for a monochrome
    /// sensor, which the caller resolves to its own mono luminance.
    ///
    /// A camera-RAW frame is always a single-sensor mosaic: a colour-filter-array
    /// sensor yields ``AutoStretchColorSource/mosaic(_:pattern:)`` from its raw mosaic
    /// and CFA pattern (split per channel by the derivation, no demosaic), while a
    /// monochrome sensor (no CFA pattern) returns `nil` so the caller falls back to the
    /// mono luminance and a uniform STF. The samples are the raw sensor counts, the
    /// same domain ``rawImageLinearLuminance(data:properties:)`` produces, so the shared
    /// derivation's `1 / fullScale` scaling (against the sensor's white level) lands
    /// them in `[0, 1]`.
    ///
    /// - Parameters:
    ///   - data:       The cropped mosaic's raw bytes.
    ///   - properties: The image's pixel layout.
    /// - Returns: The per-channel colour input, or `nil` for a monochrome sensor.
    static func rawAutoStretchColorSource( data: Data, properties: RAWImageProperties ) -> AutoStretchColorSource?
    {
        // Short-circuit on the CFA pattern before decoding: a monochrome sensor has no
        // per-channel colour input, so it returns nil without decoding the mosaic,
        // matching the fast path the caller relied on before the fromPlane split.
        guard let cfaPattern = properties.colorFilterArrayPattern,
              ( try? ImageProcessor.debayerPattern( named: cfaPattern ) ) != nil,
              let mosaic      = Self.rawImageLinearLuminance( data: data, properties: properties )
        else
        {
            return nil
        }

        return Self.rawAutoStretchColorSource( fromPlane: mosaic.samples, properties: properties )
    }

    /// The per-channel auto-stretch colour input for a camera-RAW image built from its
    /// already-decoded mosaic plane — the decode-free counterpart of
    /// ``rawAutoStretchColorSource(data:properties:)``, so the statistics reuse the
    /// render's decode. Produces the identical colour source for the same samples:
    /// a colour-filter-array sensor yields ``AutoStretchColorSource/mosaic(_:pattern:)``,
    /// while a monochrome sensor (no CFA pattern) returns `nil` so the caller falls
    /// back to the mono luminance.
    ///
    /// - Parameters:
    ///   - plane:      The already-decoded raw mosaic samples.
    ///   - properties: The image's pixel layout.
    /// - Returns: The per-channel colour input, or `nil` for a monochrome sensor.
    static func rawAutoStretchColorSource( fromPlane plane: [ Double ], properties: RAWImageProperties ) -> AutoStretchColorSource?
    {
        guard let cfaPattern = properties.colorFilterArrayPattern,
              let pattern     = try? ImageProcessor.debayerPattern( named: cfaPattern ),
              let buffer      = try? PixelBuffer( width: properties.width, height: properties.height, channels: 1, pixels: plane, isNormalized: false )
        else
        {
            return nil
        }

        return .mosaic( buffer, pattern: pattern )
    }
}
