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

@testable import FITScope
import Testing

/// Tests for ``CanvasOverlayStyle``: the single source of truth for the alpha the
/// canvas overlays share, so annotations read as layered over the image rather
/// than sitting heavily on top.
@Suite( "CanvasOverlayStyle" )
struct CanvasOverlayStyleTests
{
    @Test
    func primaryAlphaIsSemiTransparent() throws
    {
        // The shared alpha sits clearly below fully opaque so the image shows
        // through, while staying legible.
        #expect( CanvasOverlayStyle.alpha == 0.7 )
    }

    @Test
    func secondaryAlphaIsAFractionOfThePrimary() throws
    {
        // De-emphasised elements (e.g. the grid's lines beneath its labels) are a
        // fixed fraction of the primary alpha, so both track the single source of
        // truth together.
        #expect( CanvasOverlayStyle.secondaryAlpha == CanvasOverlayStyle.alpha * 0.4 )
    }

    @Test
    func secondaryAlphaIsFainterThanPrimary() throws
    {
        #expect( CanvasOverlayStyle.secondaryAlpha < CanvasOverlayStyle.alpha )
    }
}
