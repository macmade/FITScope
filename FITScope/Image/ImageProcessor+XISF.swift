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
import SwiftPixel
import SwiftUtilities
import SwiftXISF

/// XISF-specific rendering for ``ImageProcessor``: decodes an XISF image's samples
/// into channel planes and drives the shared pixel pipeline, plus the per-pixel
/// read-out and detection luminance.
public extension ImageProcessor
{
    /// Renders a decoded XISF image into a displayable `CGImage`, mirroring the
    /// FITS-facing ``render(data:properties:settings:)`` for the XISF format.
    ///
    /// The bytes are the image's already-decompressed, un-shuffled samples (as
    /// vended by `XISFImage.data`); this decodes them into channel planes per the
    /// layout's sample format, byte order and storage model, forms the pipeline
    /// input from the colour space (grayscale expanded to RGB, a colour-filter array
    /// debayered, RGB passed through), and runs the very same pipeline the FITS path
    /// uses. XISF samples are already physical values, so no `BSCALE`/`BZERO` scaling
    /// applies; the display normalization maps their range exactly as for FITS.
    ///
    /// - Parameters:
    ///   - data:       The image's raw (decompressed) pixel bytes.
    ///   - properties: The image's pixel layout.
    ///   - settings:   The user-tunable render settings.
    /// - Returns: The ``RenderResult`` with the display image, its 8-bit bytes and
    ///   the input/output pixel formats.
    /// - Throws: ``RuntimeError`` for an unsupported sample format or colour space,
    ///   invalid dimensions, or truncated data.
    static func render( data: Data, xisf properties: XISFImageProperties, settings: Settings = Settings() ) throws -> RenderResult
    {
        let planes       = try Self.xisfPlaneSamples( data: data, properties: properties )
        let config       = try Self.xisfConfig( properties: properties, settings: settings )
        let bitsPerPixel = Self.xisfBitsPerPixel( properties.sampleFormat )

        return try Self.render( planes: planes, width: properties.width, height: properties.height, bitsPerPixel: bitsPerPixel, config: config )
    }

    /// Builds the pipeline configuration for an XISF image, selecting the input
    /// layout from its colour space (and colour-filter array, when present) and
    /// scaling the samples into the format's native `[0, 1]` full-scale domain.
    ///
    /// Integer samples decode as raw counts, so they are scaled by `1 / fullScale`
    /// (e.g. `1 / 65535` for `UInt16`) to express the XISF-normalized value the
    /// format encodes; floating-point samples are already in `[0, 1]` and pass
    /// through (scale `1`). This scaling is transparent to the default min/max
    /// normalization (min/max is scale-invariant, so the displayed range is
    /// unchanged), while letting an ``Processors/Normalize/Mode/identity`` baseline —
    /// used when opening with a stored display function — act on the true full-scale
    /// domain the display function was authored in.
    ///
    /// - Parameters:
    ///   - properties: The image's pixel layout.
    ///   - settings:   The user-tunable render settings.
    /// - Returns: The configured `PixelPipeline.Config`.
    /// - Throws: ``RuntimeError`` for a channel-count/colour-space mismatch, an
    ///   unsupported colour space, or an unsupported `BAYERPAT`-equivalent pattern.
    private static func xisfConfig( properties: XISFImageProperties, settings: Settings ) throws -> PixelPipeline.Config
    {
        let scale = Self.xisfFullScale( properties.sampleFormat ).map { 1 / $0 } ?? 1

        switch properties.colorSpace
        {
            case .gray:

                guard properties.channelCount == 1
                else
                {
                    throw RuntimeError( message: "A grayscale XISF image must have a single channel, not \( properties.channelCount )." )
                }

                // A colour-filter-array image is debayered from its single mosaic
                // channel, honouring the user's debayer selection exactly as the FITS
                // BAYERPAT path does; a plain grayscale image is expanded to RGB.
                if let pattern = properties.colorFilterArrayPattern
                {
                    let bayer = try ImageProcessor.debayerPattern( named: pattern )

                    return settings.config( scale: scale, offset: 0, headerPattern: bayer )
                }

                return settings.config( scale: scale, offset: 0, inputFormat: .mono )

            case .rgb:

                guard properties.channelCount == 3
                else
                {
                    throw RuntimeError( message: "An RGB XISF image must have three channels, not \( properties.channelCount )." )
                }

                return settings.config( scale: scale, offset: 0, inputFormat: .rgb )

            case .cieLab:

                throw RuntimeError( message: "The CIE L*a*b* colour space is not supported." )

            @unknown default:

                throw RuntimeError( message: "Unsupported XISF colour space: \( properties.colorSpace.rawValue )." )
        }
    }

