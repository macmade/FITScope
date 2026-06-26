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

/// A transparent, non-interactive layer that draws the enabled canvas overlays
/// over the image, registered to image space through the displayed-image
/// rectangle reported by ``ZoomableImageView``.
///
/// It is hit-test transparent so the cursor read-out and panning underneath keep
/// working; the caller passes only the overlays that are currently enabled and
/// available.
public struct CanvasOverlayLayer: View
{
    /// The overlays to draw, in back-to-front order.
    private let overlays: [ any CanvasOverlay ]

    /// The displayed image's pixel dimensions.
    private let imageSize: CGSize

    /// The on-screen rectangle the image occupies, in this layer's coordinate
    /// space.
    private let displayedRect: CGRect

    /// Creates the overlay layer.
    ///
    /// - Parameters:
    ///   - overlays:      The overlays to draw, in back-to-front order.
    ///   - imageSize:     The displayed image's pixel dimensions.
    ///   - displayedRect: The on-screen rectangle the image occupies.
    public init( overlays: [ any CanvasOverlay ], imageSize: CGSize, displayedRect: CGRect )
    {
        self.overlays      = overlays
        self.imageSize     = imageSize
        self.displayedRect = displayedRect
    }

    /// The view's content.
    public var body: some View
    {
        Canvas
        {
            context, _ in

            for overlay in self.overlays
            {
                overlay.draw( in: &context, imageSize: self.imageSize, displayedRect: self.displayedRect )
            }
        }
        .allowsHitTesting( false )
    }
}
