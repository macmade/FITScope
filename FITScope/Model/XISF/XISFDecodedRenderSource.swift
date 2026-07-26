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

/// The XISF ``DecodedRenderSource``: an image decoded once into its channel
/// planes, rendered repeatedly without re-decoding the bytes.
///
/// Built by ``XISFRenderSource/decoded()`` from
/// ``XISFImageDecoder/planeSamples(bytes:properties:)``. Every XISF layout decodes
/// to planes, so there is no byte fallback. A `Sendable` value dropped at the end
/// of the render pass.
public struct XISFDecodedRenderSource: DecodedRenderSource
{
    /// The image's already-decoded raw channel planes.
    public let planes: [ [ Double ] ]

    /// The image's pixel layout.
    public let properties: XISFImageProperties

    /// Creates a decoded XISF render source.
    ///
    /// - Parameters:
    ///   - planes:     The already-decoded raw channel planes.
    ///   - properties: The image's pixel layout.
    public init( planes: [ [ Double ] ], properties: XISFImageProperties )
    {
        self.planes     = planes
        self.properties = properties
    }

    /// Renders the already-decoded planes, driving the decode-free
    /// ``ImageProcessor/render(planes:xisf:settings:)`` — the same core the
    /// byte-based ``XISFRenderSource/makeResult(settings:)`` reaches after decoding,
    /// so the result is identical without decoding twice.
    public func makeResult( settings: ImageProcessor.Settings ) throws -> ImageProcessor.RenderResult
    {
        try ImageProcessor.render( planes: self.planes, xisf: self.properties, settings: settings )
    }

    /// The auto Screen Transfer colour input built from the already-decoded planes: a
    /// colour-filter-array mosaic or RGB channels, else the single-channel luminance
    /// (the mean of the channels) for a uniform stretch — subsampled for a downsampled
    /// preview. Reproduces the byte-based XISF preview colour source for the same frame.
    public func autoStretchColorSource( maxDimension: Int? ) -> ImageProcessor.AutoStretchColorSource?
    {
        if let colour = ImageProcessor.xisfAutoStretchColorSource( fromPlanes: self.planes, properties: self.properties )
        {
            return colour.subsampled( maxDimension: maxDimension )
        }

        guard let luminance = XISFImageDecoder.linearLuminance( fromPlanes: self.planes, properties: self.properties ),
              let buffer    = try? PixelBuffer( width: luminance.width, height: luminance.height, channels: 1, pixels: luminance.samples, isNormalized: false )
        else
        {
            return nil
        }

        return ImageProcessor.AutoStretchColorSource.mono( buffer ).subsampled( maxDimension: maxDimension )
    }
}
