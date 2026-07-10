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

/// A `Sendable` snapshot of a camera RAW image's pixel layout — the geometry of
/// the cropped visible mosaic and how to interpret its samples.
///
/// SwiftRAW's `RAWFile` is a non-`Sendable` reference type that owns a LibRAW
/// instance, so it cannot cross the render concurrency boundary. The loader
/// crops the sensor's 16-bit single-channel Bayer buffer to the visible area and
/// captures this value type, which is all the renderer needs to decode the
/// pixels — the RAW analogue of ``XISFImageProperties`` / ``ImageIOImageProperties``.
///
/// The samples are the cropped mosaic in host byte order (the bytes are produced
/// and consumed in-process), one 16-bit sample per pixel (``width`` × ``height``
/// samples). They are the raw sensor values — linear, undemosaiced, with no white
/// balance or tone curve applied — so they flow through the pipeline exactly like
/// a colour-filter-array FITS sub.
public struct RAWImageProperties: Sendable, Equatable
{
    /// The visible image width in pixels (the cropped mosaic, margins removed).
    public let width: Int

    /// The visible image height in pixels (the cropped mosaic, margins removed).
    public let height: Int

    /// The colour-filter-array pattern of the *cropped* mosaic (e.g. `"RGGB"`),
    /// derived at the crop origin so its Bayer phase is correct after the margins
    /// are removed, or `nil` for a monochrome (non-CFA) sensor.
    public let colorFilterArrayPattern: String?

    /// The sensor's saturation (white) level, used to express a read-out value as a
    /// `0...1` fraction, or `nil` when it is unknown (no fixed full scale).
    public let whiteLevel: Double?

    /// Creates a snapshot from its parts.
    ///
    /// - Parameters:
    ///   - width:                   The visible image width in pixels.
    ///   - height:                  The visible image height in pixels.
    ///   - colorFilterArrayPattern: The cropped mosaic's CFA pattern, or `nil` for
    ///                              a monochrome sensor.
    ///   - whiteLevel:              The saturation level for the read-out fraction,
    ///                              or `nil` when unknown.
    public init( width: Int, height: Int, colorFilterArrayPattern: String?, whiteLevel: Double? )
    {
        self.width                   = width
        self.height                  = height
        self.colorFilterArrayPattern = colorFilterArrayPattern
        self.whiteLevel              = whiteLevel
    }
}
