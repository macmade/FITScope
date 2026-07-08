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

import Combine
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

    /// The image whose overlays the controller currently drives — the shown frame.
    /// Overlay enablement is stored on the image itself (``LoadedImage/enabledOverlays``),
    /// so it is per-image; the controller reads and toggles that set for whichever
    /// image is shown. `nil` when no image is displayed. Set through ``setImage(_:)``.
    private weak var image: LoadedImage?

    /// Forwards the shown image's overlay-enablement changes to the controller's own
    /// observers, so the toolbar and the *Image* menu (which observe the controller)
    /// refresh when an overlay is toggled or the shown image changes.
    private var overlaysObserver: AnyCancellable?

    /// The identifiers of the overlays the user has turned on for the shown image, or
    /// an empty set when no image is shown. Backed by the image so it is per-image.
    public var enabledOverlays: Set< String >
    {
        self.image?.enabledOverlays ?? []
    }

    /// Whether the before/after comparison is active. When on, the canvas reveals
    /// the captured "before" image on one side of a draggable vertical divider,
    /// with the processed result on the other.
    @Published public var isComparing = false

    /// The comparison divider position as a fraction of the viewport width
    /// (`0` reveals only the processed result, `1` only the captured before),
    /// clamped to `0...1`. Starts centred and is recentred whenever the comparison
    /// is turned on.
    @Published public private( set ) var comparisonFraction: CGFloat = 0.5

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

    /// Toggles the before/after comparison on or off.
    ///
    /// Turning it on recentres the divider, so the comparison always starts from a
    /// predictable middle position rather than wherever it was last dragged.
    public func toggleComparison()
    {
        self.isComparing.toggle()

        if self.isComparing
        {
            self.comparisonFraction = 0.5
        }
    }

    /// Sets the comparison divider position, clamped to `0...1`.
    ///
    /// - Parameter fraction: The divider position as a fraction of the viewport
    ///   width (`0` reveals only the processed result, `1` only the captured
    ///   before).
    public func setComparisonFraction( _ fraction: CGFloat )
    {
        self.comparisonFraction = min( max( fraction, 0 ), 1 )
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

        // Toggle on the shown image, so the selection is remembered per-image.
        if self.image?.enabledOverlays.contains( id ) == true
        {
            self.image?.enabledOverlays.remove( id )
        }
        else
        {
            self.image?.enabledOverlays.insert( id )
        }
    }

    /// Points the controller at the currently shown image (the selected frame), so
    /// overlay toggles operate on that image's own ``LoadedImage/enabledOverlays`` and
    /// the toolbar / *Image* menu track it.
    ///
    /// Subscribing to the image's `enabledOverlays` re-broadcasts the controller's own
    /// change notification whenever the set changes — and once immediately, so the UI
    /// refreshes to the newly shown image's overlays.
    ///
    /// - Parameter image: The shown image, or `nil` when none is displayed.
    public func setImage( _ image: LoadedImage? )
    {
        self.image            = image
        self.overlaysObserver = image?.$enabledOverlays.sink
        {
            [ weak self ] _ in self?.objectWillChange.send()
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
