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

import SwiftAstro
import SwiftPixel
import SwiftUI

/// A canvas overlay that marks each detected star with a circle registered to
/// image space, optionally labelled with a per-star measurement.
///
/// Each marker is centred on the star's centroid and sized from its half-flux
/// radius, so the circle hugs the star and grows with zoom; a minimum on-screen
/// radius keeps even faint, tightly-focused stars visible when zoomed out. When
/// ``metric`` is not ``StarLabelMetric/none``, the chosen measurement (HFR or
/// FWHM) is drawn beside each marker. The overlay gates itself through
/// ``isAvailable``, so its toolbar toggle only appears once detection has found at
/// least one star.
///
/// Detection runs on the un-reoriented sensor data, so the star centroids are in
/// *source* pixel coordinates. The overlay maps each one through the current
/// ``orientation`` before drawing, so the markers track the image as the user
/// rotates or flips it rather than staying pinned to the source frame.
public struct StarsOverlay: CanvasOverlay
{
    /// The detected stars to mark, in source-image pixel coordinates.
    private let stars: [ Star ]

    /// The orientation currently applied to the displayed image, used to map the
    /// source-space star centroids into the displayed frame.
    private let orientation: Processors.Orient.Orientation

    /// Whether star detection is still running. Drives the toolbar's in-progress
    /// state until ``isAvailable`` becomes true (or detection finds nothing).
    public let isLoading: Bool

    /// Whether star detection has finished running at least once for this image.
    /// Distinguishes "detection not yet run" (no toggle, no warning) from "ran and
    /// found nothing" (toggle kept, warning shown) — since both leave ``stars``
    /// empty.
    private let hasDetectedStars: Bool

    /// The markers' and labels' appearance (colour + opacity).
    private let appearance: OverlayAppearance

    /// The per-star measurement labelled next to each marker — none, HFR or FWHM.
    private let metric: StarLabelMetric

    /// Creates the overlay for the given detected stars.
    ///
    /// - Parameters:
    ///   - stars:            The detected stars, in source-image pixel coordinates.
    ///   - orientation:      The orientation applied to the displayed image.
    ///   - isLoading:        Whether detection is still running. Defaults to `false`.
    ///   - hasDetectedStars: Whether detection has finished running at least once.
    ///                       Defaults to `false`.
    ///   - appearance:       The markers' colour and opacity. Defaults to
    ///                       ``StarsOverlay/defaultAppearance``.
    ///   - metric:           The per-star measurement to label next to each marker.
    ///                       Defaults to ``StarLabelMetric/none`` (no labels).
    public init( stars: [ Star ], orientation: Processors.Orient.Orientation = .identity, isLoading: Bool = false, hasDetectedStars: Bool = false, appearance: OverlayAppearance = StarsOverlay.defaultAppearance, metric: StarLabelMetric = .none )
    {
        self.stars            = stars
        self.orientation      = orientation
        self.isLoading        = isLoading
        self.hasDetectedStars = hasDetectedStars
        self.appearance       = appearance
        self.metric           = metric
    }

    /// The overlay's stable identifier.
    public static let identifier = "stars"

    /// The markers' default appearance — semi-transparent green.
    public static let defaultAppearance = OverlayAppearance( color: .green, opacity: CanvasOverlayStyle.alpha, secondaryOpacity: CanvasOverlayStyle.alpha )

    public let id              = StarsOverlay.identifier
    public let title           = "Detected Stars"
    public let systemImageName = "sparkles"

    public var isAvailable: Bool
    {
        self.stars.isEmpty == false
    }

    public var warning: String?
    {
        // Only once detection has actually run and returned nothing: while it is
        // still loading the toolbar shows progress, and before it runs the toggle
        // is simply not offered.
        guard self.hasDetectedStars, self.stars.isEmpty, self.isLoading == false
        else
        {
            return nil
        }

        return "Star detection ran on this image but didn’t find any stars."
    }

    /// The on-screen stroke width, kept constant across zoom.
    private static let lineWidth: CGFloat = 1.5

    /// The measurement label's on-screen font size, in points.
    private static let labelFontSize: CGFloat = 11

    /// The on-screen gap between a marker's edge and its measurement label, in
    /// points.
    private static let labelGap: CGFloat = 4

    /// The smallest on-screen marker radius, in points, so a small star at a low
    /// magnification stays visible rather than collapsing to a dot.
    public static let minimumMarkerRadius: CGFloat = 4

