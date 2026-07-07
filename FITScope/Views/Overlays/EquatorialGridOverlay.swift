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

import SwiftPixel
import SwiftUI

/// A canvas overlay that draws an equatorial (RA/Dec) coordinate grid over the
/// image, registered to image space through the WCS.
///
/// Grid lines are generated in sky coordinates — meridians of constant right
/// ascension and parallels of constant declination — and each is projected to
/// the image with ``WCSProjection`` (the gnomonic TAN projection), so a line
/// follows the field's curvature rather than being a straight screen segment. The
/// projected source-space points are mapped through the current display
/// ``Processors/Orient/Orientation`` (so the grid tracks the image under rotate
/// and flip) and clipped to the image bounds. Line spacing snaps to a nice
/// sexagesimal step sized to the field, and each line is labelled in the
/// astronomy convention: RA in hours and minutes, Dec in degrees and arcminutes.
///
/// The overlay gates itself through ``isAvailable``, so its toolbar toggle only
/// appears when a WCS projection can be built.
public struct EquatorialGridOverlay: CanvasOverlay
{
    /// The projection between sky coordinates and source pixels, or `nil` when the
    /// WCS is missing or insufficient.
    private let projection: WCSProjection?

    /// The orientation applied to the displayed image, used to map the projected
    /// source-space points into the displayed frame.
    private let orientation: Processors.Orient.Orientation

    /// The action performed when the toggle is tapped with no WCS to project —
    /// proposing a plate solve — wired by the host when the overlay is built.
    public let onUnavailableTap: ( () -> Void )?

    /// The grid's appearance — its colour and the two opacity tiers (labels and
    /// the fainter lines).
    private let appearance: OverlayAppearance

    /// Creates the overlay for the given WCS and display orientation.
    ///
    /// - Parameters:
    ///   - wcs:              The world-coordinate system to project through, or `nil`.
    ///   - orientation:      The orientation applied to the displayed image. Defaults
    ///                       to the identity.
    ///   - onUnavailableTap: The action to run when tapped with nothing to show.
    ///                       Defaults to `nil`.
    ///   - appearance:       The grid's colour and its label/line opacities. Defaults
    ///                       to ``EquatorialGridOverlay/defaultAppearance``.
    public init( wcs: WorldCoordinateSystem?, orientation: Processors.Orient.Orientation = .identity, onUnavailableTap: ( () -> Void )? = nil, appearance: OverlayAppearance = EquatorialGridOverlay.defaultAppearance )
    {
        self.projection       = wcs.flatMap { WCSProjection( $0 ) }
        self.orientation      = orientation
        self.onUnavailableTap = onUnavailableTap
        self.appearance       = appearance
    }

    /// The overlay's stable identifier, also used by the canvas to recognise the
    /// grid toggle — which, like the objects and north toggles, it always offers and
    /// routes to a plate-solve prompt when there is no WCS to project.
    public static let identifier = "grid"

    /// The grid's default appearance — white, with labels at the shared primary
    /// alpha and the fainter lines at the shared secondary alpha.
    public static let defaultAppearance = OverlayAppearance( color: .white, opacity: CanvasOverlayStyle.alpha, secondaryOpacity: CanvasOverlayStyle.secondaryAlpha )

    /// The grid exposes two opacity tiers — unlike the single-tier overlays — so it
    /// declares both channels itself: its brighter labels and its fainter lines.
    public static var opacityChannels: [ OverlayOpacityChannel ]
    {
        [
            OverlayOpacityChannel( label: "Labels", keyPath: \OverlayAppearance.opacity ),
            OverlayOpacityChannel( label: "Lines",  keyPath: \OverlayAppearance.secondaryOpacity ),
        ]
    }

    public let id              = EquatorialGridOverlay.identifier
    public let title           = "Equatorial Grid"
    public let systemImageName = "grid"

    public var isAvailable: Bool
    {
        self.projection != nil
    }

    // MARK: - Grid sizing & labelling

    /// The approximate number of grid lines to draw across each axis; the step is
    /// chosen so the field shows around this many lines.
    private static let targetLineCount = 6