    /// Decodes an XISF image's samples into one raw (unscaled) plane per channel,
    /// splitting planar or interleaved storage into channel-contiguous planes — the
    /// XISF analogue of ``rgbPlaneSamples``.
    ///
    /// - Parameters:
    ///   - data:       The image's raw pixel bytes.
    ///   - properties: The image's pixel layout.
    /// - Returns: One plane per channel, each `width × height` samples.
    /// - Throws: ``RuntimeError`` for an invalid geometry, an unsupported sample
    ///   format or storage model, or truncated data.
    private static func xisfPlaneSamples( data: Data, properties: XISFImageProperties ) throws -> [ [ Double ] ]
    {
        guard properties.width > 0, properties.height > 0, properties.channelCount > 0
        else
        {
            throw RuntimeError( message: "Invalid XISF image geometry: \( properties.width ) × \( properties.height ) × \( properties.channelCount )." )
        }

        let pixelCount = properties.width * properties.height
        let samples    = try Self.xisfSamples( data: data, sampleFormat: properties.sampleFormat, byteOrder: properties.byteOrder, count: pixelCount * properties.channelCount )

        if properties.channelCount == 1
        {
            return [ samples ]
        }

        switch properties.pixelStorage
        {
            case .planar:

                // Channel-contiguous: each channel occupies one solid block.
                return ( 0 ..< properties.channelCount ).map
                {
                    channel in Array( samples[ ( channel * pixelCount ) ..< ( ( channel + 1 ) * pixelCount ) ] )
                }

            case .normal:

                // Pixel-interleaved: the channels of each pixel are adjacent.
                return ( 0 ..< properties.channelCount ).map
                {
                    channel in ( 0 ..< pixelCount ).map { samples[ $0 * properties.channelCount + channel ] }
                }

            @unknown default:

                throw RuntimeError( message: "Unsupported XISF pixel storage: \( properties.pixelStorage.rawValue )." )
        }
    }

    /// Decodes `count` XISF samples from raw bytes into `Double`s, honouring the
    /// sample format and byte order. The XISF counterpart of SwiftPixel's
    /// `readRawPixels`, which decodes only the big-endian, signed FITS formats.
    ///
    /// - Parameters:
    ///   - data:         The raw sample bytes.
    ///   - sampleFormat: The stored sample format.
    ///   - byteOrder:    The stored byte order.
    ///   - count:        The number of samples to read.
    /// - Returns: The decoded samples.
    /// - Throws: ``RuntimeError`` for a complex sample format (unsupported) or
    ///   truncated data.
    private static func xisfSamples( data: Data, sampleFormat: XISFSampleFormat, byteOrder: XISFByteOrder, count: Int ) throws -> [ Double ]
    {
        guard sampleFormat.isComplex == false
        else
        {
            throw RuntimeError( message: "Complex XISF sample formats are not supported." )
        }

        let bytesPerSample = sampleFormat.bytesPerSample
        let required       = count * bytesPerSample
        let bytes          = Data( data.prefix( required ) ) // re-wrap: startIndex may be non-zero, and trim trailing bytes

        guard bytes.count == required
        else
        {
            throw RuntimeError( message: "XISF pixel data too small: \( data.count ) < \( required )." )
        }

        let littleEndian = byteOrder != .big

        return bytes.withUnsafeBytes
        {
            ( raw: UnsafeRawBufferPointer ) -> [ Double ] in

            ( 0 ..< count ).map
            {
                Self.xisfDecodeSample( raw, at: $0 * bytesPerSample, sampleFormat: sampleFormat, littleEndian: littleEndian )
            }
        }
    }

    /// Decodes a single sample from a raw byte buffer at a byte offset, applying the
    /// byte order. Shared by the batch ``xisfSamples(data:sampleFormat:byteOrder:count:)``
    /// and the per-pixel ``xisfPixelValues(data:properties:x:y:)`` read-out.
    ///
    /// - Parameters:
    ///   - raw:          The byte buffer.
    ///   - offset:       The sample's byte offset into the buffer.
    ///   - sampleFormat: The stored sample format.
    ///   - littleEndian: Whether the samples are little-endian.
    /// - Returns: The decoded value (`NaN` for an unsupported format, which callers
    ///   reject before reaching here).
    private static func xisfDecodeSample( _ raw: UnsafeRawBufferPointer, at offset: Int, sampleFormat: XISFSampleFormat, littleEndian: Bool ) -> Double
    {
        switch sampleFormat
        {
            case .uInt8:

                return Double( raw.load( fromByteOffset: offset, as: UInt8.self ) )

            case .uInt16:

                let stored = raw.loadUnaligned( fromByteOffset: offset, as: UInt16.self )

                return Double( littleEndian ? UInt16( littleEndian: stored ) : UInt16( bigEndian: stored ) )

            case .uInt32:

                let stored = raw.loadUnaligned( fromByteOffset: offset, as: UInt32.self )

                return Double( littleEndian ? UInt32( littleEndian: stored ) : UInt32( bigEndian: stored ) )

            case .uInt64:

                let stored = raw.loadUnaligned( fromByteOffset: offset, as: UInt64.self )

                return Double( littleEndian ? UInt64( littleEndian: stored ) : UInt64( bigEndian: stored ) )

            case .float32:

                let stored = raw.loadUnaligned( fromByteOffset: offset, as: UInt32.self )

                return Double( Float( bitPattern: littleEndian ? UInt32( littleEndian: stored ) : UInt32( bigEndian: stored ) ) )

            case .float64:

                let stored = raw.loadUnaligned( fromByteOffset: offset, as: UInt64.self )

                return Double( bitPattern: littleEndian ? UInt64( littleEndian: stored ) : UInt64( bigEndian: stored ) )

            case .complex32,
                 .complex64:

                return Double.nan

            @unknown default:

                return Double.nan
        }
    }

