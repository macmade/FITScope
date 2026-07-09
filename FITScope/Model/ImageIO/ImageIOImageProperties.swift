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

/// A `Sendable` snapshot of a photographic image's decoded pixel layout — the
/// geometry and sample descriptors needed to read the bytes the loader produced
/// by drawing the `CGImage` into a canonical bitmap.
///
/// `CGImage` is not `Sendable` and cannot cross the render concurrency boundary,
/// so the loader draws it into a fixed layout off the main actor and captures that
/// layout here — the ImageIO analogue of ``XISFImageProperties`` /
/// ``FITSPropertySnapshot``.
///
/// The samples are stored **interleaved**, top row first, one row after another
/// with no padding. A grayscale image stores one component per pixel; a colour
/// image is drawn as `RGBX` (four components per pixel, the fourth an unused
/// padding/alpha byte CoreGraphics requires for an RGB bitmap), of which the first
/// three are the meaningful channels.
public struct ImageIOImageProperties: Sendable, Equatable
{
    /// The image width in pixels.
    public let width: Int

    /// The image height in pixels.
    public let height: Int

    /// The number of meaningful channels: `1` for grayscale, `3` for colour.
    public let channelCount: Int

    /// The number of components stored per pixel in the bytes: `1` for grayscale,
    /// `4` for the `RGBX` colour layout (the fourth component is unused padding and
    /// is skipped when decoding).
    public let componentsPerPixel: Int

    /// The number of bytes per component: `1` for an 8-bit image, `2` for a
    /// 16-bit image.
    public let bytesPerComponent: Int

    /// Creates a layout snapshot from its parts.
    ///
    /// - Parameters:
    ///   - width:              The image width in pixels.
    ///   - height:             The image height in pixels.
    ///   - channelCount:       The number of meaningful channels (`1` or `3`).
    ///   - componentsPerPixel: The number of stored components per pixel (`1` or `4`).
    ///   - bytesPerComponent:  The number of bytes per component (`1` or `2`).
    public init( width: Int, height: Int, channelCount: Int, componentsPerPixel: Int, bytesPerComponent: Int )
    {
        self.width              = width
        self.height             = height
        self.channelCount       = channelCount
        self.componentsPerPixel = componentsPerPixel
        self.bytesPerComponent  = bytesPerComponent
    }

    /// The full-scale value of the integer sample format — `255` for 8-bit, `65535`
    /// for 16-bit — used to scale the samples into the `[0, 1]` display range and to
    /// express a read-out value as a `0...1` fraction.
    public var fullScale: Double
    {
        self.bytesPerComponent >= 2 ? Double( UInt16.max ) : Double( UInt8.max )
    }

    /// Whether the image is colour (three channels), so the inspector offers the
    /// colour-grading controls.
    public var isColor: Bool
    {
        self.channelCount == 3
    }
}
