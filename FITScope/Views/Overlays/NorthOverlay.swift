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

/// A canvas overlay that draws a small north / east compass in the top-right of
/// the viewport, derived from the image's world-coordinate system.
///
/// The direction of north (and east) is recovered from the WCS linear transform:
/// the `CD` matrix when present, otherwise the older `CDELT` + `CROTA2` form. The
/// transform maps pixel offsets to intermediate world coordinates (ξ east, η
/// north); inverting it gives the pixel-space directions of north and east. Those
/// are expressed in FITScope's *source-display* space — column → x (right), row →
/// y (down), with data row 0 at the top — which is the opposite of the
/// conventional bottom-up sky display, so a north-up sky field appears with north
/// pointing *down* until the user flips it.
///
/// Like the scale bar, the compass is anchored to the viewport corner rather than
/// to image space, but its arrows turn with the displayed image: the source-space
/// directions are mapped through the current ``Processors/Orient/Orientation`` so
/// north keeps pointing the right way under rotate and flip. The overlay gates
/// itself through ``isAvailable``, so its toolbar toggle only appears when the WCS
/// yields an orientation.
public struct NorthOverlay: CanvasOverlay
{
    /// The on-screen directions of north and east, as unit vectors in the canvas's
    /// top-left (y-down) coordinate space.
    public struct Compass: Equatable
    {
        /// The on-screen direction of celestial north.
        public let north: CGVector

        /// The on-screen direction of celestial east.
        public let east: CGVector

        /// Creates a compass.
        ///
        /// - Parameters:
        ///   - north: The on-screen direction of north.
        ///   - east:  The on-screen direction of east.
        public init( north: CGVector, east: CGVector )
        {
            self.north = north
            self.east  = east
        }
    }

    /// The on-screen compass for the current WCS and display orientation, or `nil`
    /// when the orientation cannot be determined.
    private let compass: Compass?

    /// Creates the overlay for the given WCS and display orientation.
    ///
    /// - Parameters:
    ///   - wcs:         The world-coordinate system to derive north from, or `nil`
    ///                  when none is available.
    ///   - orientation: The orientation applied to the displayed image, so the
    ///                  compass turns with it. Defaults to the identity.
    public init( wcs: FITSMetadata?, orientation: Processors.Orient.Orientation = .identity )
    {
        self.compass = Self.compass( wcs: wcs, orientation: orientation )
    }

    /// The overlay's stable identifier, also used by the canvas to recognise the
    /// north toggle — which, like the objects toggle, it always offers and routes
    /// to a plate-solve prompt when there is no orientation to show.
    public static let identifier = "north"

    public let id              = NorthOverlay.identifier
    public let title           = "North Indicator"
    public let systemImageName = "location.north.line"

    public var isAvailable: Bool
    {
        self.compass != nil
    }

    // MARK: - WCS derivation

    /// The on-screen compass for a WCS, mapped through a display orientation.
    ///
    /// Derives the source-space directions of north and east from the WCS, then
    /// maps each one through the orientation so they track the displayed image.
    /// Returns `nil` when the WCS yields no usable orientation.
    ///
    /// - Parameters:
    ///   - wcs:         The world-coordinate system, or `nil`.
    ///   - orientation: The orientation applied to the displayed image.
    /// - Returns: The on-screen compass, or `nil` when north is unknown.
    public static func compass( wcs: FITSMetadata?, orientation: Processors.Orient.Orientation ) -> Compass?
    {
        guard let source = Self.sourceCompass( wcs: wcs )
        else
        {
            return nil
        }

        return Compass(
            north: Self.displayedDirection( source.north, orientation: orientation ),
            east:  Self.displayedDirection( source.east,  orientation: orientation )
        )
    }

    /// The directions of north and east in FITScope's source-display pixel space
    /// (column → x right, row → y down), before any display orientation is applied.
    ///
    /// Inverts the WCS linear transform: north is the pixel direction of increasing
    /// declination (η), east the direction of increasing right ascension (ξ). The
    /// vectors are normalised; `nil` is returned when there is no transform or it
    /// is degenerate.
    ///
    /// - Parameter wcs: The world-coordinate system, or `nil`.
    /// - Returns: The source-space compass, or `nil`.
    public static func sourceCompass( wcs: FITSMetadata? ) -> Compass?
    {
        guard let wcs, let cd = WCSProjection.cdMatrix( metadata: wcs )
        else
        {
            return nil
        }

        let determinant = cd.determinant

        guard determinant != 0,
              let north = Self.normalized( CGVector( dx: -cd.cd12 / determinant, dy:  cd.cd11 / determinant ) ),
              let east  = Self.normalized( CGVector( dx:  cd.cd22 / determinant, dy: -cd.cd21 / determinant ) )
        else
        {
            return nil
        }

        return Compass( north: north, east: east )
    }

    /// Maps a source-space direction through a display orientation, so a compass
    /// arrow turns with the image as the user rotates or flips it.
    ///
    /// This is the linear part of the renderer's pixel transform — the horizontal
    /// mirror first, then the quarter-turn rotation — applied to a direction rather
    /// than a point (so the translation drops out), matching how the stars and
    /// objects overlays reorient their positions.
    ///
    /// - Parameters:
    ///   - direction:   The direction in source-display space (y down).
    ///   - orientation: The orientation applied to the displayed image.
    /// - Returns: The direction in the displayed frame.
    public static func displayedDirection( _ direction: CGVector, orientation: Processors.Orient.Orientation ) -> CGVector
    {
        let mirroredX = orientation.mirroredHorizontally ? -direction.dx : direction.dx
        let mirroredY = direction.dy

        switch orientation.rotation
        {
            case .none:               return CGVector( dx: mirroredX,  dy: mirroredY )
            case .clockwise90:        return CGVector( dx: -mirroredY, dy: mirroredX )
            case .rotate180:          return CGVector( dx: -mirroredX, dy: -mirroredY )
            case .counterClockwise90: return CGVector( dx: mirroredY,  dy: -mirroredX )
            @unknown default:         return CGVector( dx: mirroredX,  dy: mirroredY )
        }
    }

