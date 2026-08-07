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
import SwiftUI
import Testing

/// Tests for the zoomable canvas, in two parts.
///
/// ``HoverImageNSView`` must render the image with row 0 at the top, matching the
/// coordinate system the star overlay and the cursor pixel readout both assume —
/// the view is `isFlipped`, so drawing the `CGImage` must account for that or the
/// image renders upside-down — and must pick its interpolation from the zoom.
///
/// ``ZoomableImageView/Coordinator`` must publish a displayed-image rectangle that
/// describes the geometry as it stands when the write lands. Those tests host the
/// canvas in a real window so `makeNSView`, `updateNSView` and the AppKit layout
/// notifications all run, since the behaviour under test is an ordering between
/// them that no isolated unit can exercise.
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

    // MARK: - Displayed-image rectangle

    /// Drives the image a hosted canvas shows, so a test can reproduce the app's
    /// own sequence: the canvas appears only once a render result exists, and a
    /// later image swap arrives through `updateNSView`.
    private final class CanvasImageModel: ObservableObject
    {
        /// The image the canvas displays, or `nil` before the first render.
        @Published var image: CGImage?
    }

    /// A SwiftUI host mirroring ``ImageCanvasView``'s structure closely enough for
    /// the coordinator to run through genuine `makeNSView` and `updateNSView`
    /// passes, reporting every rectangle the canvas publishes to ``onRectangle``.
    private struct CanvasHostView: View
    {
        /// The model deciding which image is shown.
        @ObservedObject var model: CanvasImageModel

        /// Called with every displayed-image rectangle the canvas publishes.
        let onRectangle: ( CGRect ) -> Void

        var body: some View
        {
            Color.black
                .frame( maxWidth: .infinity, maxHeight: .infinity )
                .overlay
                {
                    if let image = self.model.image
                    {
                        ZoomableImageView(
                            image:                      image,
                            command:                    CanvasCommand( kind: .fit, token: 0 ),
                            onHover:                    { _ in },
                            onZoomChange:               { _ in },
                            onCanZoomOutChange:         { _ in },
                            onDisplayedImageRectChange: self.onRectangle
                        )
                    }
                }
        }
    }

    /// Collects the rectangles a hosted canvas publishes, in order.
    private final class RectangleLog
    {
        /// Every rectangle published so far, oldest first.
        private( set ) var rectangles: [ CGRect ] = []

        /// The most recently published rectangle, or `nil` if none has been.
        var last: CGRect?
        {
            self.rectangles.last
        }

        /// Records a published rectangle.
        func append( _ rectangle: CGRect )
        {
            self.rectangles.append( rectangle )
        }

        /// Forgets everything recorded so far.
        func reset()
        {
            self.rectangles.removeAll()
        }
    }

    /// Hosts a canvas in a real window of `size`, and returns the window with the
    /// host view, the model driving it and the log of what it publishes.
    ///
    /// The window is ordered front — the canvas needs a real backing store and a
    /// layout pass — so the caller must close it, or it outlives the test in the
    /// process's window list.
    ///
    /// - Parameter size: The window's content size.
    /// - Returns: The window, the host view, its image model, and the rectangle log.
    private static func hostCanvas( size: NSSize ) -> ( window: NSWindow, hosting: NSHostingView< CanvasHostView >, model: CanvasImageModel, log: RectangleLog )
    {
        let log     = RectangleLog()
        let model   = CanvasImageModel()
        let hosting = NSHostingView( rootView: CanvasHostView( model: model, onRectangle: { log.append( $0 ) } ) )
        let window  = NSWindow( contentRect: NSRect( origin: .zero, size: size ), styleMask: [ .titled ], backing: .buffered, defer: false )

        window.contentView = hosting

        window.makeKeyAndOrderFront( nil )

        return ( window, hosting, model, log )
    }

    /// The scroll view the hosted canvas created, found by walking the hierarchy.
    ///
    /// - Parameter view: The root to search.
    /// - Returns: The first `NSScrollView` found, or `nil`.
    private static func hostedScrollView( in view: NSView ) -> NSScrollView?
    {
        if let scrollView = view as? NSScrollView
        {
            return scrollView
        }

        return view.subviews.lazy.compactMap { Self.hostedScrollView( in: $0 ) }.first
    }

    /// The rectangle the hosted document view occupies *now*, computed the way the
    /// canvas computes what it publishes.
    ///
    /// This is deliberately a live re-read rather than a hand-computed geometric
    /// expectation: a correct publication reproduces it exactly, so the comparison
    /// needs no tolerance — whereas a tolerance wide enough to absorb AppKit's
    /// backing-store alignment would also absorb the defect these tests guard.
    ///
    /// - Parameter view: The host view the canvas lives in.
    /// - Returns: The rectangle, in the scroll view's top-left space.
    private static func liveDisplayedRectangle( in view: NSView ) throws -> CGRect
    {
        let scrollView   = try #require( Self.hostedScrollView( in: view ) )
        let documentView = try #require( scrollView.documentView )
        let inScroll     = scrollView.convert( documentView.bounds, from: documentView )

        return scrollView.isFlipped
            ? inScroll
            : CGRect( x: inScroll.minX, y: scrollView.bounds.height - inScroll.maxY, width: inScroll.width, height: inScroll.height )
    }

    /// Lets AppKit lay out and the canvas's deferred writes land, returning once
    /// `log` has stopped growing for two consecutive turns.
    ///
    /// Each turn flushes the main queue in order — `RunLoop.run(until:)` does not
    /// drain those writes under Swift Testing, so the flush goes through an awaited
    /// `DispatchQueue.main.async` hop — then yields for AppKit's layout and display
    /// pass. Waiting on the log rather than on a fixed budget keeps the tests from
    /// racing a slow or loaded machine, where a late publication would otherwise
    /// arrive after the assertions.
    ///
    /// - Parameters:
    ///   - log:      The log whose growth marks the canvas as still settling.
    ///   - maxTurns: The cap, so a canvas that never settles fails on its
    ///               assertions rather than hanging the suite.
    private static func settle( until log: RectangleLog, maxTurns: Int = 40 ) async
    {
        var quietTurns = 0

        for _ in 0 ..< maxTurns
        {
            let before = log.rectangles.count

            await withCheckedContinuation
            {
                continuation in DispatchQueue.main.async { continuation.resume() }
            }

            try? await Task.sleep( for: .milliseconds( 20 ) )

            quietTurns = log.rectangles.count == before ? quietTurns + 1 : 0

            if quietTurns >= 2
            {
                return
            }
        }
    }

    /// The canvas must publish the geometry as it stands when the write lands,
    /// not as it stood when the write was scheduled.
    ///
    /// A fit reports on the next run-loop turn while a live resize reports
    /// synchronously, so a rectangle measured before the resize is delivered
    /// after it. Publishing that measurement leaves every overlay registered to a
    /// rectangle the image no longer occupies, until the next zoom or pan.
    @Test
    func publishesTheSettledRectangleWhenTheViewportMovesDuringTheFit() async throws
    {
        // 400 × 300 into a 600 × 300 viewport: the fit is height-bound and the
        // image is centred with a horizontal inset, so a stale rectangle differs
        // in origin *and* extent rather than hiding inside an aspect-matched fit.
        let canvas = Self.hostCanvas( size: NSSize( width: 600, height: 300 ) )

        defer { canvas.window.close() }

        canvas.model.image = try Self.topWhiteBottomBlackImage( width: 400, height: 300 )

        canvas.hosting.layoutSubtreeIfNeeded()

        // The fit has to have happened and published before the viewport moves, or
        // the scenario degenerates into comparing a settled value with itself and
        // the test passes without exercising anything.
        let beforeResize = try #require( canvas.log.last, "the canvas must have fitted and published before the viewport moves" )

        // Still within the same run-loop turn, the viewport grows.
        canvas.window.setContentSize( NSSize( width: 1000, height: 500 ) )

        canvas.hosting.layoutSubtreeIfNeeded()

        await Self.settle( until: canvas.log )

        let published = try #require( canvas.log.last )
        let live      = try Self.liveDisplayedRectangle( in: canvas.hosting )

        // The resize must actually have moved the geometry, so that a rectangle
        // measured before it is distinguishable from one measured after.
        #expect( beforeResize != live, "the resize must move the geometry for this test to mean anything" )
        #expect( published == live )
    }

    /// A new image with the same pixel dimensions re-fits nothing, but the canvas
    /// must still publish.
    ///
    /// The published rectangle is the only thing registering the overlays, and the
    /// coordinator is reused across files and carousel frames, so without a fresh
    /// publication a newly shown image inherits the standing rectangle unchecked —
    /// leaving no point at which a wrong one is ever corrected.
    @Test
    func publishesARectangleWhenTheImageChangesWithoutChangingTheGeometry() async throws
    {
        let canvas = Self.hostCanvas( size: NSSize( width: 800, height: 400 ) )

        defer { canvas.window.close() }

        canvas.model.image = try Self.topWhiteBottomBlackImage( width: 300, height: 400 )

        await Self.settle( until: canvas.log )

        canvas.log.reset()

        // A different image of identical dimensions — a same-size file switch, or
        // a carousel frame from the same cube.
        canvas.model.image = try Self.topWhiteBottomBlackImage( width: 300, height: 400 )

        canvas.hosting.layoutSubtreeIfNeeded()

        await Self.settle( until: canvas.log )

        let published = try #require( canvas.log.last, "a newly shown image must re-publish its rectangle" )
        let live      = try Self.liveDisplayedRectangle( in: canvas.hosting )

        #expect( published == live )
    }
}