    /// The number of segments each grid line is sampled into, so a projected line
    /// follows the field's curvature smoothly.
    private static let segmentCount = 48

    /// The number of points sampled along each image edge when estimating the
    /// field's sky bounds.
    private static let boundarySampleCount = 16

    /// The candidate declination steps, in degrees: 1′, 2′, 5′, 10′, 15′, 30′, 1°,
    /// 2°, 5°, 10°, 20°, 30°.
    private static let decCandidatesDegrees: [ Double ] = [ 1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 1200, 1800 ].map { $0 / 60 }

    /// The candidate right-ascension steps, in degrees, derived from nice steps in
    /// time: 1ˢ, 2ˢ, 5ˢ, 10ˢ, 15ˢ, 30ˢ, 1ᵐ, 2ᵐ, 5ᵐ, 10ᵐ, 15ᵐ, 30ᵐ, 1ʰ, 2ʰ, 3ʰ
    /// (one second of time spans 1/240 of a degree).
    private static let raCandidatesDegrees: [ Double ] = [ 1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900, 1800, 3600, 7200, 10800 ].map { $0 / 240 }

    /// The smallest candidate step that keeps the number of lines across `span`
    /// within `targetCount`, i.e. the smallest candidate at least `span /
    /// targetCount`; the largest candidate when even that overflows, or `nil` for a
    /// non-positive span.
    ///
    /// - Parameters:
    ///   - span:        The field span the lines must cover, in degrees.
    ///   - candidates:  The allowed step sizes, in the same unit as `span`.
    ///   - targetCount: The desired maximum number of intervals.
    /// - Returns: The chosen step, or `nil`.
    public static func niceStep( span: Double, candidates: [ Double ], targetCount: Int ) -> Double?
    {
        guard span > 0, targetCount > 0, candidates.isEmpty == false
        else
        {
            return nil
        }

        let sorted  = candidates.sorted()
        let minimum = span / Double( targetCount )

        return sorted.first { $0 >= minimum } ?? sorted.last
    }

    /// Formats a right ascension in sexagesimal time, at a precision matching the
    /// grid step: whole hours for a step of an hour or more, hours and minutes for
    /// a step of a minute or more, otherwise hours, minutes, and seconds.
    ///
    /// - Parameters:
    ///   - degrees:     The right ascension, in degrees.
    ///   - stepDegrees: The grid step, in degrees, which sets the precision.
    /// - Returns: The formatted label, e.g. `5h 35m`.
    public static func formatRA( degrees: Double, stepDegrees: Double ) -> String
    {
        // One second of time spans 1/240 of a degree; work in seconds of time,
        // wrapped into a full day.
        let stepSeconds   = stepDegrees * 240
        let totalSeconds  = ( degrees * 240 ).truncatingRemainder( dividingBy: 86400 )
        let normalized    = totalSeconds < 0 ? totalSeconds + 86400 : totalSeconds

        if stepSeconds >= 3600
        {
            let hours = Int( ( normalized / 3600 ).rounded() ) % 24

            return "\( hours )h"
        }

        if stepSeconds >= 60
        {
            let totalMinutes = Int( ( normalized / 60 ).rounded() )
            let hours        = ( totalMinutes / 60 ) % 24
            let minutes      = totalMinutes % 60

            return "\( hours )h \( Self.padded( minutes ) )m"
        }

        let seconds = Int( normalized.rounded() )
        let hours   = ( seconds / 3600 ) % 24
        let minutes = ( seconds % 3600 ) / 60
        let rest    = seconds % 60

        return "\( hours )h \( Self.padded( minutes ) )m \( Self.padded( rest ) )s"
    }

