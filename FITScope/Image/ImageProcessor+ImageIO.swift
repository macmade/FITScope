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

/// ImageIO-specific rendering for ``ImageProcessor``: turns a photographic image's
/// decoded, canonically-laid-out samples into channel planes and drives the shared
/// pixel pipeline, plus the per-pixel read-out and detection luminance.
///
/// Photographic formats (TIFF, PNG, JPEG, and, later, RAW and HEIC) are already
/// display-encoded, so unlike the linear FITS/XISF paths their samples are shown
/// **as authored**: the bytes are scaled into `[0, 1]` by the sample format's full
/// scale and the pipeline's identity normalization leaves them unchanged (the
/// per-image baseline sets ``Processors/Normalize/Mode/identity``), rather than
/// being range-stretched by a min/max normalization.
public extension ImageProcessor
{
    /// Renders a decoded photographic image into a displayable `CGImage`, mirroring
    /// the FITS-facing ``render(data:properties:settings:)`` and the XISF-facing
    /// ``render(data:xisf:settings:)`` for the ImageIO formats.
    ///
    /// The bytes are the image's samples as drawn by the loader into a canonical
    /// interleaved layout; this decodes them into channel planes and runs the very
    /// same pipeline the other formats use. The samples are scaled by the format's
    /// full scale into `[0, 1]`, so a source whose baseline uses the identity
    /// normalization displays exactly as authored.
    ///
    /// - Parameters:
    ///   - data:       The image's decoded, canonically-laid-out pixel bytes.
    ///   - properties: The image's pixel layout.
    ///   - settings:   The user-tunable render settings.
    /// - Returns: The ``RenderResult`` with the display image, its 8-bit bytes and
    ///   the input/output pixel formats.
    /// - Throws: ``RuntimeError`` for an unsupported channel count, invalid
    ///   dimensions, or truncated data.
    static func render( data: Data, imageIO properties: BitmapImageProperties, settings: Settings = Settings() ) throws -> RenderResult
    {
        try Self.render( planes: Self.imageIOPlaneSamples( data: data, properties: properties ), imageIO: properties, settings: settings )
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
        // for information only; it never re-decodes bytes from this label.
        let bitsPerPixel: BitsPerPixel = properties.bytesPerComponent >= 2 ? .int16 : .uint8

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
        let scale = 1.0 / properties.fullScale

        switch properties.channelCount
        {
            case 1:  return settings.config( scale: scale, offset: 0, inputFormat: .mono )
            case 3:  return settings.config( scale: scale, offset: 0, inputFormat: .rgb )
            default: throw RuntimeError( message: "Unsupported photographic channel count: \( properties.channelCount )." )
        }
    }

    /// Decodes a photographic image's samples into one plane per meaningful channel,
    /// reading the interleaved layout and skipping any padding component — the
    /// ImageIO analogue of the shared XISF plane extraction and ``rgbPlaneSamples``.
    ///
    /// - Parameters:
    ///   - data:       The image's decoded pixel bytes.
    ///   - properties: The image's pixel layout.
    /// - Returns: One plane per channel, each `width × height` samples.
    /// - Throws: ``RuntimeError`` for an invalid geometry or truncated data.
    ///
    /// Exposed (not private) so ``ImageIORenderSource/decoded()`` can decode the
    /// planes once and render them without decoding the bytes a second time.
    static func imageIOPlaneSamples( data: Data, properties: BitmapImageProperties ) throws -> [ [ Double ] ]
    {
        guard properties.width > 0, properties.height > 0, properties.channelCount > 0,
              properties.componentsPerPixel >= properties.channelCount, properties.bytesPerComponent > 0
        else
        {
            throw RuntimeError( message: "Invalid photographic image geometry: \( properties.width ) × \( properties.height ) × \( properties.channelCount )." )
        }

        let pixelCount     = properties.width * properties.height
        let bytesPerPixel  = properties.componentsPerPixel * properties.bytesPerComponent
        let required       = pixelCount * bytesPerPixel
        let bytes          = Data( data.prefix( required ) ) // re-wrap: startIndex may be non-zero, and trim trailing bytes

        guard bytes.count == required
        else
        {
            throw RuntimeError( message: "Photographic pixel data too small: \( data.count ) < \( required )." )
        }

        return bytes.withUnsafeBytes
        {
            ( raw: UnsafeRawBufferPointer ) -> [ [ Double ] ] in

            ( 0 ..< properties.channelCount ).map
            {
                channel in ( 0 ..< pixelCount ).map
                {
                    pixel in Self.imageIOSample( raw, at: ( pixel * properties.componentsPerPixel + channel ) * properties.bytesPerComponent, bytesPerComponent: properties.bytesPerComponent )
                }
            }
        }
    }

