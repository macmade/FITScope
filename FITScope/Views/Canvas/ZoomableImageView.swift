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
import SwiftUI

/// A zoomable, pannable image canvas backed by `NSScrollView`.
///
/// Reports the magnification through `zoom`, performs one-shot fit/recenter/zoom
/// commands via `command`, and calls `onHover` with the image-space pixel
/// coordinate under the cursor (or `nil` when the cursor leaves the image).
public struct ZoomableImageView: NSViewRepresentable
{
    /// The image to display.
    public let image: CGImage

    /// The latest one-shot command to apply.
    public let command: CanvasCommand

    /// Called with the pixel coordinate under the cursor, or `nil` when outside.
    public let onHover: ( ( x: Int, y: Int )? ) -> Void

    /// Called with the current magnification (1.0 == 100%) as the user zooms.
    public let onZoomChange: ( CGFloat ) -> Void

    /// Called when zoom-out availability changes; `false` once the whole image
    /// is visible. Driven by the canvas as the magnification and viewport change.
    public let onCanZoomOutChange: ( Bool ) -> Void

    /// Called with the on-screen rectangle the full image currently occupies, in
    /// the canvas's top-left coordinate space, whenever zoom, pan or the viewport
    /// changes. Overlays map image-space points into this rectangle, so it already
    /// carries magnification, pan and the centering of a small image.
    public let onDisplayedImageRectChange: ( CGRect ) -> Void

    /// Creates the canvas.
    public init( image: CGImage, command: CanvasCommand, onHover: @escaping ( ( x: Int, y: Int )? ) -> Void, onZoomChange: @escaping ( CGFloat ) -> Void, onCanZoomOutChange: @escaping ( Bool ) -> Void, onDisplayedImageRectChange: @escaping ( CGRect ) -> Void )
    {
        self.image                      = image
        self.command                    = command
        self.onHover                    = onHover
        self.onZoomChange               = onZoomChange
        self.onCanZoomOutChange         = onCanZoomOutChange
        self.onDisplayedImageRectChange = onDisplayedImageRectChange
    }

    public func makeCoordinator() -> Coordinator
    {
        Coordinator( self )
    }

    public func makeNSView( context: Context ) -> NSScrollView
    {
        let scrollView = ZoomingScrollView()
        let imageView  = HoverImageNSView( cgImage: self.image )

        imageView.onHover = self.onHover

        scrollView.contentView          = CenteringClipView()
        scrollView.documentView         = imageView
        scrollView.allowsMagnification  = true
        scrollView.minMagnification     = 0.05
        scrollView.maxMagnification     = 40.0
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller   = true
        scrollView.autohidesScrollers    = true
        scrollView.backgroundColor       = .black
        scrollView.contentView.postsBoundsChangedNotifications = true

        context.coordinator.scrollView = scrollView
        context.coordinator.observeMagnification()

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector( Coordinator.clipBoundsChanged ),
            name:     NSView.frameDidChangeNotification,
            object:   scrollView.contentView
        )

        scrollView.contentView.postsFrameChangedNotifications = true

        context.coordinator.fitWhenReady()