    /// Formats a declination in sexagesimal degrees, at a precision matching the
    /// grid step: whole degrees for a step of a degree or more, degrees and
    /// arcminutes for a step of an arcminute or more, otherwise degrees,
    /// arcminutes, and arcseconds. The sign is always shown.
    ///
    /// - Parameters:
    ///   - degrees:     The declination, in degrees.
    ///   - stepDegrees: The grid step, in degrees, which sets the precision.
    /// - Returns: The formatted label, e.g. `-5°24′`.
    public static func formatDec( degrees: Double, stepDegrees: Double ) -> String
    {
        let stepArcseconds = stepDegrees * 3600
        let sign           = degrees < 0 ? "-" : "+"
        let magnitude      = abs( degrees )

        if stepArcseconds >= 3600
        {
            return "\( sign )\( Int( magnitude.rounded() ) )°"
        }

        if stepArcseconds >= 60
        {
            let totalArcminutes = Int( ( magnitude * 60 ).rounded() )
            let wholeDegrees    = totalArcminutes / 60
            let arcminutes      = totalArcminutes % 60

            return "\( sign )\( wholeDegrees )°\( Self.padded( arcminutes ) )′"
        }

        let totalArcseconds = Int( ( magnitude * 3600 ).rounded() )
        let wholeDegrees    = totalArcseconds / 3600
        let arcminutes      = ( totalArcseconds % 3600 ) / 60
        let arcseconds      = totalArcseconds % 60

        return "\( sign )\( wholeDegrees )°\( Self.padded( arcminutes ) )′\( Self.padded( arcseconds ) )″"
    }

    /// A non-negative integer formatted as at least two digits.
    ///
    /// - Parameter value: The value to pad.
    /// - Returns: The zero-padded string.
    private static func padded( _ value: Int ) -> String
    {
        String( format: "%02d", value )
    }

    // MARK: - Drawing

    /// The on-screen stroke width, kept constant across zoom.
    private static let lineWidth: CGFloat = 0.75

    /// The label font size, in points.
    private static let labelFontSize: CGFloat = 10

    /// The on-screen offset of a label from its anchor point, in points.
    private static let labelOffset: CGFloat = 4

    /// The inset of the label gutter from the visible image's left edge, in points.
    private static let labelInsetLeft: CGFloat = 12

    /// The inset of the label baseline from the visible image's top edge, in points.
    /// Large enough to keep the top of the label gutter clear of the floating
    /// toolbar band.
    private static let labelInsetTop: CGFloat = 56

    /// The inset of the label baseline from the visible image's bottom edge, in
    /// points, leaving room for the floating status bar and scale bar.
    private static let labelInsetBottom: CGFloat = 60

    /// The gap kept between the bottom of the declination gutter and the
    /// right-ascension baseline, so a declination label near the bottom never
    /// collides with the row of right-ascension labels.
    private static let labelBaselineGap: CGFloat = 22

    /// Which screen edge a line's label is aligned to.
    private enum LabelAnchor
    {
        /// The label sits in the left gutter, aligned vertically with the parallel
        /// (declination lines).
        case left

        /// The label sits on the bottom baseline, aligned horizontally with the
        /// meridian (right-ascension lines).
        case bottom
    }

    /// The screen region labels are aligned into: a fixed left gutter x for the
    /// declination labels, a fixed bottom baseline y for the right-ascension labels,
    /// and the bounds each label is clamped within (which exclude the toolbar band).
    private struct LabelFrame
    {
        let gutterX:   CGFloat
        let baselineY: CGFloat
        let minX:      CGFloat
        let maxX:      CGFloat
        let minY:      CGFloat
        let maxY:      CGFloat
    }

    /// The field's sky bounds, expressed as a declination range and a right-ascension
    /// range relative to the reference RA (so the range is continuous across the
    /// 0°/360° wrap).
    private struct FieldBounds
    {
        let minDec:        Double
        let maxDec:        Double
        let minRARelative: Double
        let maxRARelative: Double
    }