    /// The unit vector in the direction of `vector`, or `nil` when it has no
    /// length.
    ///
    /// - Parameter vector: The vector to normalise.
    /// - Returns: The unit vector, or `nil`.
    private static func normalized( _ vector: CGVector ) -> CGVector?
    {
        let length = ( ( vector.dx * vector.dx ) + ( vector.dy * vector.dy ) ).squareRoot()

        guard length > 0
        else
        {
            return nil
        }

        return CGVector( dx: vector.dx / length, dy: vector.dy / length )
    }

    // MARK: - Drawing

    /// The compass colour.
    private static let color = Color.white.opacity( CanvasOverlayStyle.alpha )

    /// The on-screen stroke width.
    private static let lineWidth: CGFloat = 1.5

    /// The length of the north arm, in points.
    private static let northLength: CGFloat = 26

    /// The length of the east arm, in points (shorter, a secondary indicator).
    private static let eastLength: CGFloat = 16

    /// The length of each arrowhead barb, in points.
    private static let headLength: CGFloat = 7

    /// The half-angle of the arrowhead, in radians.
    private static let headAngle: CGFloat = 0.42

    /// The gap between an arm's tip and its label, in points.
    private static let labelGap: CGFloat = 8

    /// The label font size, in points.
    private static let labelFontSize: CGFloat = 11

    /// The inset of the compass centre from the visible image's right edge, in
    /// points. Generous enough to clear the vertical scroller when zoomed in and to
    /// keep the arms and labels within the viewport.
    private static let marginRight: CGFloat = 52

    /// The inset of the compass centre from the visible image's top edge, in
    /// points. Large enough that the centre — and the arms and labels that radiate
    /// up to ``northLength`` plus a label around it in any direction — clears the
    /// floating toolbar band along the top.
    private static let marginTop: CGFloat = 104

    public func draw( in context: inout GraphicsContext, canvasSize: CGSize, imageSize: CGSize, displayedRect: CGRect )
    {
        guard let compass = self.compass
        else
        {
            return
        }

        // Anchor to the visible image's top-right corner (its rectangle clipped to
        // the viewport), matching the scale bar's screen-anchored placement.
        let viewport = CGRect( origin: .zero, size: canvasSize )
        let region   = displayedRect.intersection( viewport )

        guard region.isNull == false, region.width > 0, region.height > 0
        else
        {
            return
        }

        let center = CGPoint( x: region.maxX - Self.marginRight, y: region.minY + Self.marginTop )

        Self.drawArm( in: &context, center: center, direction: compass.east,  length: Self.eastLength,  label: "E", withHead: false )
        Self.drawArm( in: &context, center: center, direction: compass.north, length: Self.northLength, label: "N", withHead: true )
    }

    /// Draws one compass arm: a line from the centre along `direction`, an optional
    /// arrowhead at its tip, and a label beyond the tip.
    ///
    /// - Parameters:
    ///   - context:   The graphics context.
    ///   - center:    The compass centre.
    ///   - direction: The on-screen unit direction of the arm.
    ///   - length:    The arm length, in points.
    ///   - label:     The single-letter label (`N` or `E`).
    ///   - withHead:  Whether to draw an arrowhead at the tip.
    private static func drawArm( in context: inout GraphicsContext, center: CGPoint, direction: CGVector, length: CGFloat, label: String, withHead: Bool )
    {
        let tip = CGPoint( x: center.x + ( direction.dx * length ), y: center.y + ( direction.dy * length ) )

        var path = Path()

        path.move(    to: center )
        path.addLine( to: tip )

        if withHead
        {
            // The barbs point back from the tip, rotated ±headAngle off the reverse
            // direction, forming a symmetric arrowhead.
            let back = CGVector( dx: -direction.dx, dy: -direction.dy )

            let left  = Self.rotated( back, by:  Self.headAngle )
            let right = Self.rotated( back, by: -Self.headAngle )

            path.move(    to: tip )
            path.addLine( to: CGPoint( x: tip.x + ( left.dx  * Self.headLength ), y: tip.y + ( left.dy  * Self.headLength ) ) )
            path.move(    to: tip )
            path.addLine( to: CGPoint( x: tip.x + ( right.dx * Self.headLength ), y: tip.y + ( right.dy * Self.headLength ) ) )
        }

        context.stroke( path, with: .color( Self.color ), lineWidth: Self.lineWidth )

        let labelPoint = CGPoint( x: tip.x + ( direction.dx * Self.labelGap ), y: tip.y + ( direction.dy * Self.labelGap ) )
        let text       = Text( label ).font( .system( size: Self.labelFontSize, weight: .semibold ) ).foregroundStyle( Self.color )

        context.draw( text, at: labelPoint, anchor: .center )
    }

    /// Rotates a vector by an angle, in the canvas's y-down coordinate space.
    ///
    /// - Parameters:
    ///   - vector: The vector to rotate.
    ///   - angle:  The rotation, in radians.
    /// - Returns: The rotated vector.
    private static func rotated( _ vector: CGVector, by angle: CGFloat ) -> CGVector
    {
        let cosine = cos( angle )
        let sine   = sin( angle )

        return CGVector( dx: ( vector.dx * cosine ) - ( vector.dy * sine ), dy: ( vector.dx * sine ) + ( vector.dy * cosine ) )
    }
}
