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

    /// A 2×2 RGB image split left (white) / right (black), so an up-scaled draw
    /// has a single vertical edge whose sharpness reveals the interpolation used.
    private static func leftWhiteRightBlackImage() throws -> CGImage
    {
        let width  = 2
        let height = 2
        let bytes  = ( 0 ..< ( width * height ) ).flatMap
        {
            index -> [ UInt8 ] in

            let x     = index % width
            let value: UInt8 = x == 0 ? 255 : 0

            return [ value, value, value ]
        }

        return try PixelBuffer.createCGImage( bytes: bytes, width: width, height: height, channels: 3 )
    }

    /// Draws `body` into an off-screen `width`×`height` RGBA bitmap with that
    /// context made current, and returns the bitmap for pixel sampling. The
    /// CPU-backed context lets the interpolation setting be observed headlessly.
    private static func renderBitmap( width: Int, height: Int, _ body: () -> Void ) throws -> NSBitmapImageRep
    {
        let rep = try #require( NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide:       width,
            pixelsHigh:       height,
            bitsPerSample:    8,
            samplesPerPixel:  4,
            hasAlpha:         true,
            isPlanar:         false,
            colorSpaceName:   .deviceRGB,
            bytesPerRow:      0,
            bitsPerPixel:     0
        ) )

        let context = try #require( NSGraphicsContext( bitmapImageRep: rep ) )

        NSGraphicsContext.saveGraphicsState()

        defer { NSGraphicsContext.restoreGraphicsState() }

        NSGraphicsContext.current = context

        body()

        context.flushGraphics()

        return rep
    }

    /// Whether the middle row of `rep` contains a blended (grey) column — the
    /// signature of smooth interpolation across the image's white/black edge.
    /// Nearest-neighbor leaves every column pure, so this is `false`.
    private static func hasBlendedColumn( _ rep: NSBitmapImageRep ) -> Bool
    {
        let y = rep.pixelsHigh / 2

        return ( 0 ..< rep.pixelsWide ).contains
        {
            x in

            guard let colour = rep.colorAt( x: x, y: y )
            else
            {
                return false
            }

            return colour.redComponent > 0.2 && colour.redComponent < 0.8
        }
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

    @Test
    func drawsCrispPixelsWhenMagnifiedPastActualSize() throws
    {
        let image = try Self.leftWhiteRightBlackImage()
        let size  = 20
        let rep   = try Self.renderBitmap( width: size, height: size )
        {
            HoverImageNSView.drawImage( image, into: NSRect( x: 0, y: 0, width: size, height: size ), magnification: 2.0 )
        }

        // The 2×2 image is up-scaled into the fixed 20-pt rect; the magnification
        // argument (2.0, past 100%) is what makes `drawImage` pick nearest-neighbor
        // interpolation, so the white/black edge stays a hard step with no blended
        // (grey) transition column — real pixels for inspection.
        #expect( Self.hasBlendedColumn( rep ) == false )
    }

    @Test
    func drawsSmoothPixelsBelowActualSize() throws
    {
        let image = try Self.leftWhiteRightBlackImage()
        let size  = 20
        let rep   = try Self.renderBitmap( width: size, height: size )
        {
            HoverImageNSView.drawImage( image, into: NSRect( x: 0, y: 0, width: size, height: size ), magnification: 0.5 )
        }

        // Same fixed 20-pt up-scale as the crisp case; only the magnification
        // argument differs (0.5, below 100%), so `drawImage` selects smooth
        // interpolation and the edge blends into a grey transition column. Paired
        // with the crisp case above, this proves `drawImage` picks the
        // interpolation from the magnification — and that `imageInterpolation` is
        // the setting that governs the draw.
        #expect( Self.hasBlendedColumn( rep ) )
    }
}
