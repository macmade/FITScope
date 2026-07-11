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

/// The camera-RAW conformer of ``ImageRenderSource``: a decoded RAW file's cropped
/// 16-bit mosaic bytes and its layout, rendered through the RAW-aware
/// ``ImageProcessor`` entry.
///
/// A `Sendable` value type so it can cross the render concurrency boundary without
/// sharing the non-`Sendable` `RAWFile`. Mirrors ``XISFRenderSource`` /
/// ``ImageIORenderSource`` / ``FITSRenderSource``.
public struct RAWRenderSource: ImageRenderSource
{
    /// The cropped visible mosaic's raw bytes: one 16-bit sample per pixel, in
    /// row-major order and host byte order (the bytes are produced and consumed
    /// in-process).
    public let data: Data

    /// The image's pixel layout, used to decode the bytes.
    public let properties: RAWImageProperties

    /// The detection-ready single-channel linear image (a demosaiced luminance for a
    /// CFA sensor, the mosaic itself for a monochrome one), built once at load time.
    /// `nil` when it could not be built.
    public let detectionImage: PixelBuffer?

    /// The sensor's saturation (white) level, the full scale the render brings the
    /// raw samples into `[0, 1]` against — `nil` when the decoder reported none.
    public var fullScale: Double?
    {
        self.properties.whiteLevel
    }

    /// The per-channel colour input for the auto Screen Transfer: a colour-filter-array
    /// sensor's raw mosaic, so a one-shot-colour RAW derives an unlinked per-channel
    /// STF. A monochrome sensor falls back to the single-channel ``detectionImage``,
    /// which derives a uniform STF exactly as before.
    public var autoStretchColorSource: ImageProcessor.AutoStretchColorSource?
    {
        ImageProcessor.rawAutoStretchColorSource( data: self.data, properties: self.properties ) ?? self.detectionImage.map { .mono( $0 ) }
    }

    /// Creates a render source from a decoded file's cropped mosaic bytes and layout.
    ///
    /// - Parameters:
    ///   - data:           The cropped mosaic's raw bytes.
    ///   - properties:     The image's pixel layout.
    ///   - detectionImage: The detection-ready single-channel image, or `nil`.
    public init( data: Data, properties: RAWImageProperties, detectionImage: PixelBuffer? = nil )
    {
        self.data           = data
        self.properties     = properties
        self.detectionImage = detectionImage
    }

    /// Renders the mosaic bytes and layout into a displayable result, driving the
    /// RAW-facing ``ImageProcessor/render(data:raw:settings:)``.
    public func makeResult( settings: ImageProcessor.Settings ) throws -> ImageProcessor.RenderResult
    {
        try ImageProcessor.render( data: self.data, raw: self.properties, settings: settings )
    }

    /// The decoded sample at image coordinates `(x, y)` as a single-element array (a
    /// RAW mosaic is single-channel), or `nil` when the coordinate or geometry is
    /// unavailable.
    public func pixelValues( atX x: Int, y: Int ) -> [ ImageProcessor.PixelValue ]?
    {
        ImageProcessor.rawImagePixelValues( data: self.data, properties: self.properties, x: x, y: y )
    }

    /// The image's pixel dimensions.
    public var dimensions: ( width: Int, height: Int )?
    {
        ( self.properties.width, self.properties.height )
    }
}