    /// The per-channel decoded samples of an XISF image at `(x, y)` — one
    /// ``PixelValue`` per channel (three for RGB, one for grayscale or a CFA mosaic)
    /// — for the cursor read-out, mirroring ``rgbPixelValues`` / ``rawPixelValue``.
    ///
    /// - Parameters:
    ///   - data:       The image's raw pixel bytes.
    ///   - properties: The image's pixel layout.
    ///   - x:          The zero-based column, left to right.
    ///   - y:          The zero-based row, top to bottom.
    /// - Returns: One value per channel, or `nil` for out-of-bounds coordinates, a
    ///   complex sample format, or truncated data.
    static func xisfPixelValues( data: Data, properties: XISFImageProperties, x: Int, y: Int ) -> [ PixelValue ]?
    {
        guard properties.width > 0, properties.height > 0, properties.channelCount > 0,
              x >= 0, x < properties.width, y >= 0, y < properties.height,
              properties.sampleFormat.isComplex == false
        else
        {
            return nil
        }

        let bytesPerSample = properties.sampleFormat.bytesPerSample
        let pixelCount     = properties.width * properties.height
        let pixelIndex     = y * properties.width + x
        let fullScale      = Self.xisfFullScale( properties.sampleFormat )

        let values = ( 0 ..< properties.channelCount ).compactMap
        {
            channel -> PixelValue? in

            let sampleIndex = properties.pixelStorage == .planar ? channel * pixelCount + pixelIndex : pixelIndex * properties.channelCount + channel
            let byteOffset  = sampleIndex * bytesPerSample

            guard byteOffset >= 0, byteOffset + bytesPerSample <= data.count
            else
            {
                return nil
            }

            let value = data.withUnsafeBytes
            {
                ( raw: UnsafeRawBufferPointer ) in Self.xisfDecodeSample( raw, at: byteOffset, sampleFormat: properties.sampleFormat, littleEndian: properties.byteOrder != .big )
            }

            return PixelValue( value: value, fraction: fullScale.map { value / $0 } )
        }

        return values.count == properties.channelCount ? values : nil
    }

    /// The per-pixel luminance (mean of the channels) of an XISF image, as a
    /// single-channel linear image for star detection and the sky-background
    /// measurement — the XISF analogue of ``rgbLinearLuminance``. A grayscale image
    /// yields its single channel unchanged.
    ///
    /// - Parameters:
    ///   - data:       The image's raw pixel bytes.
    ///   - properties: The image's pixel layout.
    /// - Returns: The image dimensions and the linear luminance samples, or `nil`
    ///   when the planes cannot be decoded.
    static func xisfLinearLuminance( data: Data, properties: XISFImageProperties ) -> ( width: Int, height: Int, samples: [ Double ] )?
    {
        guard let planes = try? Self.xisfPlaneSamples( data: data, properties: properties ), let first = planes.first
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

    /// The full-scale value of an integer XISF sample format, used to express a
    /// read-out value as a `0...1` fraction; `nil` for floating-point formats,
    /// which have no fixed full scale.
    ///
    /// - Parameter sampleFormat: The sample format.
    /// - Returns: The maximum representable value, or `nil`.
    static func xisfFullScale( _ sampleFormat: XISFSampleFormat ) -> Double?
    {
        switch sampleFormat
        {
            case .uInt8:      return Double( UInt8.max )
            case .uInt16:     return Double( UInt16.max )
            case .uInt32:     return Double( UInt32.max )
            case .uInt64:     return Double( UInt64.max )
            case .float32,
                 .float64,
                 .complex32,
                 .complex64:  return nil
            @unknown default: return nil
        }
    }

    /// A representative ``BitsPerPixel`` for an XISF sample format, passed to the
    /// pipeline for information only (the plane render path consumes decoded
    /// `Double`s, so it never re-decodes bytes from this).
    ///
    /// - Parameter sampleFormat: The sample format.
    /// - Returns: The closest ``BitsPerPixel`` label.
    private static func xisfBitsPerPixel( _ sampleFormat: XISFSampleFormat ) -> BitsPerPixel
    {
        switch sampleFormat
        {
            case .uInt8:      return .uint8
            case .uInt16:     return .int16
            case .uInt32,
                 .uInt64:     return .int32
            case .float32:    return .float32
            case .float64,
                 .complex32,
                 .complex64:  return .float64
            @unknown default: return .float64
        }
    }
}
