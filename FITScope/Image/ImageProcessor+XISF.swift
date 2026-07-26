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
import SwiftXISF

/// XISF-specific rendering for ``ImageProcessor``: drives the shared pixel pipeline
/// from an XISF image's decoded channel planes, plus the per-pixel read-out and the
/// auto-stretch colour input.
///
/// The sample decode, plane extraction, luminance and detection image all live in
/// the shared ``XISFImageDecoder`` (SwiftAstro); this extension keeps only what
/// exists because the app renders and presents — building the pipeline
/// configuration, reading out a pixel under the cursor, and deriving the auto Screen
/// Transfer colour source.
public extension ImageProcessor
{
    /// Renders a decoded XISF image into a displayable `CGImage`, mirroring the
    /// FITS-facing ``render(data:properties:settings:)`` for the XISF format.
    ///
    /// The bytes are the image's already-decompressed, un-shuffled samples (as
    /// vended by `XISFImage.data`); this decodes them into channel planes through the
    /// shared ``XISFImageDecoder``, forms the pipeline input from the colour space
    /// (grayscale expanded to RGB, a colour-filter array debayered, RGB passed
    /// through), and runs the very same pipeline the FITS path uses. XISF samples are
    /// already physical values, so no `BSCALE`/`BZERO` scaling applies; the display
    /// normalization maps their range exactly as for FITS.
    ///
    /// - Parameters:
    ///   - data:       The image's raw (decompressed) pixel bytes.
    ///   - properties: The image's pixel layout.
    ///   - settings:   The user-tunable render settings.
    /// - Returns: The ``RenderResult`` with the display image, its 8-bit bytes and
    ///   the input/output pixel formats.
    /// - Throws: An error for an unsupported sample format or colour space, invalid
    ///   dimensions, or truncated data.
    static func render( data: Data, xisf properties: XISFImageProperties, settings: Settings = Settings() ) throws -> RenderResult
    {
        let planes = try XISFImageDecoder.planeSamples( bytes: data, properties: properties )

        return try Self.render( planes: planes, xisf: properties, settings: settings )
    }

    /// Renders an XISF image from its already-decoded channel planes — the decode-free
    /// core the byte-based ``render(data:xisf:settings:)`` delegates to after decoding,
    /// and which the preview renderer calls directly so a one-shot preview decodes the
    /// image only once (sharing the planes with the auto-stretch statistics).
    ///
    /// - Parameters:
    ///   - planes:     The image's already-decoded raw channel planes.
    ///   - properties: The image's pixel layout.
    ///   - settings:   The render settings.
    /// - Returns: The render result.
    /// - Throws: Any error building the configuration or running the pipeline.
    static func render( planes: [ [ Double ] ], xisf properties: XISFImageProperties, settings: Settings ) throws -> RenderResult
    {
        let config       = try Self.xisfConfig( properties: properties, settings: settings )
        let bitsPerPixel = XISFImageDecoder.bitsPerPixel( from: properties ) ?? .float64

        return try Self.render( planes: planes, width: properties.width, height: properties.height, bitsPerPixel: bitsPerPixel, config: config )
    }

    /// Builds the pipeline configuration for an XISF image, selecting the input
    /// layout from its colour space (and colour-filter array, when present) and
    /// scaling the samples into the format's native `[0, 1]` full-scale domain.
    ///
    /// Integer samples decode as raw counts, so they are scaled by `1 / fullScale`
    /// (e.g. `1 / 65535` for `UInt16`) to express the XISF-normalized value the
    /// format encodes; floating-point samples are already in `[0, 1]` and pass
    /// through (scale `1`). The additive offset is the shared decoder's affine offset,
    /// which is `0` for XISF (its samples are stored at their physical values). This
    /// scaling is transparent to the default min/max normalization (min/max is
    /// scale-invariant, so the displayed range is unchanged), while letting an
    /// ``Processors/Normalize/Mode/identity`` baseline — used when opening with a
    /// stored display function — act on the true full-scale domain the display
    /// function was authored in.
    ///
    /// - Parameters:
    ///   - properties: The image's pixel layout.
    ///   - settings:   The user-tunable render settings.
    /// - Returns: The configured `PixelPipeline.Config`.
    /// - Throws: ``RuntimeError`` for a channel-count/colour-space mismatch, an
    ///   unsupported colour space, or an unsupported `BAYERPAT`-equivalent pattern.
    private static func xisfConfig( properties: XISFImageProperties, settings: Settings ) throws -> PixelPipeline.Config
    {
        let ( _, offset ) = XISFImageDecoder.scaling( from: properties )
        let scale         = XISFImageDecoder.fullScale( from: properties ).map { 1 / $0 } ?? 1

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
                    let bayer = try ColorFilterArray.pattern( named: pattern )

                    // Bin the mosaic before the demosaic when heavily downsampling a
                    // colour-filter-array preview, exactly as the FITS path does, so the
                    // expensive debayer runs on a smaller mosaic.
                    let binFactor = ImageProcessor.previewBinFactor( maxSide: Swift.max( properties.width, properties.height ), maxDimension: settings.maxDimension, isMosaic: true )

                    return settings.config( scale: scale, offset: offset, headerPattern: bayer, binFactor: binFactor )
                }