    public func draw( in context: inout GraphicsContext, canvasSize: CGSize, imageSize: CGSize, displayedRect: CGRect )
    {
        guard let projection = self.projection, imageSize.width > 0, imageSize.height > 0
        else
        {
            return
        }

        let viewport = CGRect( origin: .zero, size: canvasSize )
        let region   = displayedRect.intersection( viewport )

        guard region.isNull == false, region.width > 0, region.height > 0
        else
        {
            return
        }

        let sourceSize = Self.sourceSize( displayedSize: imageSize, orientation: self.orientation )

        guard let bounds  = Self.fieldBounds( projection: projection, sourceSize: sourceSize ),
              let decStep = Self.niceStep( span: bounds.maxDec - bounds.minDec, candidates: Self.decCandidatesDegrees, targetCount: Self.targetLineCount ),
              let raStep  = Self.niceStep( span: bounds.maxRARelative - bounds.minRARelative, candidates: Self.raCandidatesDegrees, targetCount: Self.targetLineCount )
        else
        {
            return
        }

        let raSampleStep  = ( bounds.maxRARelative - bounds.minRARelative ) / Double( Self.segmentCount )
        let decSampleStep = ( bounds.maxDec - bounds.minDec ) / Double( Self.segmentCount )

        // The gutter / baseline labels align into, clamped clear of the toolbar
        // (top), the status & scale bars (bottom), and the edges (sides). The
        // declination gutter (minY...maxY) stops a gap short of the right-ascension
        // baseline so the two label sets never collide in the bottom-left corner.
        let baselineY = region.maxY - Self.labelInsetBottom
        let frame     = LabelFrame(
            gutterX:   region.minX + Self.labelInsetLeft,
            baselineY: baselineY,
            minX:      region.minX + Self.labelInsetLeft,
            maxX:      region.maxX - Self.labelInsetLeft,
            minY:      region.minY + Self.labelInsetTop,
            maxY:      baselineY - Self.labelBaselineGap
        )

        // Parallels: constant declination, sampled across the RA range.
        let firstDec = ( bounds.minDec / decStep ).rounded( .up ) * decStep

        stride( from: firstDec, through: bounds.maxDec, by: decStep ).forEach
        {
            dec in

            let skyPoints = stride( from: bounds.minRARelative, through: bounds.maxRARelative, by: raSampleStep ).map
            {
                ( ra: projection.referenceRA + $0, dec: dec )
            }

            Self.drawLine( in: &context, skyPoints: skyPoints, projection: projection, sourceSize: sourceSize, orientation: self.orientation, imageSize: imageSize, displayedRect: displayedRect, label: Self.formatDec( degrees: dec, stepDegrees: decStep ), anchor: .left, frame: frame, lineColor: self.appearance.secondaryColor, labelColor: self.appearance.primaryColor )
        }

        // Meridians: constant right ascension, sampled across the Dec range.
        let firstRA = ( bounds.minRARelative / raStep ).rounded( .up ) * raStep

        stride( from: firstRA, through: bounds.maxRARelative, by: raStep ).forEach
        {
            raRelative in

            let ra        = projection.referenceRA + raRelative
            let skyPoints = stride( from: bounds.minDec, through: bounds.maxDec, by: decSampleStep ).map
            {
                ( ra: ra, dec: $0 )
            }

            Self.drawLine( in: &context, skyPoints: skyPoints, projection: projection, sourceSize: sourceSize, orientation: self.orientation, imageSize: imageSize, displayedRect: displayedRect, label: Self.formatRA( degrees: ra, stepDegrees: raStep ), anchor: .bottom, frame: frame, lineColor: self.appearance.secondaryColor, labelColor: self.appearance.primaryColor )
        }
    }

