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

/// The FITS conformer of ``ImageRenderSource``: an image HDU's raw bytes and
/// header properties, rendered through the FITS-aware ``ImageProcessor`` entries.
///
/// A `Sendable` value type so it can cross the render concurrency boundary without
/// sharing the non-`Sendable` `FITSFile`.
public struct FITSRenderSource: ImageRenderSource
{
    /// The image HDU's raw pixel bytes.
    public let data: Data

    /// The owning header's property snapshots, used to interpret the bytes.
    public let properties: [ FITSPropertySnapshot ]

    /// The detection-ready single-channel linear image — demosaiced to a luminance
    /// channel for one-shot-colour frames — built once at load time via
    /// `SwiftAstro.FITSImageDecoder`. `nil` when no detection input is needed (e.g.
    /// the QuickLook extensions) or it could not be decoded.
    public let detectionImage: PixelBuffer?

    /// The format's full-scale maximum, from the header's `BITPIX` /
    /// `BSCALE` / `BZERO` — `nil` for a floating-point `BITPIX`, which has no fixed
    /// full scale.
    public var fullScale: Double?
    {
        ImageProcessor.fullScale( forImageHDU: self.properties )
    }

    /// The per-channel colour input for the auto Screen Transfer: an RGB
    /// `NAXIS=3` frame's interleaved planes or a colour-filter-array frame's raw
    /// mosaic, so a colour image derives an unlinked per-channel STF. A monochrome
    /// frame falls back to the single-channel ``detectionImage``, which derives a
    /// uniform STF exactly as before.
    public var autoStretchColorSource: ImageProcessor.AutoStretchColorSource?
    {
        ImageProcessor.autoStretchColorSource( forImageHDU: self.data, properties: self.properties ) ?? self.detectionImage.map { .mono( $0 ) }
    }

    /// Creates a render source from an image HDU's bytes and header properties.
    ///
    /// - Parameters:
    ///   - data:           The image HDU's raw pixel bytes.
    ///   - properties:     The owning header's property snapshots.
    ///   - detectionImage: The detection-ready single-channel image, or `nil`.
    public init( data: Data, properties: [ FITSPropertySnapshot ], detectionImage: PixelBuffer? = nil )
    {
        self.data           = data
        self.properties     = properties
        self.detectionImage = detectionImage
    }

    /// Selects the first renderable image HDU from a file's sections and snapshots
    /// it into a Sendable render source.
    ///
    /// The HDU-selection rule lives in ``FITSPreviewRenderer/imageHDU(from:)`` so
    /// the app's render path and the QuickLook extensions pick the same image HDU.
    ///
    /// - Parameters:
    ///   - sections:       The file's sections, in file order.
    ///   - detectionImage: The detection-ready single-channel image to carry
    ///                     alongside the render bytes, or `nil` when star detection
    ///                     is not needed for this source.
    /// - Throws: ``RuntimeError`` when the file contains no image data section.
    public init( sections: [ FITSSection ], detectionImage: PixelBuffer? = nil ) throws
    {
        let hdu = try FITSPreviewRenderer.imageHDU( from: sections )

        self.init( data: hdu.data, properties: hdu.properties, detectionImage: detectionImage )
    }

    /// Renders the FITS bytes and header into a displayable result, driving the
    /// FITS-facing ``ImageProcessor/render(data:properties:settings:)``.
    public func makeResult( settings: ImageProcessor.Settings ) throws -> ImageProcessor.RenderResult
    {
        try ImageProcessor.render( data: self.data, properties: self.properties, settings: settings )
    }

    /// Decodes the image HDU's raw samples once into a ``FITSDecodedRenderSource``,
    /// so the renderer can render the displayed result and the before/after original
    /// from the one decode. Returns `nil` for an RGB colour-plane frame or a data
    /// cube — anything ``ImageProcessor/decodedImageHDU(data:properties:)`` cannot
    /// decode as a 2-D image — so the caller falls back to the byte path.
    public func decoded() throws -> ( any DecodedRenderSource )?
    {
        ImageProcessor.decodedImageHDU( data: self.data, properties: self.properties ).map
        {
            FITSDecodedRenderSource( samples: $0.samples, width: $0.width, height: $0.height, bitsPerPixel: $0.bitsPerPixel, properties: self.properties )
        }
    }

    /// The decoded sample(s) at image coordinates `(x, y)`: three per-channel values
    /// for an RGB colour-planes image, a single value otherwise, or `nil` when the
    /// coordinate or geometry is unavailable.
    public func pixelValues( atX x: Int, y: Int ) -> [ ImageProcessor.PixelValue ]?
    {
        if let rgb = ImageProcessor.rgbPixelValues( data: self.data, properties: self.properties, x: x, y: y )
        {
            return rgb
        }

        return ImageProcessor.rawPixelValue( data: self.data, properties: self.properties, x: x, y: y ).map { [ $0 ] }
    }

    /// The image's pixel dimensions read from the header, or `nil` when they
    /// cannot be determined.
    public var dimensions: ( width: Int, height: Int )?
    {
        ImageProcessor.imageDimensions( from: self.properties )
    }
}

/// FITS convenience for building an ``ImageRenderer`` from a parsed FITS file.
public extension ImageRenderer
{
    /// Creates a renderer from a parsed FITS file, extracting the first renderable
    /// image HDU. Any extraction failure is captured and surfaces at render time.
    ///
    /// - Parameter file: The parsed FITS file.
    convenience init( file: FITSFile )
    {
        self.init( source: Swift.Result { try FITSRenderSource( sections: file.sections ) } )
    }
}