        return scrollView
    }

    public func updateNSView( _ nsView: NSScrollView, context: Context )
    {
        if let imageView = nsView.documentView as? HoverImageNSView
        {
            imageView.onHover = self.onHover

            if imageView.cgImage !== self.image
            {
                let sizeChanged = imageView.cgImage.width != self.image.width || imageView.cgImage.height != self.image.height

                imageView.cgImage      = self.image
                imageView.needsDisplay = true

                if sizeChanged
                {
                    imageView.setFrameSize( NSSize( width: self.image.width, height: self.image.height ) )
                    context.coordinator.refit()
                }
            }
        }

        context.coordinator.apply( command: self.command )
    }

    /// Bridges AppKit callbacks back to SwiftUI state.
    @MainActor
    public final class Coordinator: NSObject
    {
        private let parent: ZoomableImageView

        /// The hosted scroll view.
        weak var scrollView: NSScrollView?

        /// The hard lower bound on magnification, used when an image is too large
        /// to ever fully fit, so the scroll view keeps a sane minimum.
        private static let minimumZoom: CGFloat = 0.05

        /// The token of the last command applied, to ignore repeats.
        private var lastCommandToken: Int?

        /// Whether the image has been fitted to the viewport at least once.
        private var hasFitted = false

        /// The magnification at which the image currently fits the viewport,
        /// recomputed whenever the image or viewport changes.
        private var fitMagnification: CGFloat = 0

        init( _ parent: ZoomableImageView )
        {
            self.parent = parent
        }

        deinit
        {
            NotificationCenter.default.removeObserver( self )
        }

        /// Subscribes to magnification changes to keep `zoom` in sync.
        func observeMagnification()
        {
            guard let scrollView = self.scrollView
            else
            {
                return
            }

            // A live pinch continuously rescales the clip view's bounds, so its
            // bounds-change notification tracks the magnification throughout the
            // gesture; the end notification provides a final sync.
            NotificationCenter.default.addObserver( self, selector: #selector( self.magnificationChanged ), name: NSView.boundsDidChangeNotification, object: scrollView.contentView )
            NotificationCenter.default.addObserver( self, selector: #selector( self.magnificationChanged ), name: NSScrollView.didEndLiveMagnifyNotification, object: scrollView )
        }

        /// Reports the magnification to SwiftUI on the next run-loop turn.
        ///
        /// The coordinator runs from `updateNSView` / `makeNSView` and from AppKit
        /// layout notifications that fire during SwiftUI's update pass; writing the
        /// observed `zoom` / `canZoomOut` state synchronously there is reported as
        /// "publishing changes from within view updates" (notably when switching
        /// to a file changes the image and triggers a re-fit). Deferring the write
        /// moves it out of the update pass — imperceptible for the read-out and the
        /// zoom-out button.
        private func reportZoom( _ magnification: CGFloat )
        {
            DispatchQueue.main.async { self.parent.onZoomChange( magnification ) }
        }

        /// Reports zoom-out availability to SwiftUI on the next run-loop turn, for
        /// the same reason as ``reportZoom(_:)``.
        private func reportCanZoomOut( _ canZoomOut: Bool )
        {
            DispatchQueue.main.async { self.parent.onCanZoomOutChange( canZoomOut ) }
        }

        /// Reports the on-screen rectangle the full image occupies, in the
        /// canvas's top-left coordinate space, for overlays to draw into.
        ///
        /// The geometry is read now — from the document view's bounds converted up
        /// through the magnifying clip view, then flipped from the scroll view's
        /// bottom-left space to the overlay's top-left space — but the SwiftUI
        /// write is deferred to the next run-loop turn, for the same reason as
        /// ``reportZoom(_:)``.
        private func reportDisplayedImageRect()
        {
            guard let scrollView = self.scrollView,
                  let documentView = scrollView.documentView
            else
            {
                return
            }

            // `convert(_:from:)` walks the document view up through the magnifying
            // clip view, so the result is in points with magnification, pan and the
            // centering of a small image already applied. The scroll view is
            // flipped (top-left origin, matching the SwiftUI overlay), so the
            // converted rect is used as-is; the non-flipped case is handled for
            // completeness by mirroring the y axis about the scroll view's height.
            let inScroll = scrollView.convert( documentView.bounds, from: documentView )
            let rect      = scrollView.isFlipped
                ? inScroll
                : CGRect( x: inScroll.minX, y: scrollView.bounds.height - inScroll.maxY, width: inScroll.width, height: inScroll.height )

            DispatchQueue.main.async { self.parent.onDisplayedImageRectChange( rect ) }
        }

        @objc
        private func magnificationChanged()
        {
            guard let scrollView = self.scrollView
            else
            {
                return
            }

            self.reportZoom( scrollView.magnification )

            self.publishZoomOutAvailability()
            self.reportDisplayedImageRect()
        }

        /// Recomputes the fit magnification and the scroll view's minimum
        /// magnification for the current image and viewport sizes, and returns the
        /// fit magnification (`0` for degenerate sizes).
        @discardableResult
        private func updateFitGeometry() -> CGFloat
        {
            guard let scrollView = self.scrollView,
                  let imageView  = scrollView.documentView
            else
            {
                return 0
            }

            let fit = CanvasGeometry.boundedFitFactor( content: imageView.frame.size, visible: scrollView.contentView.frame.size, minimum: Self.minimumZoom, maximum: scrollView.maxMagnification )

            guard fit > 0
            else
            {
                return 0
            }

            let rawFit = CanvasGeometry.fitFactor( content: imageView.frame.size, visible: scrollView.contentView.frame.size )

            self.fitMagnification       = fit
            scrollView.minMagnification = CanvasGeometry.minimumMagnification( fitFactor: rawFit, floor: Self.minimumZoom )

            return fit
        }

        /// Publishes whether zoom-out is still useful at the current magnification.
        private func publishZoomOutAvailability()
        {
            guard let scrollView = self.scrollView
            else
            {
                return
            }

            self.reportCanZoomOut( CanvasGeometry.canZoomOut( magnification: scrollView.magnification, minimum: scrollView.minMagnification ) )
        }

        /// Applies a one-shot command if its token is new.
        func apply( command: CanvasCommand )
        {
            guard self.lastCommandToken != command.token
            else
            {
                return
            }

            self.lastCommandToken = command.token

            switch command.kind
            {
                case .fit:        self.fit()
                case .actualSize: self.zoom( to: 1.0 )
                case .recenter:   self.recenter()
                case .zoomIn:     self.zoom( by: 1.25 )
                case .zoomOut:    self.zoom( by: 0.8 )
            }
        }

        /// Fits now if the clip view already has a real size; otherwise the
        /// first frame-change notification will trigger it.
        func fitWhenReady()
        {
            if let clip = self.scrollView?.contentView, clip.bounds.width > 0, clip.bounds.height > 0
            {
                self.fit()
            }
        }

        /// Handles a viewport size change: re-fits when the clip view first gains
        /// a non-zero size (avoiding the zero bounds seen during `makeNSView`),
        /// and afterwards keeps a fitted image fitted while tracking the zoom-out
        /// bound for an image the user has zoomed in on.
        @objc
        func clipBoundsChanged()
        {
            guard let scrollView = self.scrollView
            else
            {
                return
            }

            if self.hasFitted == false
            {
                self.fit()

                return
            }

            let wasFitted = CanvasGeometry.isFitted( magnification: scrollView.magnification, fitMagnification: self.fitMagnification )

            self.updateFitGeometry()

            let target = CanvasGeometry.magnificationAfterResize( currentMagnification: scrollView.magnification, fitMagnification: self.fitMagnification, wasFitted: wasFitted )

            if target != scrollView.magnification
            {
                // The image was re-fitted or snapped back up to fill the viewport;
                // recenter it.
                scrollView.magnification = target

                self.reportZoom( target )
                self.recenter()
            }
            else if wasFitted
            {
                // Still fitted at the same magnification: keep it centred as the
                // viewport changes.
                self.recenter()
            }

            self.publishZoomOutAvailability()
            self.reportDisplayedImageRect()
        }

        /// Forces a fresh fit, used when a genuinely new image is displayed.
        func refit()
        {
            self.hasFitted = false

            self.fitWhenReady()
        }

        /// Scales the image to fit the visible area and recenters.
        func fit()
        {
            guard let scrollView = self.scrollView
            else
            {
                return
            }

            let fit = self.updateFitGeometry()

            guard fit > 0
            else
            {
                return
            }

            scrollView.magnification = fit
            self.reportZoom( fit )
            self.hasFitted           = true

            self.recenter()
            self.publishZoomOutAvailability()
            self.reportDisplayedImageRect()
        }

        /// Centers the document in the visible area.
        func recenter()
        {
            guard let scrollView = self.scrollView,
                  let imageView  = scrollView.documentView
            else
            {
                return
            }

            let visibleDoc = scrollView.contentView.bounds.size
            let origin     = CanvasGeometry.centeredOrigin( content: imageView.frame.size, visibleInDocumentSpace: visibleDoc )

            imageView.scroll( origin )
        }

        /// Multiplies the current magnification by `factor`, keeping the centre
        /// of the viewport fixed, and reports the actually-applied value.
        private func zoom( by factor: CGFloat )
        {
            guard let scrollView = self.scrollView
            else
            {
                return
            }

            let target = CanvasGeometry.clamp( scrollView.magnification * factor, min: scrollView.minMagnification, max: scrollView.maxMagnification )
            let clip   = scrollView.contentView.bounds
            let center = CGPoint( x: clip.midX, y: clip.midY )

            scrollView.setMagnification( target, centeredAt: center )
            self.reportZoom( scrollView.magnification )
        }

        /// Sets the magnification to an absolute value, keeping the centre of the
        /// viewport fixed, and reports the actually-applied value.
        private func zoom( to magnification: CGFloat )
        {
            guard let scrollView = self.scrollView
            else
            {
                return
            }

            let target = CanvasGeometry.clamp( magnification, min: scrollView.minMagnification, max: scrollView.maxMagnification )
            let clip   = scrollView.contentView.bounds
            let center = CGPoint( x: clip.midX, y: clip.midY )

            scrollView.setMagnification( target, centeredAt: center )
            self.reportZoom( scrollView.magnification )
        }
    }
}

/// An `NSScrollView` that zooms on scroll-wheel input — centred on the cursor —
/// instead of scrolling the document. Panning stays available by click-drag and
/// pinch-to-zoom keeps working through the standard magnify gesture.
final class ZoomingScrollView: NSScrollView
{
    /// The magnification multiplier applied per discrete wheel notch.
    private static let zoomStep = 1.2

    override func scrollWheel( with event: NSEvent )
    {
        guard event.scrollingDeltaY != 0
        else
        {
            return
        }

        // Scroll up zooms in, scroll down zooms out. A precise device (trackpad
        // or Magic Mouse) streams many small deltas for a smooth zoom; a classic
        // wheel sends one discrete notch per event.
        let steps  = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY / 30.0 : ( event.scrollingDeltaY > 0 ? 1.0 : -1.0 )
        let factor = CGFloat( pow( Self.zoomStep, Double( steps ) ) )
        let target = CanvasGeometry.clamp( self.magnification * factor, min: self.minMagnification, max: self.maxMagnification )
        let point  = self.contentView.convert( event.locationInWindow, from: nil )

        self.setMagnification( target, centeredAt: point )
    }
}

/// A clip view that centres the document view when it is smaller than the clip
/// bounds, so a fitted image that does not fill the viewport sits in the middle
/// rather than in a corner. When the document is larger than the clip, normal
/// scrolling applies.
final class CenteringClipView: NSClipView
{
    override func constrainBoundsRect( _ proposedBounds: NSRect ) -> NSRect
    {
        var rect = super.constrainBoundsRect( proposedBounds )

        guard let documentView = self.documentView
        else
        {
            return rect
        }

        let document = documentView.frame.size

        if rect.size.width > document.width
        {
            rect.origin.x = ( document.width - rect.size.width ) / 2
        }

        if rect.size.height > document.height
        {
            rect.origin.y = ( document.height - rect.size.height ) / 2
        }

        return rect
    }
}

/// A flipped `NSView` that draws a `CGImage` and reports the image-space pixel
/// under the cursor through `onHover`.
final class HoverImageNSView: NSView
{
    /// The image to draw.
    var cgImage: CGImage

    /// Called with the pixel coordinate under the cursor, or `nil` when outside.
    var onHover: ( ( ( x: Int, y: Int )? ) -> Void )?

    /// The cursor location, in window coordinates, at the previous drag step,
    /// used to pan by exact 1:1 increments while a drag is in progress.
    private var panAnchor: NSPoint?

    /// A flipped coordinate system so image row 0 is at the top.
    override var isFlipped: Bool
    {
        true
    }

    init( cgImage: CGImage )
    {
        self.cgImage = cgImage

        super.init( frame: NSRect( x: 0, y: 0, width: cgImage.width, height: cgImage.height ) )
    }

    @available( *, unavailable )
    required init?( coder: NSCoder )
    {
        fatalError( "init(coder:) is not supported" )
    }

    override func draw( _ dirtyRect: NSRect )
    {
        // The view is `isFlipped` (top-left origin) so image row 0 is at the top,
        // matching the star overlay and the cursor readout. A raw
        // `CGContext.draw` assumes a bottom-left origin and renders the image
        // upside-down in a flipped view; `NSImage.draw(in:)` honours the view's
        // coordinate system and draws it upright.
        let image = NSImage( cgImage: self.cgImage, size: self.bounds.size )

        image.draw( in: self.bounds )
    }

    override func updateTrackingAreas()
    {
        super.updateTrackingAreas()

        self.trackingAreas.forEach { self.removeTrackingArea( $0 ) }

        let area = NSTrackingArea( rect: self.bounds, options: [ .mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect ], owner: self, userInfo: nil )

        self.addTrackingArea( area )
    }

    override func mouseMoved( with event: NSEvent )
    {
        let point = self.convert( event.locationInWindow, from: nil )
        let x     = Int( point.x.rounded( .down ) )
        let y     = Int( point.y.rounded( .down ) )

        if x >= 0, x < self.cgImage.width, y >= 0, y < self.cgImage.height
        {
            self.onHover?( ( x: x, y: y ) )
        }
        else
        {
            self.onHover?( nil )
        }
    }

    override func mouseExited( with event: NSEvent )
    {
        self.onHover?( nil )
    }

    override func mouseDown( with event: NSEvent )
    {
        self.panAnchor = event.locationInWindow

        NSCursor.closedHand.set()
    }

    override func mouseDragged( with event: NSEvent )
    {
        guard let scrollView = self.enclosingScrollView,
              let anchor     = self.panAnchor
        else
        {
            return
        }

        let location      = event.locationInWindow
        let magnification  = max( scrollView.magnification, 0.0001 )
        let clip           = scrollView.contentView

        // `locationInWindow` is in window points: it neither scales with the
        // magnification nor moves as the document scrolls, so its delta is a
        // clean, acceleration-free measure of cursor travel. Convert it to
        // document units, and note that the clip view is flipped (y grows
        // downward) while window coordinates grow upward.
        var origin = clip.bounds.origin
        origin.x  -= ( location.x - anchor.x ) / magnification
        origin.y  += ( location.y - anchor.y ) / magnification

        // Route the proposed origin through the clip view's own constraint so a
        // pan can't drag the image past its edges into the black background;
        // `scroll(to:)` alone does not constrain.
        let constrained = clip.constrainBoundsRect( NSRect( origin: origin, size: clip.bounds.size ) )

        clip.scroll( to: constrained.origin )
        scrollView.reflectScrolledClipView( clip )

        self.panAnchor = location
    }

    override func mouseUp( with event: NSEvent )
    {
        self.panAnchor = nil

        NSCursor.arrow.set()
    }

    override func resetCursorRects()
    {
        self.addCursorRect( self.bounds, cursor: .openHand )
    }
}
