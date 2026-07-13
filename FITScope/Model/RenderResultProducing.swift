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

/// A value that can render itself into an ``ImageProcessor/RenderResult`` from
/// user settings — the capability shared by a raw ``ImageRenderSource``, which
/// decodes its bytes on every call, and a ``DecodedRenderSource``, which has
/// already decoded its pixels and renders them without touching bytes again.
///
/// ``ImageRenderer`` renders through this protocol so it can drive either a
/// source or a pre-decoded frame with the same code path — decoding a frame once
/// and rendering both the displayed result and the before/after original from
/// that single decode.
///
/// A `Sendable` value so it can cross the render concurrency boundary.
public protocol RenderResultProducing: Sendable
{
    /// Renders the receiver with the given user settings, producing the display
    /// image plus the bytes and pixel formats the histogram stages consume. Pure,
    /// so it runs off the main actor.
    ///
    /// - Parameter settings: The user-tunable render settings to apply.
    /// - Returns: The render result.
    /// - Throws: Any error thrown while decoding or running the pipeline.
    func makeResult( settings: ImageProcessor.Settings ) throws -> ImageProcessor.RenderResult
}
