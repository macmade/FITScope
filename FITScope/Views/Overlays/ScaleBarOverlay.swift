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

/// A canvas overlay that draws an angular measurement (scale) bar in the bottom-
/// right of the viewport, labelled with a nice round value (arc-seconds, arc-
/// minutes, or degrees) derived from the image's pixel scale.
///
/// Unlike the image-registered overlays, the bar is anchored to the viewport
/// corner (via the graphics context's clip bounds), not to image space — a scale
/// bar belongs to the screen, not the picture. Its length, however, tracks the
/// zoom: it picks the largest nice angular value whose on-screen length fits the
/// allowed width, so the bar stays a sensible size and its label updates as the
/// user zooms. The overlay gates itself through ``isAvailable``, so its toolbar
/// toggle only appears when a pixel scale is known.
public struct ScaleBarOverlay: CanvasOverlay
{
    /// The image's pixel scale, in arc-seconds per pixel, or `nil` when it cannot
    /// be determined (no WCS, focal length, or pixel size).
    private let pixelScale: Double?

    /// Creates the overlay for the given pixel scale.
    ///
    /// - Parameter pixelScale: The plate scale, in arc-seconds per pixel, or `nil`
    ///                         when unknown.
    public init( pixelScale: Double? )
    {
        self.pixelScale = pixelScale
    }

    public let id              = "scale"
    public let title           = "Scale Bar"
    public let systemImageName = "ruler"

    public var isAvailable: Bool
    {
        ( self.pixelScale ?? 0 ) > 0
    }

    public var warning: String?
    {
        self.isAvailable ? nil : "No scale information is available for this image. Plate solve it, or check that its header carries a focal length and pixel size."
    }

    /// A chosen scale-bar measurement: the angular value to display and the length
    /// it occupies on screen.
    public struct Measurement: Equatable
    {
        /// The unit-formatted label, e.g. `30″`, `10′`, or `5°`.
        public let label: String

        /// The bar's on-screen length, in points.
        public let lengthInPoints: CGFloat
    }

    /// The nice round angular values a bar may take, in arc-seconds, ascending:
    /// 1/2/5/10/15/30″, 1/2/5/10/20/30′, then 1/2/5/10°.
    private static let niceArcseconds: [ Double ] =
        [
            1, 2, 5, 10, 15, 30,
            60, 120, 300, 600, 1200, 1800,
            3600, 7200, 18000, 36000,
        ]

    /// The colour of the bar and its label.
    private static let color = Color.white.opacity( CanvasOverlayStyle.alpha )

    /// The on-screen stroke width.
    private static let lineWidth: CGFloat = 1.5

    /// The on-screen height of the end ticks, in points.
    private static let tickHeight: CGFloat = 5

    /// The inset from the visible image's right edge, in points. Generous enough
    /// that, when zoomed in, the bar clears the vertical scroller that appears
    /// along the right edge rather than sitting on top of it.
    private static let margin: CGFloat = 36

    /// The inset from the visible image's bottom edge, in points. Larger than the
    /// side inset to leave room for the floating status bar along the bottom.
    private static let bottomMargin: CGFloat = 56

    /// The gap between the bar and its label, in points.
    private static let labelGap: CGFloat = 3

    /// The label font size, in points.
    private static let labelFontSize: CGFloat = 11

    /// The fraction of the viewport width the bar may occupy at most.
    private static let maxWidthFraction: CGFloat = 0.25

    /// The absolute cap on the bar's on-screen length, in points.
    private static let maxBarLength: CGFloat = 180

