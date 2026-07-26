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

/// The camera-RAW ``DecodedRenderSource``: a sensor mosaic decoded once into its
/// single plane, rendered repeatedly without re-decoding the bytes.
///
/// Built by ``RAWRenderSource/decoded()`` from
/// ``RAWImageDecoder/planeSamples(bytes:properties:)``. A RAW frame is always a
/// single-sensor mosaic, so this never falls back to a byte path. A `Sendable`
/// value dropped at the end of the render pass.
public struct RAWDecodedRenderSource: DecodedRenderSource
{
    /// The already-decoded raw mosaic samples, in row-major order.
    public let plane: [ Double ]

    /// The image's pixel layout.
    public let properties: RAWImageProperties

    /// Creates a decoded RAW render source.
    ///
    /// - Parameters:
    ///   - plane:      The already-decoded raw mosaic samples.
    ///   - properties: The image's pixel layout.
    public init( plane: [ Double ], properties: RAWImageProperties )
    {
        self.plane      = plane
        self.properties = properties
    }

    /// Renders the already-decoded mosaic, driving the decode-free
    /// ``ImageProcessor/render(plane:raw:settings:)`` — the same core the byte-based
    /// ``RAWRenderSource/makeResult(settings:)`` reaches after decoding, so the result
    /// is identical without decoding twice.
    public func makeResult( settings: ImageProcessor.Settings ) throws -> ImageProcessor.RenderResult
    {
        try ImageProcessor.render( plane: self.plane, raw: self.properties, settings: settings )
    }

    /// The auto Screen Transfer colour input from the already-decoded mosaic: a
    /// colour-filter-array sensor's per-channel mosaic, else the mono mosaic itself as
    /// a uniform luminance — subsampled for a downsampled preview. Matches the
    /// byte-based ``RAWRenderSource/autoStretchColorSource`` for the same frame (whose
    /// mono fallback is the detection image, itself the mosaic for a mono sensor).
    public func autoStretchColorSource( maxDimension: Int? ) -> ImageProcessor.AutoStretchColorSource?
    {
        if let colour = ImageProcessor.rawAutoStretchColorSource( fromPlane: self.plane, properties: self.properties )
        {
            return colour.subsampled( maxDimension: maxDimension )
        }

        guard let buffer = try? PixelBuffer( width: self.properties.width, height: self.properties.height, channels: 1, pixels: self.plane, isNormalized: false )
        else
        {
            return nil
        }

        return ImageProcessor.AutoStretchColorSource.mono( buffer ).subsampled( maxDimension: maxDimension )
    }
}
