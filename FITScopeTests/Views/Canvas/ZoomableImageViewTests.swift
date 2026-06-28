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

import AppKit
@testable import FITScope
import SwiftPixel
import Testing

/// Tests for ``HoverImageNSView``: the image must render with row 0 at the top,
/// matching the coordinate system the star overlay and the cursor pixel readout
/// both assume. The view is `isFlipped`, so drawing the `CGImage` must account
/// for that or the image renders upside-down.
@MainActor
@Suite( "ZoomableImageView" )
struct ZoomableImageViewTests
{
    /// An RGB `CGImage` whose top half is white and bottom half is black, so the
    /// rendered orientation is unambiguous.
    private static func topWhiteBottomBlackImage( width: Int = 8, height: Int = 8 ) throws -> CGImage
    {
        let bytes = ( 0 ..< ( width * height ) ).flatMap
        {
            index -> [ UInt8 ] in

            let y     = index / width
            let value: UInt8 = y < ( height / 2 ) ? 255 : 0

            return [ value, value, value ]
        }

        return try PixelBuffer.createCGImage( bytes: bytes, width: width, height: height, channels: 3 )
    }

    /// Renders the view through an offscreen window — the reliable path for
    /// capturing AppKit drawing, including the view's flippedness — and returns
    /// its rendered bitmap, whose `(0, 0)` is the top-left of the displayed image.
    private static func render( _ view: NSView ) throws -> NSBitmapImageRep
    {
        let window = NSWindow( contentRect: view.bounds, styleMask: [ .borderless ], backing: .buffered, defer: false )

        window.contentView?.addSubview( view )
        view.displayIfNeeded()

        let rep = try #require( view.bitmapImageRepForCachingDisplay( in: view.bounds ) )

        view.cacheDisplay( in: view.bounds, to: rep )

        return rep
    }

    @Test
    func drawsImageWithRowZeroAtTop() throws
    {
        let image = try Self.topWhiteBottomBlackImage()
        let view  = HoverImageNSView( cgImage: image )
        let rep   = try Self.render( view )

        // The rep is sized in backing pixels (≥ the view's points on a Retina
        // display), so sample by fraction of its actual height.
        let cx     = rep.pixelsWide / 2
        let top    = try #require( rep.colorAt( x: cx, y: rep.pixelsHigh / 4 ) )
        let bottom = try #require( rep.colorAt( x: cx, y: ( rep.pixelsHigh * 3 ) / 4 ) )

        // Row 0 (white) must appear at the top of the rendered view, not flipped
        // to the bottom — so the image lines up with the overlay and readout.
        #expect( top.redComponent    > 0.8 )
        #expect( bottom.redComponent < 0.2 )
    }
}
