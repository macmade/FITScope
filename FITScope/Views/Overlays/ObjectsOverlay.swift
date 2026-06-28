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

/// A canvas overlay that marks each plate-solved catalogue object with a circle
/// and its name, registered to image space.
///
/// The objects come from a successful plate solve (``PlateSolveResult/annotations``),
/// each carrying a position in the solved image's pixel space. Astrometry.net uses
/// the FITS convention — 1-based pixels where pixel `(1, 1)` is the first stored
/// pixel (data row 0). FITScope's pixel pipeline indexes the image the same way
/// and puts data row 0 at the top of the displayed image (it does not flip rows),
/// so each position needs only a 1-based→0-based shift — no y flip — before being
/// mapped through the current ``orientation`` (reusing ``StarsOverlay``'s shared
/// mapping) so the markers track the image as the user rotates or flips it. The
/// overlay gates itself through ``isAvailable``, so its toolbar toggle only appears
/// once a solve has identified at least one object.
public struct ObjectsOverlay: CanvasOverlay
{
    /// The plate-solved objects to mark, in solved-image pixel coordinates.
    private let annotations: [ PlateSolveResult.Annotation ]

    /// The orientation currently applied to the displayed image, used to map the
    /// source-space object positions into the displayed frame.
    private let orientation: Processors.Orient.Orientation

    /// Creates the overlay for the given plate-solved objects.
    ///
    /// - Parameters:
    ///   - annotations: The plate-solved objects, in solved-image pixel
    ///                  coordinates.
    ///   - orientation: The orientation applied to the displayed image.
    public init( annotations: [ PlateSolveResult.Annotation ], orientation: Processors.Orient.Orientation = .identity )
    {
        self.annotations = annotations
        self.orientation = orientation
    }

    /// The overlay's stable identifier, also used by the canvas to recognise the
    /// objects toggle (which it always offers and routes to a plate-solve prompt
    /// when there is nothing to show).
    public static let identifier = "objects"

    public let id              = ObjectsOverlay.identifier
    public let title           = "Plate-Solved Objects"
    public let systemImageName = "tag"

    public var isAvailable: Bool
    {
        self.annotations.isEmpty == false
    }

    /// The marker and label colour.
    private static let color = Color.cyan.opacity( 0.9 )

    /// The on-screen stroke width, kept constant across zoom.
    private static let lineWidth: CGFloat = 1.5

    /// The smallest on-screen marker radius, in points, so a point source (a
    /// zero-radius annotation) or a small object stays visible when zoomed out.
    public static let minimumMarkerRadius: CGFloat = 6

    /// The label's on-screen font size, in points.
    private static let labelFontSize: CGFloat = 11

    /// The on-screen gap between a marker's edge and its label, in points.
    private static let labelGap: CGFloat = 4

    /// The on-screen radius for an object marker: its annotated radius scaled by
    /// the displayed magnification, but never below ``minimumMarkerRadius`` (so a
    /// point source, whose radius is `0`, still shows a visible marker).
    ///
    /// - Parameters:
    ///   - radius:       The object's annotated radius, in image pixels.
    ///   - displayScale: On-screen points per image pixel (the effective
    ///                   magnification of the displayed image).
    /// - Returns: The marker radius, in on-screen points.
    public static func markerRadius( radius: Double, displayScale: CGFloat ) -> CGFloat
    {
        max( Self.minimumMarkerRadius, CGFloat( radius ) * displayScale )
    }

    /// Maps an Astrometry.net pixel position into the displayed (reoriented)
    /// image's pixel space.
    ///
    /// Astrometry's coordinates are 1-based and pixel `(1, 1)` is the first stored
    /// pixel (data row 0). FITScope's pixel space is 0-based with that same first
    /// row at the top (the pipeline does not flip rows), so the only conversion is
    /// 1-based→0-based — there is no y flip. The result is handed to
    /// ``StarsOverlay/displayedImagePoint(x:y:displayedImageSize:orientation:)``,
    /// which applies the orientation and clamps into range, so the mapping matches
    /// the stars overlay exactly.
    ///
    /// - Parameters:
    ///   - pixelX:             The object column, in Astrometry pixel space.
    ///   - pixelY:             The object row, in Astrometry pixel space.
    ///   - displayedImageSize: The displayed image's pixel dimensions.
    ///   - orientation:        The orientation applied to the displayed image.
    /// - Returns: The position in displayed-image pixel space.
    public static func displayedImagePoint( pixelX: Double, pixelY: Double, displayedImageSize: CGSize, orientation: Processors.Orient.Orientation ) -> CGPoint
    {
        StarsOverlay.displayedImagePoint( x: pixelX - 1, y: pixelY - 1, displayedImageSize: displayedImageSize, orientation: orientation )
    }

    public func draw( in context: inout GraphicsContext, canvasSize: CGSize, imageSize: CGSize, displayedRect: CGRect )
    {
        guard imageSize.width > 0, imageSize.height > 0
        else
        {
            return
        }

        let scale = CanvasGeometry.displayScale( imageSize: imageSize, displayedRect: displayedRect )

        self.annotations.forEach
        {
            annotation in

            let imagePoint = Self.displayedImagePoint( pixelX: annotation.pixelX, pixelY: annotation.pixelY, displayedImageSize: imageSize, orientation: self.orientation )
            let center     = CanvasGeometry.viewPoint( forImagePoint: imagePoint, imageSize: imageSize, displayedRect: displayedRect )
            let radius     = Self.markerRadius( radius: annotation.radius, displayScale: scale )
            let circle     = Path( ellipseIn: CGRect( x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2 ) )

            context.stroke( circle, with: .color( Self.color ), lineWidth: Self.lineWidth )

            guard let label = annotation.label
            else
            {
                return
            }

            let text = Text( label ).font( .system( size: Self.labelFontSize, weight: .medium ) ).foregroundStyle( Self.color )

            context.draw( text, at: CGPoint( x: center.x + radius + Self.labelGap, y: center.y ), anchor: .leading )
        }
    }
}
