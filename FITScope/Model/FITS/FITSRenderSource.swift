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

    /// The decoded sample at image coordinates `(x, y)`, or `nil` when the
    /// coordinate or geometry is unavailable.
    public func pixelValue( atX x: Int, y: Int ) -> ImageProcessor.PixelValue?
    {
        ImageProcessor.rawPixelValue( data: self.data, properties: self.properties, x: x, y: y )
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