    /// Chooses the scale-bar measurement for a pixel scale at the current zoom.
    ///
    /// Picks the largest nice angular value whose on-screen length is at most
    /// `maxLength`, so the bar fills as much of the allowed width as a round value
    /// permits. Returns `nil` when the pixel scale is non-positive or when even the
    /// smallest nice value would overflow the allowed width (an extreme zoom-in).
    ///
    /// - Parameters:
    ///   - pixelScale:   The plate scale, in arc-seconds per pixel.
    ///   - displayScale: On-screen points per image pixel (the magnification).
    ///   - maxLength:    The largest on-screen length the bar may take, in points.
    /// - Returns: The chosen measurement, or `nil` when none fits.
    public static func measurement( pixelScale: Double, displayScale: CGFloat, maxLength: CGFloat ) -> Measurement?
    {
        guard pixelScale > 0, displayScale > 0, maxLength > 0
        else
        {
            return nil
        }

        // The angular span the allowed on-screen width represents, in arc-seconds.
        let maxArcseconds = Double( maxLength / displayScale ) * pixelScale

        guard let arcseconds = Self.niceArcseconds.last( where: { $0 <= maxArcseconds } )
        else
        {
            return nil
        }

        let lengthInPoints = CGFloat( arcseconds / pixelScale ) * displayScale

        return Measurement( label: Self.label( forArcseconds: arcseconds ), lengthInPoints: lengthInPoints )
    }

    /// Formats a nice angular value as a unit-bearing label: arc-seconds below a
    /// minute, arc-minutes below a degree, otherwise degrees.
    ///
    /// - Parameter arcseconds: The angular value, in arc-seconds (a nice value, so
    ///                         it divides evenly into its unit).
    /// - Returns: The formatted label.
    private static func label( forArcseconds arcseconds: Double ) -> String
    {
        if arcseconds < 60
        {
            return "\( Int( arcseconds ) )″"
        }

        if arcseconds < 3600
        {
            return "\( Int( arcseconds / 60 ) )′"
        }

        return "\( Int( arcseconds / 3600 ) )°"
    }

    public func draw( in context: inout GraphicsContext, canvasSize: CGSize, imageSize: CGSize, displayedRect: CGRect )
    {
        guard let pixelScale = self.pixelScale, imageSize.width > 0
        else
        {
            return
        }

        let displayScale = CanvasGeometry.displayScale( imageSize: imageSize, displayedRect: displayedRect )

        // The bar belongs on the image, but must also stay on screen: anchor it to
        // the visible part of the image — its rectangle clipped to the viewport.
        // When the image is smaller than the viewport this is the image itself;
        // when zoomed in past the edges it is the visible portion. The viewport is
        // the canvas size (the graphics context's clip bounds are unreliable here).
        let viewport = CGRect( origin: .zero, size: canvasSize )
        let region   = displayedRect.intersection( viewport )

        guard region.isNull == false, region.width > 0, region.height > 0
        else
        {
            return
        }

        let maxLength = min( region.width * Self.maxWidthFraction, Self.maxBarLength )

        guard let measurement = Self.measurement( pixelScale: pixelScale, displayScale: displayScale, maxLength: maxLength )
        else
        {
            return
        }

        // Anchor to the visible image's bottom-right corner, growing leftward. The
        // larger bottom inset keeps the bar clear of the floating status bar.
        let endX     = region.maxX - Self.margin
        let startX   = endX - measurement.lengthInPoints
        let baseline = region.maxY - Self.bottomMargin

        var path = Path()

        path.move(    to: CGPoint( x: startX, y: baseline ) )
        path.addLine( to: CGPoint( x: endX,   y: baseline ) )

        // End ticks, drawn upward so they stay clear of the viewport edge.
        path.move(    to: CGPoint( x: startX, y: baseline - Self.tickHeight ) )
        path.addLine( to: CGPoint( x: startX, y: baseline ) )
        path.move(    to: CGPoint( x: endX,   y: baseline - Self.tickHeight ) )
        path.addLine( to: CGPoint( x: endX,   y: baseline ) )

        context.stroke( path, with: .color( Self.color ), lineWidth: Self.lineWidth )

        let label = Text( measurement.label ).font( .system( size: Self.labelFontSize, weight: .medium ) ).foregroundStyle( Self.color )

        context.draw( label, at: CGPoint( x: ( startX + endX ) / 2, y: baseline - Self.tickHeight - Self.labelGap ), anchor: .bottom )
    }
}