    /// Strokes one grid line and draws its label, aligned into the label frame.
    ///
    /// Each sky sample is projected to a source pixel, dropped if it falls outside
    /// the image (so the line is clipped to the frame), mapped through the display
    /// orientation, and converted to a view point. The polyline breaks wherever a
    /// sample is dropped. The label is then aligned to a shared gutter / baseline:
    /// a declination label sits in the left gutter at the height the parallel
    /// crosses it; a right-ascension label sits on the bottom baseline at the column
    /// the meridian crosses it. A line that does not cross its gutter / baseline is
    /// left unlabelled.
    ///
    /// - Parameters:
    ///   - context:       The graphics context.
    ///   - skyPoints:     The sky samples along the line.
    ///   - projection:    The sky-to-pixel projection.
    ///   - sourceSize:    The source image's pixel dimensions.
    ///   - orientation:   The orientation applied to the displayed image.
    ///   - imageSize:     The displayed image's pixel dimensions.
    ///   - displayedRect: The on-screen rectangle the image occupies.
    ///   - label:         The line's label.
    ///   - anchor:        Which shared edge the label aligns to.
    ///   - frame:         The gutter / baseline and clamp bounds labels align into.
    ///   - lineColor:     The colour for the grid line (the fainter secondary tier).
    ///   - labelColor:    The colour for the label (the brighter primary tier).
    private static func drawLine( in context: inout GraphicsContext, skyPoints: [ ( ra: Double, dec: Double ) ], projection: WCSProjection, sourceSize: CGSize, orientation: Processors.Orient.Orientation, imageSize: CGSize, displayedRect: CGRect, label: String, anchor: LabelAnchor, frame: LabelFrame, lineColor: Color, labelColor: Color )
    {
        var path    = Path()
        var started = false
        var points  = [ CGPoint ]()

        skyPoints.forEach
        {
            sky in

            guard let source = projection.sourcePixel( ra: sky.ra, dec: sky.dec ),
                  source.x >= 0, source.x <= sourceSize.width, source.y >= 0, source.y <= sourceSize.height
            else
            {
                started = false

                return
            }

            let displayed = Self.displayedPoint( sourceX: source.x, sourceY: source.y, sourceSize: sourceSize, orientation: orientation )
            let view      = CanvasGeometry.viewPoint( forImagePoint: displayed, imageSize: imageSize, displayedRect: displayedRect )

            if started
            {
                path.addLine( to: view )
            }
            else
            {
                path.move( to: view )

                started = true
            }

            points.append( view )
        }

        context.stroke( path, with: .color( lineColor ), lineWidth: Self.lineWidth )

        guard label.isEmpty == false, let position = Self.labelPosition( points: points, anchor: anchor, frame: frame )
        else
        {
            return
        }

        let text = Text( label ).font( .system( size: Self.labelFontSize, weight: .medium ) ).foregroundStyle( labelColor )

        switch anchor
        {
            case .left:   context.draw( text, at: CGPoint( x: position.x + Self.labelOffset, y: position.y ), anchor: .leading )
            case .bottom: context.draw( text, at: position, anchor: .center )
        }
    }

    /// The aligned label position for a line, or `nil` when the line does not cross
    /// the shared gutter / baseline (so it should be left unlabelled).
    ///
    /// A declination label aligns to the gutter x at the height the parallel crosses
    /// it; a right-ascension label aligns to the baseline y at the column the
    /// meridian crosses it. The free coordinate is taken from the line's nearest
    /// point and clamped within the frame.
    ///
    /// - Parameters:
    ///   - points: The line's on-screen points.
    ///   - anchor: The shared edge the label aligns to.
    ///   - frame:  The gutter / baseline and clamp bounds.
    /// - Returns: The label position, or `nil`.
    private static func labelPosition( points: [ CGPoint ], anchor: LabelAnchor, frame: LabelFrame ) -> CGPoint?
    {
        switch anchor
        {
            case .left:

                guard points.contains( where: { $0.x <= frame.gutterX } ), points.contains( where: { $0.x >= frame.gutterX } ),
                      let nearest = points.min( by: { abs( $0.x - frame.gutterX ) < abs( $1.x - frame.gutterX ) } )
                else
                {
                    return nil
                }

                return CGPoint( x: frame.gutterX, y: CanvasGeometry.clamp( nearest.y, min: frame.minY, max: frame.maxY ) )

            case .bottom:

                guard points.contains( where: { $0.y <= frame.baselineY } ), points.contains( where: { $0.y >= frame.baselineY } ),
                      let nearest = points.min( by: { abs( $0.y - frame.baselineY ) < abs( $1.y - frame.baselineY ) } )
                else
                {
                    return nil
                }

                return CGPoint( x: CanvasGeometry.clamp( nearest.x, min: frame.minX, max: frame.maxX ), y: frame.baselineY )
        }
    }

