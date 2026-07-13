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

public extension ImageProcessor.AutoStretchColorSource
{
    /// A spatially decimated copy of the colour source, small enough that its
    /// larger side fits within `maxDimension`, used to derive a preview's auto
    /// Screen Transfer at a fraction of the cost.
    ///
    /// The auto-stretch derivation sorts every sample twice (for the median and
    /// the median absolute deviation), so on a full-resolution frame it dominates
    /// a thumbnail's cost. The statistics only need a representative subset, so the
    /// underlying buffer is decimated — not averaged — via ``SwiftPixel/Processors/Resample``
    /// in its ``SwiftPixel/Processors/Resample/Mode/nearest(blockSize:)`` mode, to
    /// preserve the value distribution the median and MAD read. A raw colour-filter-
    /// array ``mosaic`` is decimated in whole 2×2 cells so it stays phase-aligned and
    /// still splits per channel correctly; a co-located ``mono``/``channels`` source
    /// is decimated per sample. When `maxDimension` is `nil` or the source already
    /// fits, the source is returned unchanged.
    ///
    /// - Parameter maxDimension: The largest dimension the decimated source may
    ///                           take, or `nil` to leave it untouched.
    /// - Returns: The decimated colour source, or the original when no reduction
    ///   applies.
    func subsampled( maxDimension: Int? ) -> ImageProcessor.AutoStretchColorSource
    {
        guard let maxDimension
        else
        {
            return self
        }

        switch self
        {
            case .mono( let buffer ):

                return ( try? Self.decimated( buffer, maxDimension: maxDimension, blockSize: 1 ) ).map { .mono( $0 ) } ?? self

            case .channels( let buffer ):

                return ( try? Self.decimated( buffer, maxDimension: maxDimension, blockSize: 1 ) ).map { .channels( $0 ) } ?? self

            case .mosaic( let buffer, let pattern ):

                return ( try? Self.decimated( buffer, maxDimension: maxDimension, blockSize: 2 ) ).map { .mosaic( $0, pattern: pattern ) } ?? self
        }
    }

    /// Decimates a buffer by applying ``SwiftPixel/Processors/Resample`` in its
    /// nearest mode — the same way the app applies a standalone ``SwiftPixel/Processors/Normalize``.
    ///
    /// - Parameters:
    ///   - buffer:       The buffer to decimate.
    ///   - maxDimension: The largest dimension the result may take.
    ///   - blockSize:    The cell kept intact (`1` per sample, `2` for a mosaic).
    /// - Returns: The decimated buffer.
    /// - Throws: A `PixelBufferError` if the decimated geometry is inconsistent.
    private static func decimated( _ buffer: PixelBuffer, maxDimension: Int, blockSize: Int ) throws -> PixelBuffer
    {
        var result = buffer

        try Processors.Resample( maxDimension: maxDimension, mode: .nearest( blockSize: blockSize ) ).process( buffer: &result )

        return result
    }
}
