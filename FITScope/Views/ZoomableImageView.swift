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

import AppKit
import SwiftUI

/// A discrete command sent from SwiftUI into the scroll view, bumped by changing
/// its `token` so the same command can be requested twice in a row.
public struct CanvasCommand: Equatable
{
    /// The kind of one-shot canvas command.
    public enum Kind: Equatable
    {
        case fit
        case recenter
        case zoomIn
        case zoomOut
    }

    /// The command to perform.
    public var kind:  Kind

    /// A nonce making each request distinct.
    public var token: Int

    /// Creates a command.
    public init( kind: Kind, token: Int )
    {
        self.kind  = kind
        self.token = token
    }
}

/// A zoomable, pannable image canvas backed by `NSScrollView`.
///
/// Reports the magnification through `zoom`, performs one-shot fit/recenter/zoom
/// commands via `command`, and calls `onHover` with the image-space pixel
/// coordinate under the cursor (or `nil` when the cursor leaves the image).
public struct ZoomableImageView: NSViewRepresentable
{
    /// The image to display.
    public let image: CGImage

    /// The current magnification (1.0 == 100%). Updated as the user zooms.
    @Binding public var zoom: CGFloat

    /// The latest one-shot command to apply.
    public let command: CanvasCommand

    /// Called with the pixel coordinate under the cursor, or `nil` when outside.
    public let onHover: ( ( x: Int, y: Int )? ) -> Void

    /// Creates the canvas.
    public init( image: CGImage, zoom: Binding< CGFloat >, command: CanvasCommand, onHover: @escaping ( ( x: Int, y: Int )? ) -> Void )
    {
        self.image    = image
        self._zoom    = zoom
        self.command  = command
        self.onHover  = onHover
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

        /// The token of the last command applied, to ignore repeats.
        private var lastCommandToken: Int?

        /// Whether the image has been fitted to the viewport at least once.
        private var hasFitted = false

        /// The pixel dimensions last fitted to, used to detect a genuinely new
        /// image so the view is only re-fitted then.
        private var contentSize = CGSize.zero

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

        @objc private func magnificationChanged()
        {
            guard let scrollView = self.scrollView
            else
            {
                return
            }

            self.parent.zoom = scrollView.magnification
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
                case .fit:      self.fit()
                case .recenter: self.recenter()
                case .zoomIn:   self.zoom( by: 1.25 )
                case .zoomOut:  self.zoom( by: 0.8 )
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

        /// Re-fits when the clip view first gains a non-zero size, avoiding the
        /// zero bounds seen during `makeNSView`.
        @objc func clipBoundsChanged()
        {
            if self.hasFitted == false
            {
                self.fit()
            }
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
            guard let scrollView = self.scrollView,
                  let imageView  = scrollView.documentView
            else
            {
                return
            }

            let visible = scrollView.contentView.frame.size
            let content = imageView.frame.size
            let factor  = CanvasGeometry.fitFactor( content: content, visible: visible )

            guard factor > 0
            else
            {
                return
            }

            let clamped = max( scrollView.minMagnification, min( scrollView.maxMagnification, factor ) )

            scrollView.magnification = clamped
            self.parent.zoom         = clamped
            self.hasFitted           = true
            self.contentSize         = content

            self.recenter()
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
            self.parent.zoom = scrollView.magnification
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
        guard let context = NSGraphicsContext.current?.cgContext
        else
        {
            return
        }

        context.draw( self.cgImage, in: self.bounds )
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

        clip.scroll( to: origin )
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
