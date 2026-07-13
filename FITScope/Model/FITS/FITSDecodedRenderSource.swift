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

/// The FITS ``DecodedRenderSource``: a 2-D image HDU decoded once into its raw
/// samples, rendered repeatedly without re-decoding the bytes.
///
/// Built by ``FITSRenderSource/decoded()`` from
/// ``ImageProcessor/decodedImageHDU(data:properties:)`` — which returns `nil` for
/// an RGB colour-plane frame or a data cube, so those keep the byte path. A
/// `Sendable` value holding only the decoded `[Double]` samples and the header
/// snapshots, dropped at the end of the render pass.
public struct FITSDecodedRenderSource: DecodedRenderSource
{
    /// The image HDU's raw, unscaled samples, in row-major order.
    public let samples: [ Double ]

    /// The image width in pixels.
    public let width: Int

    /// The image height in pixels.
    public let height: Int

    /// The sample format the samples were decoded from.
    public let bitsPerPixel: BitsPerPixel

    /// The owning header's property snapshots (scaling, `BAYERPAT`).
    public let properties: [ FITSPropertySnapshot ]

    /// Creates a decoded FITS render source.
    ///
    /// - Parameters:
    ///   - samples:      The raw, unscaled samples in row-major order.
    ///   - width:        The image width in pixels.
    ///   - height:       The image height in pixels.
    ///   - bitsPerPixel: The sample format the samples were decoded from.
    ///   - properties:   The owning header's property snapshots.
    public init( samples: [ Double ], width: Int, height: Int, bitsPerPixel: BitsPerPixel, properties: [ FITSPropertySnapshot ] )
    {
        self.samples      = samples
        self.width        = width
        self.height       = height
        self.bitsPerPixel = bitsPerPixel
        self.properties   = properties
    }

    /// Renders the already-decoded samples, driving the decode-free
    /// ``ImageProcessor/render(rawSamples:width:height:bitsPerPixel:properties:settings:)``
    /// — the same core the byte-based ``FITSRenderSource/makeResult(settings:)``
    /// reaches after decoding, so the result is identical without decoding twice.
    public func makeResult( settings: ImageProcessor.Settings ) throws -> ImageProcessor.RenderResult
    {
        try ImageProcessor.render( rawSamples: self.samples, width: self.width, height: self.height, bitsPerPixel: self.bitsPerPixel, properties: self.properties, settings: settings )
    }

    /// The auto Screen Transfer colour input built from the already-decoded samples
    /// — a colour-filter-array ``ImageProcessor/AutoStretchColorSource/mosaic(_:pattern:)``
    /// or a ``ImageProcessor/AutoStretchColorSource/mono(_:)`` luminance — subsampled
    /// for a downsampled preview. Matches the byte-based FITS preview colour source
    /// for the same frame.
    public func autoStretchColorSource( maxDimension: Int? ) -> ImageProcessor.AutoStretchColorSource?
    {
        ImageProcessor.autoStretchColorSource( fromSamples: self.samples, width: self.width, height: self.height, properties: self.properties )?.subsampled( maxDimension: maxDimension )
    }
}