    /// The on-screen radius for a star marker: its half-flux radius scaled by the
    /// displayed magnification, but never below ``minimumMarkerRadius``.
    ///
    /// - Parameters:
    ///   - hfr:          The star's half-flux radius, in image pixels.
    ///   - displayScale: On-screen points per image pixel (the effective
    ///                   magnification of the displayed image).
    /// - Returns: The marker radius, in on-screen points.
    public static func markerRadius( hfr: Double, displayScale: CGFloat ) -> CGFloat
    {
        max( Self.minimumMarkerRadius, CGFloat( hfr ) * displayScale )
    }

    /// Maps a source-space star centroid into the displayed (reoriented) image's
    /// pixel space.
    ///
    /// The centroid is in source coordinates; `displayedImageSize` is the size
    /// *after* the orientation is applied. The source dimensions are recovered
    /// from it (a quarter-turn swaps width and height), the centroid is clamped
    /// into range, then mapped forward through the orientation.
    ///
    /// - Parameters:
    ///   - x:                 The star centroid column, in source pixels.
    ///   - y:                 The star centroid row, in source pixels.
    ///   - displayedImageSize: The displayed image's pixel dimensions.
    ///   - orientation:       The orientation applied to the displayed image.
    /// - Returns: The centroid in displayed-image pixel space.
    public static func displayedImagePoint( x: Double, y: Double, displayedImageSize: CGSize, orientation: Processors.Orient.Orientation ) -> CGPoint
    {
        let quarterTurn  = orientation.rotation == .clockwise90 || orientation.rotation == .counterClockwise90
        let sourceWidth  = Int( ( quarterTurn ? displayedImageSize.height : displayedImageSize.width  ).rounded() )
        let sourceHeight = Int( ( quarterTurn ? displayedImageSize.width  : displayedImageSize.height ).rounded() )

        guard sourceWidth > 0, sourceHeight > 0
        else
        {
            return .zero
        }

        let sourceX = min( max( Int( x.rounded() ), 0 ), sourceWidth  - 1 )
        let sourceY = min( max( Int( y.rounded() ), 0 ), sourceHeight - 1 )

        // Forward map a source pixel into the displayed frame: the mirror is
        // applied first (across the source width), then the quarter-turn rotation,
        // matching the renderer's pixel transform so a marker tracks its star.
        let mirroredX = orientation.mirroredHorizontally ? sourceWidth - 1 - sourceX : sourceX

        let display: ( x: Int, y: Int ) = switch orientation.rotation
        {
            case .none:               ( mirroredX, sourceY )
            case .clockwise90:        ( sourceHeight - 1 - sourceY, mirroredX )
            case .rotate180:          ( sourceWidth - 1 - mirroredX, sourceHeight - 1 - sourceY )
            case .counterClockwise90: ( sourceY, sourceWidth - 1 - mirroredX )
            @unknown default:         ( mirroredX, sourceY )
        }

        return CGPoint( x: display.x, y: display.y )
    }

    public func draw( in context: inout GraphicsContext, canvasSize: CGSize, imageSize: CGSize, displayedRect: CGRect )
    {
        guard imageSize.width > 0, imageSize.height > 0
        else
        {
            return
        }

        let scale = CanvasGeometry.displayScale( imageSize: imageSize, displayedRect: displayedRect )

        self.stars.forEach
        {
            star in

            // The centroid is in source coordinates; map it into the displayed
            // (reoriented) frame so the marker tracks the image under rotate/flip.
            let imagePoint = Self.displayedImagePoint( x: star.x, y: star.y, displayedImageSize: imageSize, orientation: self.orientation )
            let center     = CanvasGeometry.viewPoint( forImagePoint: imagePoint, imageSize: imageSize, displayedRect: displayedRect )
            let radius     = Self.markerRadius( hfr: star.hfr, displayScale: scale )
            let circle     = Path( ellipseIn: CGRect( x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2 ) )

            context.stroke( circle, with: .color( self.appearance.primaryColor ), lineWidth: Self.lineWidth )

            // Label the selected measurement to the right of the marker, mirroring
            // the objects overlay so the two read as one annotation style.
            guard let label = self.metric.label( for: star )
            else
            {
                return
            }

            let text = Text( label ).font( .system( size: Self.labelFontSize, weight: .medium ) ).foregroundStyle( self.appearance.primaryColor )

            context.draw( text, at: CGPoint( x: center.x + radius + Self.labelGap, y: center.y ), anchor: .leading )
        }
    }
}
