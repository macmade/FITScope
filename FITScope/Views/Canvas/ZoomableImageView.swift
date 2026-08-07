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
    /// the canvas's top-left coordinate space, whenever zoom, pan, the viewport or
    /// the displayed image changes. Overlays map image-space points into this
    /// rectangle, so it already carries magnification, pan and the centering of a
    /// small image.
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
        // Mutating the scroll view here (resize, re-fit, command) makes AppKit
        // post its bounds / magnification notifications synchronously, so the
        // coordinator's handlers run inside SwiftUI's update pass; the flag lets
        // them defer their state writes while that is the case.
        context.coordinator.applyingViewUpdate
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
                    else
                    {
                        // Same pixel dimensions, so there is nothing to re-fit and
                        // no AppKit notification to report from — but the overlays
                        // still need a rectangle measured for this image rather
                        // than the one the previous image left behind.
                        context.coordinator.republishDisplayedImageRect()
                    }
                }
            }

            context.coordinator.apply( command: self.command )
        }
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

        /// Whether a scroll-view mutation driven by SwiftUI's update pass
        /// (`updateNSView`) is currently in flight. AppKit posts the bounds /
        /// magnification notifications synchronously as the scroll view is
        /// mutated, so ``magnificationChanged()`` runs inside the update pass and
        /// must defer its SwiftUI state write while this is set — a synchronous
        /// write there is reported as "Modifying state during view update".
        private var isApplyingViewUpdate = false

        init( _ parent: ZoomableImageView )
        {
            self.parent = parent
        }

        deinit
        {
            NotificationCenter.default.removeObserver( self )
        }

        /// Runs `body` — a programmatic scroll-view mutation performed from
        /// within SwiftUI's update pass — with ``isApplyingViewUpdate`` set, so
        /// the synchronous AppKit notifications it triggers defer their SwiftUI
        /// state writes out of the update pass.
        ///
        /// - Parameter body: The mutation to apply.
        func applyingViewUpdate( _ body: () -> Void )
        {
            self.isApplyingViewUpdate = true

            defer { self.isApplyingViewUpdate = false }

            body()
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
        /// The geometry is read at the moment the write is made, so a deferred
        /// write describes the layout as it stands a run-loop turn later rather
        /// than as it stood when the write was requested. That distinction is
        /// load-bearing: the synchronous callers report in between, and a
        /// rectangle measured early would be delivered after them — leaving every
        /// overlay registered to a rectangle the image no longer occupies, with
        /// nothing to correct it until the next zoom, pan or resize.
        ///
        /// - Parameter deferred: Whether to defer the SwiftUI write to the next
        ///   run-loop turn (for the same reason as ``reportZoom(_:)``: the caller
        ///   runs inside SwiftUI's update pass). The callers that can run either way
        ///   — resize, magnification and a new image — pass
        ///   ``isApplyingViewUpdate``, so a live AppKit callback reports
        ///   synchronously and re-registers the overlays in the same pass as the
        ///   image, while the same code path defers when driven from an update.
        private func reportDisplayedImageRect( deferred: Bool = true )
        {
            guard deferred
            else
            {
                self.publishDisplayedImageRect()

                return
            }

            DispatchQueue.main.async { self.publishDisplayedImageRect() }
        }

        /// Measures the displayed-image rectangle and hands it to SwiftUI, doing
        /// nothing when there is no longer a scroll view to measure.
        private func publishDisplayedImageRect()
        {
            guard let rect = self.displayedImageRect()
            else
            {
                return
            }

            self.parent.onDisplayedImageRectChange( rect )
        }

        /// The on-screen rectangle the full image currently occupies, in the
        /// canvas's top-left coordinate space, or `nil` when the scroll view or its
        /// document view is gone.
        ///
        /// ``scrollView`` is weak and this is read from deferred blocks as well as
        /// synchronously, so it is resolved on every call rather than captured by
        /// the caller.
        private func displayedImageRect() -> CGRect?
        {
            guard let scrollView   = self.scrollView,
                  let documentView = scrollView.documentView
            else
            {
                return nil
            }

            // `convert(_:from:)` walks the document view up through the magnifying
            // clip view, so the result is in points with magnification, pan and the
            // centering of a small image already applied. The scroll view is
            // flipped (top-left origin, matching the SwiftUI overlay), so the
            // converted rect is used as-is; the non-flipped case is handled for
            // completeness by mirroring the y axis about the scroll view's height.
            let inScroll = scrollView.convert( documentView.bounds, from: documentView )

            return scrollView.isFlipped
                ? inScroll
                : CGRect( x: inScroll.minX, y: scrollView.bounds.height - inScroll.maxY, width: inScroll.width, height: inScroll.height )
        }

        /// Publishes the displayed-image rectangle again, from a fresh
        /// measurement, for a newly shown image that left the geometry unchanged.
        ///
        /// An image of new pixel dimensions re-fits, and the re-fit publishes once
        /// the clip view has a size (otherwise the first frame change does); an
        /// image of the same dimensions re-fits not at all, so nothing else would
        /// publish for it. Since the
        /// coordinator and the reported rectangle are both reused across files and
        /// carousel frames, the overlays would otherwise go on registering against
        /// whatever the previous image left behind, with no point at which a wrong
        /// rectangle is ever recovered from.
        func republishDisplayedImageRect()
        {
            self.reportDisplayedImageRect( deferred: self.isApplyingViewUpdate )
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

            // AppKit scales a cached snapshot on magnification without re-running
            // the image view's draw, so ask it to redraw when the new zoom changes
            // the interpolation — otherwise crisp "real pixels" only appear once an
            // unrelated change forces a redraw.
            ( scrollView.documentView as? HoverImageNSView )?.refreshInterpolation( forMagnification: scrollView.magnification )

            // A live magnify (pinch / scroll-wheel zoom) fires outside SwiftUI's
            // update pass, so report synchronously to keep the overlays locked to
            // the image throughout the gesture. When this instead fires from a
            // programmatic mutation during `updateNSView`, the write must defer to
            // avoid "Modifying state during view update".
            self.reportDisplayedImageRect( deferred: self.isApplyingViewUpdate )
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

            // A live window resize drives this through AppKit's frame-change
            // notification, outside SwiftUI's update pass, so report synchronously:
            // the overlays are re-registered in the same pass as the image and
            // track it without lag. A resize driven from within `updateNSView`
            // defers instead, to avoid "Modifying state during view update".
            self.reportDisplayedImageRect( deferred: self.isApplyingViewUpdate )
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

    /// The multiplier applied by one ⌘+ / ⌘- keyboard step, matching the toolbar
    /// and menu zoom-in / zoom-out amounts.
    private static let keyboardZoomIn:  CGFloat = 1.25
    private static let keyboardZoomOut: CGFloat = 0.8

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

    /// Handles the ⌘+ / ⌘- zoom keys directly, the way AppKit matches key
    /// equivalents — by the character the key produces — so they work on every
    /// keyboard layout. SwiftUI's `.keyboardShortcut` matching failed to fire ⌘-
    /// on non-US layouts (and here even on US), while the menu still shows the
    /// shortcuts; being deeper in the responder chain, this runs before the menu's
    /// equivalents, so the menu items never double-fire. The change reports back
    /// to SwiftUI through the same bounds-change notifications as scroll-wheel and
    /// pinch zoom, keeping the zoom read-out and overlays in step.
    override func performKeyEquivalent( with event: NSEvent ) -> Bool
    {
        let flags = event.modifierFlags.intersection( .deviceIndependentFlagsMask )

        // Command is required; Shift is tolerated (it is needed to type "+" on many
        // layouts and is already reflected in the produced character), but Option
        // and Control are not, so other ⌘-shortcuts are left untouched.
        guard flags.contains( .command ),
              flags.isDisjoint( with: [ .option, .control ] ),
              let key = event.charactersIgnoringModifiers
        else
        {
            return super.performKeyEquivalent( with: event )
        }

        switch key
        {
            case "+",
                 "=": self.zoomAroundViewportCenter( by: Self.keyboardZoomIn )
            case "-":      self.zoomAroundViewportCenter( by: Self.keyboardZoomOut )
            default:       return super.performKeyEquivalent( with: event )
        }

        return true
    }

    /// Multiplies the current magnification by `factor`, clamped to the allowed
    /// range and keeping the centre of the viewport fixed.
    ///
    /// - Parameter factor: The magnification multiplier (> 1 zooms in, < 1 out).
    private func zoomAroundViewportCenter( by factor: CGFloat )
    {
        let target = CanvasGeometry.clamp( self.magnification * factor, min: self.minMagnification, max: self.maxMagnification )
        let clip   = self.contentView.bounds
        let center = CGPoint( x: clip.midX, y: clip.midY )

        self.setMagnification( target, centeredAt: center )
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

    /// The magnification the image was last drawn at, so the canvas can force a
    /// redraw only when a zoom change actually alters the interpolation rather
    /// than on every pan or zoom step. Updated on each ``draw(_:)``.
    private var lastDrawnMagnification: CGFloat = 1.0

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
        // The enclosing scroll view applies the magnification as a transform on
        // this drawing context, so at high zoom the image is upscaled as it is
        // drawn here. Past actual size that upscale is drawn with nearest-neighbor
        // interpolation so individual pixels read as crisp squares for
        // inspection, rather than the smooth blur the default interpolation gives.
        let magnification = self.enclosingScrollView?.magnification ?? 1.0

        self.lastDrawnMagnification = magnification

        Self.drawImage( self.cgImage, into: self.bounds, magnification: magnification )
    }

    /// Redraws the image if changing the magnification to `magnification` alters
    /// the interpolation it should be drawn with (see
    /// ``CanvasGeometry/needsRedrawForInterpolation(previous:current:)``).
    ///
    /// The enclosing scroll view scales a cached snapshot on magnification
    /// without re-running ``draw(_:)``, so the crisp/smooth switch would not
    /// appear until an unrelated change forced a redraw; the canvas calls this
    /// as the magnification changes to apply it live.
    ///
    /// - Parameter magnification: The scroll view's new magnification.
    func refreshInterpolation( forMagnification magnification: CGFloat )
    {
        guard CanvasGeometry.needsRedrawForInterpolation( previous: self.lastDrawnMagnification, current: magnification )
        else
        {
            return
        }

        self.needsDisplay = true
    }

    /// Draws `image` into `rect` in the current graphics context, using
    /// nearest-neighbor interpolation (crisp, real pixels) once `magnification`
    /// reaches the ``CanvasGeometry/usesNearestNeighbor(magnification:)``
    /// threshold and smooth interpolation below it.
    ///
    /// Factored out of ``draw(_:)`` so the interpolation behavior can be
    /// exercised off-screen in tests.
    ///
    /// - Parameters:
    ///   - image:         The image to draw.
    ///   - rect:          The destination rectangle, in the view's coordinates.
    ///   - magnification: The enclosing scroll view's magnification.
    static func drawImage( _ image: CGImage, into rect: NSRect, magnification: CGFloat )
    {
        // The view is `isFlipped` (top-left origin) so image row 0 is at the top,
        // matching the star overlay and the cursor readout. A raw
        // `CGContext.draw` assumes a bottom-left origin and renders the image
        // upside-down in a flipped view; `NSImage.draw(in:)` honours the view's
        // coordinate system and draws it upright. It draws with the current
        // graphics context's `imageInterpolation`, which is set here per zoom.
        let nsImage = NSImage( cgImage: image, size: rect.size )

        NSGraphicsContext.current?.imageInterpolation = CanvasGeometry.usesNearestNeighbor( magnification: magnification ) ? .none : .default

        nsImage.draw( in: rect )
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
