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

/// ImageIO-specific rendering for ``ImageProcessor``: drives the shared pixel pipeline
/// from a photographic image's decoded, canonically-laid-out samples, plus the
/// per-pixel read-out.
///
/// The draw, the sample decode and the detection image all live in the shared
/// ``BitmapImageDecoder`` (SwiftAstro); this extension keeps only what exists because
/// the app renders and presents — building the pipeline configuration and reading out
/// a pixel under the cursor.
///
/// Photographic formats (TIFF, PNG, JPEG, and, through the same ImageIO path, RAW and
/// HEIC) are already display-encoded, so unlike the linear FITS/XISF paths their
/// samples are shown **as authored**: the bytes are scaled into `[0, 1]` by the sample
/// format's full scale and the pipeline's identity normalization leaves them unchanged
/// (the per-image baseline sets ``Processors/Normalize/Mode/identity``), rather than
/// being range-stretched by a min/max normalization.
public extension ImageProcessor
{
    /// Renders a decoded photographic image into a displayable `CGImage`, mirroring
    /// the FITS-facing ``render(data:properties:settings:)`` and the XISF-facing
    /// ``render(data:xisf:settings:)`` for the ImageIO formats.
    ///
    /// The bytes are the image's samples as drawn by the loader into a canonical
    /// interleaved layout; this decodes them into channel planes through the shared
    /// ``BitmapImageDecoder`` and runs the very same pipeline the other formats use. The
    /// samples are scaled by the format's full scale into `[0, 1]`, so a source whose
    /// baseline uses the identity normalization displays exactly as authored.
    ///
    /// - Parameters:
    ///   - data:       The image's decoded, canonically-laid-out pixel bytes.
    ///   - properties: The image's pixel layout.
    ///   - settings:   The user-tunable render settings.
    /// - Returns: The ``RenderResult`` with the display image, its 8-bit bytes and
    ///   the input/output pixel formats.
    /// - Throws: An error for an unsupported channel count, invalid dimensions, or
    ///   truncated data.
    static func render( data: Data, imageIO properties: BitmapImageProperties, settings: Settings = Settings() ) throws -> RenderResult
    {
        try Self.render( planes: BitmapImageDecoder.planeSamples( bytes: data, properties: properties ), imageIO: properties, settings: settings )
    }

    /// Renders a photographic image from its already-decoded channel planes — the
    /// decode-free core the byte-based ``render(data:imageIO:settings:)`` delegates to
    /// after decoding, and which the decode-once render path calls directly so the
    /// image is decoded only once.
    ///
    /// - Parameters:
    ///   - planes:     The already-decoded channel planes.
    ///   - properties: The image's pixel layout.
    ///   - settings:   The render settings.
    /// - Returns: The render result.
    /// - Throws: Any error building the configuration or running the pipeline.
    static func render( planes: [ [ Double ] ], imageIO properties: BitmapImageProperties, settings: Settings ) throws -> RenderResult
    {
        let config = try Self.imageIOConfig( properties: properties, settings: settings )

        // The plane render path consumes decoded Doubles, so the bit depth is passed
        // for information only; it never re-decodes bytes from this label. The shared
        // decoder answers every bitmap layout, so the 8-bit default is never taken.
        let bitsPerPixel = BitmapImageDecoder.bitsPerPixel( from: properties ) ?? .uint8

        return try Self.render( planes: planes, width: properties.width, height: properties.height, bitsPerPixel: bitsPerPixel, config: config )
    }

    /// Builds the pipeline configuration for a photographic image, selecting the
    /// input layout from the channel count and scaling the samples into `[0, 1]` by
    /// the format's full scale (so the identity normalization shows them as
    /// authored).
    ///
    /// - Parameters:
    ///   - properties: The image's pixel layout.
    ///   - settings:   The user-tunable render settings.
    /// - Returns: The configured `PixelPipeline.Config`.
    /// - Throws: ``RuntimeError`` for an unsupported channel count.
    private static func imageIOConfig( properties: BitmapImageProperties, settings: Settings ) throws -> PixelPipeline.Config
    {
        // Scale the drawn components into the native full-scale [0, 1] domain by the
        // format's full scale (1 / 255 for 8-bit, 1 / 65535 for 16-bit), taken from the
        // shared decoder, mirroring the XISF / RAW 1 / fullScale scaling. This is
        // transparent to the default min/max path (min/max is scale-invariant), while
        // letting an identity baseline — the as-authored photographic default — show
        // the stored values unchanged. The additive offset is the decoder's affine
        // offset, 0 for a drawn bitmap (the components are already their stored values).
        let ( _, offset ) = BitmapImageDecoder.scaling( from: properties )
        let scale         = BitmapImageDecoder.fullScale( from: properties ).map { $0 > 0 ? 1 / $0 : 1 } ?? 1

        switch properties.channelCount
        {
            case 1:  return settings.config( scale: scale, offset: offset, inputFormat: .mono )
            case 3:  return settings.config( scale: scale, offset: offset, inputFormat: .rgb )
            default: throw RuntimeError( message: "Unsupported photographic channel count: \( properties.channelCount )." )
        }
    }

    /// The per-channel decoded samples of a photographic image at `(x, y)` — one
    /// ``PixelValue`` per meaningful channel (three for colour, one for grayscale) —
    /// for the cursor read-out, mirroring ``xisfPixelValues`` / ``rawImagePixelValues``.
    ///
    /// The byte offsets and the single-component decode both come from the shared
    /// ``BitmapImageDecoder``; this composes the presentation ``PixelValue`` from the
    /// sample and the format's full scale.
    ///
    /// - Parameters:
    ///   - data:       The image's decoded pixel bytes.
    ///   - properties: The image's pixel layout.
    ///   - x:          The zero-based column, left to right.
    ///   - y:          The zero-based row, top to bottom.
    /// - Returns: One value per channel, or `nil` for out-of-bounds coordinates or
    ///   truncated data.
    static func imageIOPixelValues( data: Data, properties: BitmapImageProperties, x: Int, y: Int ) -> [ PixelValue ]?
    {
        guard let offsets = BitmapImageDecoder.sampleByteOffsets( x: x, y: y, properties: properties )
        else
        {
            return nil
        }

        let fullScale = BitmapImageDecoder.fullScale( from: properties )

        let values = offsets.compactMap
        {
            byteOffset -> PixelValue? in

            guard let value = BitmapImageDecoder.decodeSample( bytes: data, at: data.startIndex + byteOffset, properties: properties )
            else
            {
                return nil
            }

            return PixelValue( value: value, fraction: fullScale.map { value / $0 } )
        }

        return values.count == properties.channelCount ? values : nil
    }
}
