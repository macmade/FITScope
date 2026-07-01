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

/// An annotation drawn over the image canvas, registered to image space and
/// transformed with zoom and pan.
///
/// An overlay never deals with magnification or scroll directly: it is handed
/// the rectangle the displayed image currently occupies (which already encodes
/// zoom, pan and the centering of a small image) and maps its image-space points
/// into that rectangle with ``CanvasGeometry``. Stroke widths and marker sizes
/// are expressed in on-screen points, so they stay constant across zoom; use
/// ``CanvasGeometry/displayScale(imageSize:displayedRect:)`` when a size must
/// instead scale with the image.
public protocol CanvasOverlay
{
    /// A stable identifier, used to key the overlay's enabled state and its
    /// toolbar toggle. It must not be a localized or display-derived string.
    var id: String { get }

    /// A short title for the overlay's toolbar toggle, shown as its tooltip.
    var title: String { get }

    /// The SF Symbol shown on the overlay's toolbar toggle.
    var systemImageName: String { get }

    /// Whether the overlay has something to show for the current image. Its
    /// toolbar toggle is hidden when this is `false`, so the toolbar never offers
    /// a toggle that would reveal nothing.
    var isAvailable: Bool { get }

    /// Whether the overlay's data is still being computed. While `true`, the
    /// toolbar shows the overlay's button in a disabled, in-progress state instead
    /// of an active toggle — so the toolbar handles "loading" generically, without
    /// knowing what any particular overlay computes. Defaults to `false`.
    var isLoading: Bool { get }

    /// A warning message for an overlay that has finished computing but has nothing
    /// to show — e.g. star detection ran yet found no stars. When non-`nil`, the
    /// toolbar keeps the overlay's toggle visible (so the user learns the work ran)
    /// and, on tap, presents this message instead of switching on an empty layer.
    /// `nil` when there is nothing to warn about. Defaults to `nil`, so the toolbar
    /// handles warnings generically without knowing what any overlay computes.
    var warning: String? { get }

    /// Draws the overlay into the canvas.
    ///
    /// - Parameters:
    ///   - context:       The graphics context, in the canvas's top-left
    ///                    coordinate space.
    ///   - canvasSize:    The on-screen size of the canvas (the viewport). Most
    ///                    overlays ignore it; a screen-anchored overlay (e.g. the
    ///                    scale bar) uses it to stay within the visible area.
    ///   - imageSize:     The displayed image's pixel dimensions.
    ///   - displayedRect: The on-screen rectangle the image occupies; map
    ///                    image-space points into it with ``CanvasGeometry``.
    func draw( in context: inout GraphicsContext, canvasSize: CGSize, imageSize: CGSize, displayedRect: CGRect )
}

public extension CanvasOverlay
{
    /// Overlays whose data is always ready report `false`; a data-driven overlay
    /// that computes asynchronously overrides this while its work is in flight.
    var isLoading: Bool
    {
        false
    }

    /// Overlays with nothing to warn about report `nil`; a data-driven overlay
    /// overrides this to surface a warning once it has run and found nothing.
    var warning: String?
    {
        nil
    }
}
