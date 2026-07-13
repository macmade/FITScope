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

/// A render source whose pixels have already been decoded once, so it can render
/// them repeatedly — and derive its auto-stretch input — without decoding the
/// bytes again.
///
/// Built for the span of a single ``ImageRenderer/render()`` pass, or one preview
/// render, and dropped when it returns: the displayed result and the unstretched
/// before/after original are rendered from the one decode, and the preview path
/// shares that decode between its auto-stretch statistics and its render. It must
/// never be retained across renders — holding the decoded pixels would reintroduce
/// the memory the re-decode-on-demand design deliberately avoids.
///
/// A `Sendable` value so it can cross the render concurrency boundary.
public protocol DecodedRenderSource: RenderResultProducing
{
    /// The colour input an auto Screen Transfer derives from, built from the
    /// already-decoded pixels rather than re-decoding the bytes — a colour source's
    /// per-channel input (a raw mosaic or co-located channels) or a mono source's
    /// single luminance channel, or `nil` when the source exposes no derivation
    /// input.
    ///
    /// - Parameter maxDimension: The largest dimension to derive the statistics
    ///   over, subsampling the colour source when set (matching a downsampled
    ///   preview), or `nil` for the full resolution.
    /// - Returns: The per-channel or mono colour input, or `nil`.
    func autoStretchColorSource( maxDimension: Int? ) -> ImageProcessor.AutoStretchColorSource?
}
