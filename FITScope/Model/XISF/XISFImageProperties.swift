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
import SwiftXISF

/// A `Sendable` snapshot of an XISF image's pixel layout — the geometry and
/// sample descriptors needed to decode its bytes.
///
/// `XISFImage` is a reference type and not `Sendable`, so it cannot cross the
/// render concurrency boundary. This value type captures the geometry and the
/// (already `Sendable`) sample-format descriptors, which is all the renderer
/// needs to decode the pixels — the XISF analogue of ``FITSPropertySnapshot``.
public struct XISFImageProperties: Sendable, Equatable
{
    /// The image width in pixels (the first, fastest-varying spatial dimension).
    public let width: Int

    /// The image height in pixels (the second spatial dimension, `1` for a purely
    /// one-dimensional geometry).
    public let height: Int

    /// The number of channels (`1` for grayscale or a colour-filter array, `3`
    /// for RGB).
    public let channelCount: Int

    /// The stored sample format (integer or floating-point width).
    public let sampleFormat: XISFSampleFormat

    /// The byte order the samples are stored in.
    public let byteOrder: XISFByteOrder

    /// Whether the channels are stored channel-contiguous (planar) or
    /// pixel-interleaved (normal).
    public let pixelStorage: XISFPixelStorage

    /// The colour space, which selects the channel-forming step (grayscale is
    /// expanded, RGB passes through).
    public let colorSpace: XISFColorSpace

    /// The colour-filter-array pattern (e.g. `"RGGB"`) when the image is a raw
    /// mosaic to be debayered, or `nil` for a non-CFA image.
    public let colorFilterArrayPattern: String?

    /// Creates a snapshot from its parts.
    ///
    /// - Parameters:
    ///   - width:                   The image width in pixels.
    ///   - height:                  The image height in pixels.
    ///   - channelCount:            The number of channels.
    ///   - sampleFormat:            The stored sample format.
    ///   - byteOrder:               The byte order of the samples.
    ///   - pixelStorage:            The planar/interleaved storage model.
    ///   - colorSpace:              The colour space.
    ///   - colorFilterArrayPattern: The CFA pattern, or `nil`.
    public init( width: Int, height: Int, channelCount: Int, sampleFormat: XISFSampleFormat, byteOrder: XISFByteOrder, pixelStorage: XISFPixelStorage, colorSpace: XISFColorSpace, colorFilterArrayPattern: String? )
    {
        self.width                   = width
        self.height                  = height
        self.channelCount            = channelCount
        self.sampleFormat            = sampleFormat
        self.byteOrder               = byteOrder
        self.pixelStorage            = pixelStorage
        self.colorSpace              = colorSpace
        self.colorFilterArrayPattern = colorFilterArrayPattern
    }

    /// Snapshots a parsed ``XISFImage``'s layout, so the non-`Sendable` image need
    /// not cross the render concurrency boundary.
    ///
    /// The spatial dimensions are read most-significant first (`width`, then
    /// `height`); a purely one-dimensional geometry reports a `height` of `1`.
    ///
    /// - Parameter image: The parsed XISF image.
    public init( image: XISFImage )
    {
        let dimensions = image.geometry.dimensions

        self.init(
            width:                   dimensions.first ?? 0,
            height:                  dimensions.count > 1 ? dimensions[ 1 ] : 1,
            channelCount:            image.geometry.channelCount,
            sampleFormat:            image.sampleFormat,
            byteOrder:               image.byteOrder,
            pixelStorage:            image.pixelStorage,
            colorSpace:              image.colorSpace,
            colorFilterArrayPattern: image.colorFilterArray?.pattern
        )
    }
}
