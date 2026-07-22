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

/// The XISF conformer of ``ImageRenderSource``: a decoded XISF image's raw pixel
/// bytes and its layout, rendered through the XISF-aware ``ImageProcessor`` entry.
///
/// A `Sendable` value type so it can cross the render concurrency boundary without
/// sharing the non-`Sendable` `XISFImage`. Mirrors ``FITSRenderSource``.
public struct XISFRenderSource: ImageRenderSource
{
    /// The image's raw (decompressed, un-shuffled) pixel bytes.
    public let data: Data

    /// The image's pixel layout, used to decode the bytes.
    public let properties: XISFImageProperties

    /// The detection-ready single-channel linear image (the mean of the channels),
    /// built once at load time. `nil` when no detection input is needed or it could
    /// not be decoded.
    public let detectionImage: PixelBuffer?

    /// The format's full-scale maximum, from the sample format — `nil` for a
    /// floating-point sample format, which has no fixed full scale.
    public var fullScale: Double?
    {
        ImageProcessor.xisfFullScale( self.properties.sampleFormat )
    }

    /// The per-channel colour input for the auto Screen Transfer: a colour-filter-array
    /// frame's raw mosaic or an RGB frame's interleaved planes, so a colour image
    /// derives an unlinked per-channel STF. A grayscale (or non-RGB) frame falls back
    /// to the single-channel ``detectionImage``, which derives a uniform STF exactly as
    /// before.
    public var autoStretchColorSource: ImageProcessor.AutoStretchColorSource?
    {
        ImageProcessor.xisfAutoStretchColorSource( data: self.data, properties: self.properties ) ?? self.detectionImage.map { .mono( $0 ) }
    }

    /// Creates a render source from a decoded image's bytes and layout.
    ///
    /// - Parameters:
    ///   - data:           The image's raw pixel bytes.
    ///   - properties:     The image's pixel layout.
    ///   - detectionImage: The detection-ready single-channel image, or `nil`.
    public init( data: Data, properties: XISFImageProperties, detectionImage: PixelBuffer? = nil )
    {
        self.data           = data
        self.properties     = properties
        self.detectionImage = detectionImage
    }

    /// Renders the XISF bytes and layout into a displayable result, driving the
    /// XISF-facing ``ImageProcessor/render(data:xisf:settings:)``.
    public func makeResult( settings: ImageProcessor.Settings ) throws -> ImageProcessor.RenderResult
    {
        try ImageProcessor.render( data: self.data, xisf: self.properties, settings: settings )
    }

    /// Decodes the image's channel planes once into an ``XISFDecodedRenderSource``,
    /// so the renderer can render the displayed result and the before/after original
    /// from the one decode. Every XISF layout decodes to planes, so this never
    /// returns `nil`; it throws only when the bytes cannot be decoded, and the caller
    /// then falls back to the byte path.
    public func decoded() throws -> ( any DecodedRenderSource )?
    {
        XISFDecodedRenderSource( planes: try ImageProcessor.xisfPlaneSamples( data: self.data, properties: self.properties ), properties: self.properties )
    }

    /// The decoded sample(s) at image coordinates `(x, y)`: three per-channel values
    /// for an RGB image, a single value otherwise, or `nil` when the coordinate or
    /// geometry is unavailable.
    public func pixelValues( atX x: Int, y: Int ) -> [ ImageProcessor.PixelValue ]?
    {
        ImageProcessor.xisfPixelValues( data: self.data, properties: self.properties, x: x, y: y )
    }

    /// The image's pixel dimensions.
    public var dimensions: ( width: Int, height: Int )?
    {
        ( self.properties.width, self.properties.height )
    }
}