    /// The field's sky bounds, estimated by deprojecting points sampled along the
    /// four image edges (so a curved field's extremes are captured). The RA range
    /// is measured relative to the reference RA so it stays continuous across the
    /// 0°/360° wrap.
    ///
    /// - Parameters:
    ///   - projection: The sky-to-pixel projection.
    ///   - sourceSize: The source image's pixel dimensions.
    /// - Returns: The field bounds, or `nil` for a degenerate image.
    private static func fieldBounds( projection: WCSProjection, sourceSize: CGSize ) -> FieldBounds?
    {
        let width  = Double( sourceSize.width )
        let height = Double( sourceSize.height )

        guard width > 0, height > 0
        else
        {
            return nil
        }

        let edges = stride( from: 0.0, through: 1.0, by: 1.0 / Double( Self.boundarySampleCount ) ).flatMap
        {
            t -> [ ( x: Double, y: Double ) ] in

            [ ( t * width, 0 ), ( t * width, height ), ( 0, t * height ), ( width, t * height ) ]
        }

        let skies      = edges.map { projection.sky( forSourceX: $0.x, y: $0.y ) }
        let decs       = skies.map { $0.dec }
        let relativeRA = skies.map { Self.relativeRA( $0.ra - projection.referenceRA ) }

        guard let minDec = decs.min(), let maxDec = decs.max(), let minRA = relativeRA.min(), let maxRA = relativeRA.max()
        else
        {
            return nil
        }

        return FieldBounds( minDec: minDec, maxDec: maxDec, minRARelative: minRA, maxRARelative: maxRA )
    }

    /// An RA difference wrapped into `-180...180`, so a field straddling 0°/360° has
    /// a continuous range.
    ///
    /// - Parameter delta: The RA difference, in degrees.
    /// - Returns: The wrapped difference.
    private static func relativeRA( _ delta: Double ) -> Double
    {
        let wrapped = delta.truncatingRemainder( dividingBy: 360 )

        if wrapped > 180
        {
            return wrapped - 360
        }

        if wrapped < -180
        {
            return wrapped + 360
        }

        return wrapped
    }

    /// The source image's pixel dimensions for a displayed size and orientation (a
    /// quarter-turn swaps width and height).
    ///
    /// - Parameters:
    ///   - displayedSize: The displayed image's dimensions.
    ///   - orientation:   The orientation applied to the displayed image.
    /// - Returns: The source dimensions.
    private static func sourceSize( displayedSize: CGSize, orientation: Processors.Orient.Orientation ) -> CGSize
    {
        let quarterTurn = orientation.rotation == .clockwise90 || orientation.rotation == .counterClockwise90

        return quarterTurn ? CGSize( width: displayedSize.height, height: displayedSize.width ) : displayedSize
    }

    /// Maps a continuous source-space point into the displayed (reoriented) image's
    /// pixel space — the mirror first, then the quarter-turn rotation — matching the
    /// stars and objects overlays' point mapping.
    ///
    /// - Parameters:
    ///   - sourceX:     The source column.
    ///   - sourceY:     The source row.
    ///   - sourceSize:  The source image's pixel dimensions.
    ///   - orientation: The orientation applied to the displayed image.
    /// - Returns: The point in displayed-image pixel space.
    private static func displayedPoint( sourceX: Double, sourceY: Double, sourceSize: CGSize, orientation: Processors.Orient.Orientation ) -> CGPoint
    {
        let mirroredX = orientation.mirroredHorizontally ? sourceSize.width - sourceX : sourceX

        switch orientation.rotation
        {
            case .none:               return CGPoint( x: mirroredX,                      y: sourceY )
            case .clockwise90:        return CGPoint( x: sourceSize.height - sourceY,    y: mirroredX )
            case .rotate180:          return CGPoint( x: sourceSize.width - mirroredX,   y: sourceSize.height - sourceY )
            case .counterClockwise90: return CGPoint( x: sourceY,                        y: sourceSize.width - mirroredX )
            @unknown default:         return CGPoint( x: mirroredX,                      y: sourceY )
        }
    }
}
