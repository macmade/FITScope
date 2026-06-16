/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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

import CoreGraphics

/// Pure geometry for the zoomable canvas: the magnification that fits content
/// into a viewport, and the document-space origin that centres it.
public enum CanvasGeometry
{
    /// The magnification at which `content` fits entirely within `visible`,
    /// i.e. the smaller of the width and height ratios. Returns `0` for any
    /// non-positive dimension.
    public static func fitFactor( content: CGSize, visible: CGSize ) -> CGFloat
    {
        guard content.width > 0, content.height > 0, visible.width > 0, visible.height > 0
        else
        {
            return 0
        }

        return min( visible.width / content.width, visible.height / content.height )
    }

    /// The document-space origin of the visible rectangle that centres
    /// `content` within a viewport whose size, expressed in document space, is
    /// `visibleInDocumentSpace` (i.e. the clip bounds divided by magnification).
    public static func centeredOrigin( content: CGSize, visibleInDocumentSpace: CGSize ) -> CGPoint
    {
        CGPoint(
            x: ( content.width  - visibleInDocumentSpace.width  ) / 2,
            y: ( content.height - visibleInDocumentSpace.height ) / 2
        )
    }

    /// `value` clamped to `min...max`.
    public static func clamp( _ value: CGFloat, min lower: CGFloat, max upper: CGFloat ) -> CGFloat
    {
        Swift.max( lower, Swift.min( upper, value ) )
    }
}
