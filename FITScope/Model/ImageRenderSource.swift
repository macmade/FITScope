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

/// The renderable source of an image, decoupling ``ImageRenderer`` from any file
/// format: the renderer drives the pixel pipeline, computes histograms and manages
/// re-rendering through this protocol without knowing whether the pixels came from
/// FITS, XISF, or a photographic format.
///
/// A `Sendable` value so it can cross the render concurrency boundary without
/// sharing a format's non-`Sendable` parsed file.
public protocol ImageRenderSource: Sendable
{
    /// Renders the source with the given user settings, producing the display
    /// image plus the bytes and pixel formats the histogram stages consume. Pure,
    /// so it runs off the main actor.
    ///
    /// - Parameter settings: The user-tunable render settings to apply.
    /// - Returns: The render result.
    /// - Throws: Any error thrown while decoding or running the pipeline.
    func makeResult( settings: ImageProcessor.Settings ) throws -> ImageProcessor.RenderResult

    /// The decoded sample value at source-image coordinates `(x, y)`, for the
    /// cursor read-out, or `nil` for out-of-bounds coordinates or a source that
    /// exposes no per-pixel values.
    ///
    /// - Parameters:
    ///   - x: The zero-based column, left to right.
    ///   - y: The zero-based row, top to bottom.
    /// - Returns: The decoded value, or `nil`.
    func pixelValue( atX x: Int, y: Int ) -> ImageProcessor.PixelValue?

    /// The source image's pixel dimensions, or `nil` when they cannot be
    /// determined. Used to map a display coordinate back to source space under a
    /// non-identity orientation.
    var dimensions: ( width: Int, height: Int )? { get }

    /// The detection-ready single-channel linear image for star detection and the
    /// sky-background measurement, or `nil` when none is available.
    var detectionImage: PixelBuffer? { get }
}