    /// Decodes a single sample from a raw byte buffer at a byte offset. The samples
    /// are stored in the host byte order (little-endian on Apple platforms), matching
    /// the bitmap the loader drew.
    ///
    /// - Parameters:
    ///   - raw:               The byte buffer.
    ///   - offset:            The sample's byte offset into the buffer.
    ///   - bytesPerComponent: The number of bytes per component (`1` or `2`).
    /// - Returns: The decoded value.
    private static func imageIOSample( _ raw: UnsafeRawBufferPointer, at offset: Int, bytesPerComponent: Int ) -> Double
    {
        if bytesPerComponent >= 2
        {
            return Double( raw.loadUnaligned( fromByteOffset: offset, as: UInt16.self ) )
        }

        return Double( raw.load( fromByteOffset: offset, as: UInt8.self ) )
    }

    /// The per-channel decoded samples of a photographic image at `(x, y)` — one
    /// ``PixelValue`` per meaningful channel (three for colour, one for grayscale) —
    /// for the cursor read-out, mirroring ``xisfPixelValues`` / ``rgbPixelValues``.
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
        guard properties.width > 0, properties.height > 0, properties.channelCount > 0,
              x >= 0, x < properties.width, y >= 0, y < properties.height
        else
        {
            return nil
        }

        let pixelIndex = y * properties.width + x
        let fullScale  = properties.fullScale

        let values = ( 0 ..< properties.channelCount ).compactMap
        {
            channel -> PixelValue? in

            let byteOffset = ( pixelIndex * properties.componentsPerPixel + channel ) * properties.bytesPerComponent

            guard byteOffset >= 0, byteOffset + properties.bytesPerComponent <= data.count
            else
            {
                return nil
            }

            let value = data.withUnsafeBytes
            {
                ( raw: UnsafeRawBufferPointer ) in Self.imageIOSample( raw, at: byteOffset, bytesPerComponent: properties.bytesPerComponent )
            }

            return PixelValue( value: value, fraction: value / fullScale )
        }

        return values.count == properties.channelCount ? values : nil
    }

    /// The per-pixel luminance (mean of the channels) of a photographic image, as a
    /// single-channel image for star detection and the sky-background measurement —
    /// the ImageIO analogue of the shared linear-luminance decode. A
    /// grayscale image yields its single channel unchanged.
    ///
    /// Unlike the FITS/XISF luminance, these samples are display-encoded (gamma), not
    /// linear, since photographic formats are already display-ready; the detection
    /// stages operate on the encoded values, which is acceptable for locating bright
    /// features.
    ///
    /// - Parameters:
    ///   - data:       The image's decoded pixel bytes.
    ///   - properties: The image's pixel layout.
    /// - Returns: The image dimensions and the linear luminance samples, or `nil`
    ///   when the planes cannot be decoded.
    static func imageIOLinearLuminance( data: Data, properties: BitmapImageProperties ) -> ( width: Int, height: Int, samples: [ Double ] )?
    {
        guard let planes = try? Self.imageIOPlaneSamples( data: data, properties: properties )
        else
        {
            return nil
        }

        return Self.imageIOLinearLuminance( fromPlanes: planes, properties: properties )
    }

    /// The per-pixel luminance (mean of the channels) built from a photographic
    /// image's already-decoded channel planes — the decode-free counterpart of
    /// ``imageIOLinearLuminance(data:properties:)``, so the statistics reuse the
    /// render's decode. A grayscale image yields its single channel unchanged.
    ///
    /// - Parameters:
    ///   - planes:     The already-decoded channel planes.
    ///   - properties: The image's pixel layout.
    /// - Returns: The dimensions and averaged luminance samples, or `nil` when empty.
    static func imageIOLinearLuminance( fromPlanes planes: [ [ Double ] ], properties: BitmapImageProperties ) -> ( width: Int, height: Int, samples: [ Double ] )?
    {
        guard let first = planes.first
        else
        {
            return nil
        }

        let samples = ( 0 ..< first.count ).map
        {
            index -> Double in

            let sum = planes.reduce( 0.0 ) { $0 + $1[ index ] }

            return sum / Double( planes.count )
        }

        return ( width: properties.width, height: properties.height, samples: samples )
    }
}
