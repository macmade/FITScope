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

/// Camera-RAW rendering for ``ImageProcessor``: drives the shared pixel pipeline from
/// a cropped 16-bit sensor mosaic, plus the per-pixel read-out and the auto-stretch
/// colour input.
///
/// The crop, the sample decode and the detection image all live in the shared
/// ``RAWImageDecoder`` (SwiftAstro); this extension keeps only what exists because the
/// app renders and presents — building the pipeline configuration, reading out a pixel
/// under the cursor, and deriving the auto Screen Transfer colour source.
public extension ImageProcessor
{
    /// Renders a decoded RAW file's cropped mosaic into a displayable `CGImage`,
    /// mirroring the FITS/XISF-facing render entries for the RAW format.
    ///
    /// The bytes are the cropped, visible sensor mosaic — one 16-bit sample per pixel
    /// in host byte order, linear and undemosaiced. This decodes them into a single
    /// plane through the shared ``RAWImageDecoder``, forms the pipeline input from the
    /// colour-filter array (a CFA mosaic is debayered exactly as the FITS `BAYERPAT`
    /// path is, a monochrome sensor is expanded to RGB), and runs the very same pipeline
    /// the FITS/XISF paths use. The samples are raw sensor values, so no scaling applies;
    /// the display normalization maps their range exactly as for a FITS light frame.
    ///
    /// - Parameters:
    ///   - data:       The cropped mosaic's raw bytes.
    ///   - properties: The image's pixel layout.
    ///   - settings:   The user-tunable render settings.
    /// - Returns: The ``RenderResult`` with the display image, its 8-bit bytes and
    ///   the input/output pixel formats.
    /// - Throws: An error for invalid dimensions, truncated data, or an unsupported
    ///   colour-filter-array pattern.
    static func render( data: Data, raw properties: RAWImageProperties, settings: Settings = Settings() ) throws -> RenderResult
    {
        guard let plane = try RAWImageDecoder.planeSamples( bytes: data, properties: properties ).first
        else
        {
            throw RuntimeError( message: "The RAW sensor mosaic decoded to no samples." )
        }

        return try Self.render( plane: plane, raw: properties, settings: settings )
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
        let config       = try Self.rawImageConfig( properties: properties, settings: settings )
        let bitsPerPixel = RAWImageDecoder.bitsPerPixel( from: properties ) ?? .int16

        return try Self.render( planes: [ plane ], width: properties.width, height: properties.height, bitsPerPixel: bitsPerPixel, config: config )
    }

    /// Builds the pipeline configuration for a RAW image, selecting the input layout
    /// from the colour-filter array (a CFA mosaic is debayered, a monochrome sensor is
    /// expanded to RGB) and leaving the samples at their raw sensor values.
    ///
    /// - Parameters:
    ///   - properties: The image's pixel layout.
    ///   - settings:   The user-tunable render settings.
    /// - Returns: The configured `PixelPipeline.Config`.
    /// - Throws: An error for an unsupported colour-filter-array pattern.
    private static func rawImageConfig( properties: RAWImageProperties, settings: Settings ) throws -> PixelPipeline.Config
    {
        // Scale the raw sensor counts into the native full-scale [0, 1] domain by their
        // white level (e.g. 1 / 16383 for a 14-bit sensor), taken from the shared
        // decoder, mirroring the XISF 1 / fullScale scaling. This is transparent to the
        // default min/max path (min/max is scale-invariant), while letting an identity
        // baseline — used when opening with an auto Screen Transfer — act on that
        // full-scale domain. A sensor with no reported white level passes through
        // unscaled. The additive offset is the decoder's affine offset, 0 for RAW (the
        // samples are the physical sensor counts).
        let ( _, offset ) = RAWImageDecoder.scaling( from: properties )
        let scale         = RAWImageDecoder.fullScale( from: properties ).map { $0 > 0 ? 1 / $0 : 1 } ?? 1

        guard let cfaPattern = properties.colorFilterArrayPattern
        else
        {
            return settings.config( scale: scale, offset: offset, inputFormat: .mono )
        }

        let bayer = try ColorFilterArray.pattern( named: cfaPattern )

        return settings.config( scale: scale, offset: offset, headerPattern: bayer )
    }

    /// The decoded sample at image coordinates `(x, y)` as a single-element array (a
    /// RAW mosaic is single-channel), for the cursor read-out, mirroring
    /// ``xisfPixelValues`` / ``imageIOPixelValues``.
    ///
    /// The byte offset and the single-sample decode both come from the shared
    /// ``RAWImageDecoder``; this composes the presentation ``PixelValue`` from the
    /// sample and the sensor's full scale.
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
        guard let offsets = RAWImageDecoder.sampleByteOffsets( x: x, y: y, properties: properties )
        else
        {
            return nil
        }

        let fullScale = RAWImageDecoder.fullScale( from: properties )

        let values = offsets.compactMap
        {
            byteOffset -> PixelValue? in

            guard let value = RAWImageDecoder.decodeSample( bytes: data, at: data.startIndex + byteOffset, properties: properties )
            else
            {
                return nil
            }

            return PixelValue( value: value, fraction: fullScale.map { value / $0 } )
        }

        return values.count == 1 ? values : nil
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
    /// same domain the shared decoder's linear image produces, so the shared
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
              ( try? ColorFilterArray.pattern( named: cfaPattern ) ) != nil,
              let mosaic      = RAWImageDecoder.linearImage( bytes: data, properties: properties )
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
              let pattern     = try? ColorFilterArray.pattern( named: cfaPattern ),
              let buffer      = try? PixelBuffer( width: properties.width, height: properties.height, channels: 1, pixels: plane, isNormalized: false )
        else
        {
            return nil
        }

        return .mosaic( buffer, pattern: pattern )
    }
}
