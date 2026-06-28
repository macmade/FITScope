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

import CoreGraphics
@testable import FITScope
import Testing

/// Tests for ``ReticleOverlay``: it is always offered (every image has a centre)
/// and its centre is the image's midpoint, which ``CanvasGeometry`` registers to
/// the displayed rectangle so it tracks zoom and pan.
@Suite( "ReticleOverlay" )
struct ReticleOverlayTests
{
    @Test
    func isAlwaysAvailable() throws
    {
        // Every image has a centre, so the reticle is always offered, like the
        // frame overlay.
        #expect( ReticleOverlay().isAvailable )
    }

    @Test
    func isNotLoading() throws
    {
        #expect( ReticleOverlay().isLoading == false )
    }

    @Test
    func hasAStableNonDisplayIdentifier() throws
    {
        #expect( ReticleOverlay().id == "reticle" )
    }

    @Test
    func centreIsTheImageMidpoint() throws
    {
        #expect( ReticleOverlay.imageCenter( imageSize: CGSize( width: 100, height: 80 ) ) == CGPoint( x: 50, y: 40 ) )
    }
}
