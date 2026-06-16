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
        let scrollView = NSScrollView()
        let imageView  = HoverImageNSView( cgImage: self.image )

        imageView.onHover = self.onHover

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
        context.coordinator.fit()

        return scrollView
    }

    public func updateNSView( _ nsView: NSScrollView, context: Context )
    {
        if let imageView = nsView.documentView as? HoverImageNSView
        {
            imageView.onHover = self.onHover

            if imageView.cgImage !== self.image
            {
                imageView.cgImage = self.image
                imageView.setFrameSize( NSSize( width: self.image.width, height: self.image.height ) )
                imageView.needsDisplay = true
                context.coordinator.fit()
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

        init( _ parent: ZoomableImageView )
        {
            self.parent = parent
        }

        /// Subscribes to magnification changes to keep `zoom` in sync.
        func observeMagnification()
        {
            guard let scrollView = self.scrollView
            else
            {
                return
            }

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

        /// Scales the image to fit the visible area and recenters.
        func fit()
        {
            guard let scrollView = self.scrollView,
                  let imageView  = scrollView.documentView
            else
            {
                return
            }

            let visible = scrollView.contentView.bounds.size
            let content = imageView.frame.size

            guard content.width > 0, content.height > 0, visible.width > 0, visible.height > 0
            else
            {
                return
            }

            let factor = min( visible.width / content.width, visible.height / content.height )

            scrollView.magnification = factor
            self.parent.zoom         = factor
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

            let bounds = imageView.frame
            let centerPoint = NSPoint( x: bounds.midX, y: bounds.midY )

            imageView.scroll( NSPoint( x: centerPoint.x - scrollView.contentView.bounds.width / 2, y: centerPoint.y - scrollView.contentView.bounds.height / 2 ) )
        }

        /// Multiplies the current magnification by `factor`, around the center.
        private func zoom( by factor: CGFloat )
        {
            guard let scrollView = self.scrollView
            else
            {
                return
            }

            let target = max( scrollView.minMagnification, min( scrollView.maxMagnification, scrollView.magnification * factor ) )

            scrollView.animator().magnification = target
            self.parent.zoom = target
        }
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
}
