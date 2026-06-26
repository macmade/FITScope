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

/// A simple overlay that outlines the image's borders and marks its centre.
///
/// It is always available — every image has a frame — so it doubles as the
/// reference implementation of ``CanvasOverlay`` and a visible check that the
/// overlay layer stays registered to the image across zoom, pan and resize: the
/// border hugs the image edges and the cross sits on the exact centre at any
/// magnification.
public struct FrameOverlay: CanvasOverlay
{
    public let id              = "frame"
    public let title           = "Image Frame"
    public let systemImageName = "viewfinder"
    public let isAvailable     = true

    /// The overlay's colour.
    private static let color = Color.yellow.opacity( 0.8 )

    /// The on-screen stroke width, kept constant across zoom.
    private static let lineWidth: CGFloat = 1

    /// The on-screen half-length of each arm of the centre cross.
    private static let crossArm: CGFloat = 8

    /// Creates the overlay.
    public init() {}

    public func draw( in context: inout GraphicsContext, imageSize: CGSize, displayedRect: CGRect )
    {
        guard imageSize.width > 0, imageSize.height > 0
        else
        {
            return
        }

        // The border is the displayed rectangle itself, so it tracks the image
        // edges under zoom and pan with no transform needed.
        context.stroke( Path( displayedRect ), with: .color( Self.color ), lineWidth: Self.lineWidth )

        // The cross sits at the image centre, mapped into the displayed rectangle;
        // its arms are sized in on-screen points so they stay constant across zoom.
        let center = CanvasGeometry.viewPoint( forImagePoint: CGPoint( x: imageSize.width / 2, y: imageSize.height / 2 ), imageSize: imageSize, displayedRect: displayedRect )
        var cross  = Path()

        cross.move(    to: CGPoint( x: center.x - Self.crossArm, y: center.y ) )
        cross.addLine( to: CGPoint( x: center.x + Self.crossArm, y: center.y ) )
        cross.move(    to: CGPoint( x: center.x, y: center.y - Self.crossArm ) )
        cross.addLine( to: CGPoint( x: center.x, y: center.y + Self.crossArm ) )

        context.stroke( cross, with: .color( Self.color ), lineWidth: Self.lineWidth )
    }
}
