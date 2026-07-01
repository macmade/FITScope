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

import SwiftUI

/// The shared source of truth for a window's image-canvas interaction, so the
/// floating ``ImageToolbarView`` and the *Image* menu (``ImageCommands``) drive
/// the very same zoom, command and overlay state instead of duplicating it.
///
/// ``ImageCanvasView`` owns one of these per window and publishes it to the scene
/// with `.focusedSceneObject`, so the menu — which lives at scene level — reaches
/// the frontmost window's canvas through `@FocusedObject`, exactly as the File
/// menu reaches the selected file. The zoom actions issue one-shot
/// ``CanvasCommand``s into the scroll view; the overlay tap toggles an available
/// overlay, or lets an unavailable one explain itself (a ``CanvasOverlay/warning``)
/// or run its call to action (``CanvasOverlay/onUnavailableTap``), so the canvas
/// stays free of any overlay-specific knowledge.
@MainActor
public final class ImageCanvasController: ObservableObject
{
    /// The current magnification (1.0 == 100%), reported by the canvas as the user
    /// zoom, and shown as a percentage by the toolbar.
    @Published public var zoom: CGFloat = 1.0

    /// Whether zoom-out is still useful; `false` once the whole image is visible,
    /// which disables both the toolbar's and the menu's Zoom Out.
    @Published public var canZoomOut = true

    /// The latest one-shot canvas command, consumed by ``ZoomableImageView``.
    /// Bumped by ``issue(_:)`` so the same command can be requested twice in a row.
    @Published public private( set ) var command = CanvasCommand( kind: .fit, token: 0 )

    /// The identifiers of the overlays the user has turned on for this file.
    @Published public var enabledOverlays = Set< String >()

    /// Whether the generic overlay alert is shown — raised when an overlay with
    /// nothing to reveal but a ``CanvasOverlay/warning`` is tapped, so the user
    /// sees why it reveals nothing.
    @Published public var isOverlayAlertPresented = false

    /// The title of the overlay alert — the tapped overlay's title.
    @Published public private( set ) var overlayAlertTitle = ""

    /// The message of the overlay alert — the tapped overlay's warning.
    @Published public private( set ) var overlayAlertMessage = ""

    /// The overlays applicable to the current image, in toolbar order. A derived
    /// mirror kept current by ``ImageCanvasView``; deliberately *not* `@Published`,
    /// as it is a copy of view-computed state (writing it during a view update
    /// would be reported as "publishing changes from within view updates"). The
    /// menu re-renders off the published enabled/alert state, and the overlay set
    /// is structurally fixed, so a plain property is enough here.
    public var overlays: [ any CanvasOverlay ] = []

    /// A monotonically increasing token source, making each command distinct.
    private var tokens = 0

    /// Creates a canvas controller with its command in the initial fit state.
    public init() {}

    /// Fits the image to the window.
    public func fit()
    {
        self.issue( .fit )
    }

    /// Shows the image at actual size (100%).
    public func actualSize()
    {
        self.issue( .actualSize )
    }

    /// Recenters the image in the viewport.
    public func recenter()
    {
        self.issue( .recenter )
    }

    /// Zooms in one step.
    public func zoomIn()
    {
        self.issue( .zoomIn )
    }

    /// Zooms out one step.
    public func zoomOut()
    {
        self.issue( .zoomOut )
    }

    /// Whether the overlay with a given identifier is currently enabled.
    ///
    /// - Parameter id: The overlay's stable ``CanvasOverlay/id``.
    /// - Returns: `true` when the overlay is turned on.
    public func isOverlayEnabled( _ id: String ) -> Bool
    {
        self.enabledOverlays.contains( id )
    }

    /// Responds to a tap on an overlay's toggle by identifier — from the toolbar
    /// or the menu, identically.
    ///
    /// An available overlay simply switches on or off. An overlay with nothing to
    /// show handles the tap itself: through its ``CanvasOverlay/warning`` (an
    /// informational alert) or its ``CanvasOverlay/onUnavailableTap`` (a call to
    /// action, e.g. proposing a plate solve) — so the controller stays generic.
    ///
    /// - Parameter id: The tapped overlay's stable ``CanvasOverlay/id``.
    public func overlayTapped( _ id: String )
    {
        guard let overlay = self.overlays.first( where: { $0.id == id } )
        else
        {
            return
        }

        guard overlay.isAvailable
        else
        {
            if let warning = overlay.warning
            {
                self.presentOverlayAlert( title: overlay.title, message: warning )
            }
            else
            {
                overlay.onUnavailableTap?()
            }

            return
        }

        if self.enabledOverlays.contains( id )
        {
            self.enabledOverlays.remove( id )
        }
        else
        {
            self.enabledOverlays.insert( id )
        }
    }

    /// Presents the generic overlay alert with the given title and message.
    ///
    /// - Parameters:
    ///   - title:   The alert's title — the tapped overlay's title.
    ///   - message: The alert's message — the tapped overlay's warning.
    private func presentOverlayAlert( title: String, message: String )
    {
        self.overlayAlertTitle       = title
        self.overlayAlertMessage     = message
        self.isOverlayAlertPresented = true
    }

    /// Issues a one-shot canvas command with a fresh token, so the scroll view —
    /// which de-dupes by token — applies it even when it repeats the last kind.
    ///
    /// - Parameter kind: The command to perform.
    private func issue( _ kind: CanvasCommand.Kind )
    {
        self.tokens += 1
        self.command = CanvasCommand( kind: kind, token: self.tokens )
    }
}
