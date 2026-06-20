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

/// Tests for `CanvasGeometry`: fit factor is the limiting ratio; centered
/// origin places the content's centre at the viewport's centre.
@Suite( "CanvasGeometry" )
struct CanvasGeometryTests
{
    @Test
    func fitFactorIsLimitingRatio() throws
    {
        // 1000×500 content into a 200×200 viewport → width limits → 0.2.
        #expect( CanvasGeometry.fitFactor( content: CGSize( width: 1000, height: 500 ), visible: CGSize( width: 200, height: 200 ) ) == 0.2 )
    }

    @Test
    func fitFactorIsZeroForDegenerateInput() throws
    {
        #expect( CanvasGeometry.fitFactor( content: .zero, visible: CGSize( width: 200, height: 200 ) ) == 0 )
        #expect( CanvasGeometry.fitFactor( content: CGSize( width: 10, height: 10 ), visible: .zero ) == 0 )
    }

    @Test
    func centeredOriginCentersContent() throws
    {
        // Visible 100×100 (in document space) over 400×400 content → origin (150,150).
        let origin = CanvasGeometry.centeredOrigin( content: CGSize( width: 400, height: 400 ), visibleInDocumentSpace: CGSize( width: 100, height: 100 ) )

        #expect( origin == CGPoint( x: 150, y: 150 ) )
    }

    @Test
    func clampBoundsMagnification() throws
    {
        #expect( CanvasGeometry.clamp( 100, min: 0.05, max: 40 ) == 40 )
        #expect( CanvasGeometry.clamp( 0.001, min: 0.05, max: 40 ) == 0.05 )
        #expect( CanvasGeometry.clamp( 1.5, min: 0.05, max: 40 ) == 1.5 )
    }
}