                return settings.config( scale: scale, offset: offset, inputFormat: .mono )

            case .rgb:

                guard properties.channelCount == 3
                else
                {
                    throw RuntimeError( message: "An RGB XISF image must have three channels, not \( properties.channelCount )." )
                }

                return settings.config( scale: scale, offset: offset, inputFormat: .rgb )

            case .cieLab:

                throw RuntimeError( message: "The CIE L*a*b* colour space is not supported." )

            @unknown default:

                throw RuntimeError( message: "Unsupported XISF colour space: \( properties.colorSpace.rawValue )." )
        }
    }

    /// The per-channel decoded samples of an XISF image at `(x, y)` — one
    /// ``PixelValue`` per channel (three for RGB, one for grayscale or a CFA mosaic)
    /// — for the cursor read-out, mirroring ``rgbPixelValues`` / ``rawPixelValue``.
    ///
    /// The byte-offset arithmetic and the single-sample decode both come from the
    /// shared ``XISFImageDecoder``; this composes the presentation ``PixelValue`` from
    /// the sample and the format's full scale.
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
        guard let offsets = XISFImageDecoder.sampleByteOffsets( x: x, y: y, properties: properties )
        else
        {
            return nil
        }

        let fullScale = XISFImageDecoder.fullScale( from: properties )

        let values = offsets.compactMap
        {
            byteOffset -> PixelValue? in

            guard let value = XISFImageDecoder.decodeSample( bytes: data, at: data.startIndex + byteOffset, properties: properties )
            else
            {
                return nil
            }

            return PixelValue( value: value, fraction: fullScale.map { value / $0 } )
        }

        return values.count == properties.channelCount ? values : nil
    }

    /// Builds the colour input an auto Screen Transfer derives a *per-channel*
    /// (unlinked) STF from, for an XISF image — or `nil` for a monochrome frame,
    /// which the caller resolves to its own mono luminance.
    ///
    /// A colour-filter-array frame yields ``AutoStretchColorSource/mosaic(_:pattern:)``
    /// from its raw single-channel mosaic and CFA pattern (split per channel by the
    /// derivation, no demosaic); an RGB frame yields ``AutoStretchColorSource/channels(_:)``
    /// from its three interleaved planes. A grayscale frame — or a `CIELab` one, whose
    /// channels are not RGB — returns `nil`, so a caller falls back to the mono
    /// luminance and a uniform STF. The samples are the raw stored values, the same
    /// domain the shared decoder's linear luminance produces, so the shared
    /// derivation's `1 / fullScale` scaling lands them in `[0, 1]`.
    ///
    /// - Parameters:
    ///   - data:       The image's raw pixel bytes.
    ///   - properties: The image's pixel layout.
    /// - Returns: The per-channel colour input, or `nil` for a mono / non-RGB frame.
    static func xisfAutoStretchColorSource( data: Data, properties: XISFImageProperties ) -> AutoStretchColorSource?
    {
        guard let planes = try? XISFImageDecoder.planeSamples( bytes: data, properties: properties )
        else
        {
            return nil
        }

        return Self.xisfAutoStretchColorSource( fromPlanes: planes, properties: properties )
    }

    /// The per-channel auto-stretch colour input for an XISF image built from its
    /// already-decoded channel planes — the decode-free counterpart of
    /// ``xisfAutoStretchColorSource(data:properties:)``, so the statistics reuse the
    /// render's decode. Produces the identical colour source for the same bytes.
    ///
    /// - Parameters:
    ///   - planes:     The image's already-decoded raw channel planes.
    ///   - properties: The image's pixel layout.
    /// - Returns: The per-channel colour input, or `nil` for a mono / non-RGB frame.
    static func xisfAutoStretchColorSource( fromPlanes planes: [ [ Double ] ], properties: XISFImageProperties ) -> AutoStretchColorSource?
    {
        if let cfaPattern = properties.colorFilterArrayPattern,
           let pattern    = try? ColorFilterArray.pattern( named: cfaPattern ),
           let mosaic     = planes.first,
           let buffer     = try? PixelBuffer( width: properties.width, height: properties.height, channels: 1, pixels: mosaic, isNormalized: false )
        {
            return .mosaic( buffer, pattern: pattern )
        }

        if properties.colorSpace == .rgb, properties.channelCount == 3, planes.count == 3,
           let interleaved = try? PixelUtilities.interleave( planes: planes ),
           let buffer      = try? PixelBuffer( width: properties.width, height: properties.height, channels: 3, pixels: interleaved, isNormalized: false )
        {
            return .channels( buffer )
        }

        return nil
    }
}
