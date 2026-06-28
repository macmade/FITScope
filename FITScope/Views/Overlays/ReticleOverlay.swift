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

/// A canvas overlay that frames the image and marks its centre: the image border,
/// a full crosshair spanning the image through its centre, and concentric centre
/// rings — drawn as one element in a single colour.
///
/// It consolidates the old separate frame and centre overlays. The border hugs the
/// displayed image; a fixed, centred crosshair (modelled on NINA's) extends a set
/// fraction from the centre, staying well clear of the border; and the rings — a
/// tight central bullseye plus graduated outer rings — give the familiar target.
/// The crosshair and rings are sized as fractions of the displayed image, so the
/// whole reticle scales with the picture and stays registered to it across zoom and
/// pan (the border comes from the displayed rectangle; the centre is mapped through
/// ``CanvasGeometry``). It is always available — every image has a frame and a
/// centre — so its toolbar toggle is always offered.
public struct ReticleOverlay: CanvasOverlay
{
    /// Creates the overlay.
    public init()
    {}

    public let id              = "reticle"
    public let title           = "Reticle"
    public let systemImageName = "plus.viewfinder"
    public let isAvailable     = true

    /// The reticle colour, shared by the border, crosshair, and rings (the frame's
    /// colour, so the consolidated overlay keeps the familiar frame look).
    private static let color = Color.yellow.opacity( 0.8 )

    /// The on-screen stroke width, kept constant across zoom.
    private static let lineWidth: CGFloat = 1

    /// The six ring radii, in NINA's reference units, built so the two-regime
    /// design is explicit rather than a list of opaque numbers:
    ///
    /// - The inner three are a **bullseye that doubles each ring** (5, 10, 20):
    ///   tight, fine spacing near the centre, where you judge small offsets to
    ///   place a target dead-centre.
    /// - The outer three are **evenly spaced** (46, 88, 130): regular reference
    ///   rings for framing, which read more easily than ever-widening ones.
    ///
    /// They are normalised in ``ringFractions`` so the outer ring is a fixed
    /// fraction of the frame.
    private static let ringRadii: [ CGFloat ] =
    {
        let bullseyeBase:  CGFloat = 5
        let framingStart:  CGFloat = 46
        let framingStep:   CGFloat = 42

        // `1 << i` is 1, 2, 4 — so each bullseye ring is double the previous.
        let bullseye = ( 0 ..< 3 ).map { bullseyeBase * CGFloat( 1 << $0 ) }
        let framing  = ( 0 ..< 3 ).map { framingStart + framingStep * CGFloat( $0 ) }

        return bullseye + framing
    }()

    /// The outer ring's radius as a fraction of the displayed image's smaller
    /// dimension (1/8 of the frame). The other rings keep ``ringRadii``'s
    /// proportions, scaled to this.
    private static let outerRingFraction: CGFloat = 0.125

    /// The ring radii as fractions of the displayed image's smaller dimension, so
    /// the reticle scales with the picture at any magnification. Scaled so the
    /// outer ring is ``outerRingFraction`` of the frame.
    private static let ringFractions: [ CGFloat ] =
    {
        let outer = Self.ringRadii.last ?? 1

        return Self.ringRadii.map { $0 / outer * Self.outerRingFraction }
    }()

    /// Each crosshair arm's outer tip, as a fraction of the displayed image's
    /// smaller dimension. Short enough to leave generous space to the border, long
    /// enough to reach well past the outer ring (NINA's proportions). The arms stop
    /// at the second ring on their way in (see ``draw(in:canvasSize:imageSize:displayedRect:)``),
    /// so the centre stays open.
    private static let crosshairArmOuterFraction: CGFloat = 0.35

    /// The image's centre, in image pixel space: its midpoint.
    ///
    /// - Parameter imageSize: The displayed image's pixel dimensions.
    /// - Returns: The centre point, in image pixel space.
    public static func imageCenter( imageSize: CGSize ) -> CGPoint
    {
        CGPoint( x: imageSize.width / 2, y: imageSize.height / 2 )
    }

    public func draw( in context: inout GraphicsContext, canvasSize: CGSize, imageSize: CGSize, displayedRect: CGRect )
    {
        guard imageSize.width > 0, imageSize.height > 0
        else
        {
            return
        }

        // Map the image centre into the displayed frame, so the reticle tracks the
        // true centre under zoom and pan.
        let center = CanvasGeometry.viewPoint( forImagePoint: Self.imageCenter( imageSize: imageSize ), imageSize: imageSize, displayedRect: displayedRect )

        let base = min( displayedRect.width, displayedRect.height )

        // The border is the displayed rectangle itself, so it hugs the image edges.
        context.stroke( Path( displayedRect ), with: .color( Self.color ), lineWidth: Self.lineWidth )

        // Four crosshair arms that do NOT cross the centre: each runs from the
        // second ring (so it crosses the outer ring on the way in) out to a fixed
        // tip, leaving the middle to the rings alone.
        let outer = base * Self.crosshairArmOuterFraction
        let inner = base * ( Self.ringFractions.dropLast().last ?? 0 )
        var cross = Path()

        cross.move(    to: CGPoint( x: center.x, y: center.y - outer ) )
        cross.addLine( to: CGPoint( x: center.x, y: center.y - inner ) )
        cross.move(    to: CGPoint( x: center.x, y: center.y + inner ) )
        cross.addLine( to: CGPoint( x: center.x, y: center.y + outer ) )
        cross.move(    to: CGPoint( x: center.x - outer, y: center.y ) )
        cross.addLine( to: CGPoint( x: center.x - inner, y: center.y ) )
        cross.move(    to: CGPoint( x: center.x + inner, y: center.y ) )
        cross.addLine( to: CGPoint( x: center.x + outer, y: center.y ) )

        context.stroke( cross, with: .color( Self.color ), lineWidth: Self.lineWidth )

        // Concentric rings, sized relative to the displayed image so they scale.
        var rings = Path()

        Self.ringFractions.forEach
        {
            fraction in

            let radius = base * fraction

            rings.addEllipse( in: CGRect( x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2 ) )
        }

        context.stroke( rings, with: .color( Self.color ), lineWidth: Self.lineWidth )
    }
}
