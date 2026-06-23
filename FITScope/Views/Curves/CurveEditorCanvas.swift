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

/// An interactive tone-curve editor: the curve is drawn over a grid, and the
/// user edits its control points directly.
///
/// - Drag on empty space to add a control point and drag it.
/// - Drag an existing point to move it (the end points are locked to `x = 0`
///   and `x = 1`; interior points stay ordered between their neighbours).
/// - Drag a point off the chart to remove it (end points cannot be removed).
///
/// The drawn curve is the exact monotone-cubic interpolation the
/// ``Processors/Curves`` processor applies, so the editor previews the real
/// result. Every change calls ``onChange`` so the owner can commit and re-render.
struct CurveEditorCanvas: View
{
    /// The hit/centre radius, in points, for grabbing a control point and for
    /// drawing the point markers.
    private static let hitRadius: CGFloat = 16

    /// The marker radius drawn for each control point.
    private static let markerRadius: CGFloat = 5

    /// The minimum `x` gap kept between an interior point and its neighbours, so
    /// control points never coincide (the processor requires increasing `x`).
    private static let minimumGap = 0.02

    /// How far outside the chart (in points) a point must be released to be
    /// removed.
    private static let removalMargin: CGFloat = 28

    /// The control points being edited, ordered by increasing `x` with the end
    /// points fixed at `x = 0` and `x = 1`.
    @Binding var points: [ Processors.Curves.Point ]

    /// The colour the curve is drawn in (tinted per channel).
    let tint: Color

    /// Called after any change to the points, so the owner can commit + re-render.
    let onChange: () -> Void

    /// The index of the point currently being dragged, or `nil`.
    @State private var draggingIndex: Int?

    /// The view's content.
    var body: some View
    {
        GeometryReader
        {
            geometry in

            let size = geometry.size

            Canvas
            {
                context, _ in

                self.draw( in: &context, size: size )
            }
            .contentShape( Rectangle() )
            .gesture( self.drag( in: size ) )
        }
        .background( Color.black.opacity( 0.35 ) )
        .clipShape( RoundedRectangle( cornerRadius: 10 ) )
        .overlay( RoundedRectangle( cornerRadius: 10 ).strokeBorder( .white.opacity( 0.08 ), lineWidth: 1 ) )
        .accessibilityIdentifier( AccessibilityIdentifier.CurvesWindowView.canvas )
    }

    // MARK: - Drawing

    /// Draws the grid, the identity reference, the interpolated curve and the
    /// control-point markers.
    private func draw( in context: inout GraphicsContext, size: CGSize )
    {
        let divisions = 4

        // Grid.
        var grid = Path()

        for step in 0 ... divisions
        {
            let x = size.width  * CGFloat( step ) / CGFloat( divisions )
            let y = size.height * CGFloat( step ) / CGFloat( divisions )

            grid.move( to: CGPoint( x: x, y: 0 ) )
            grid.addLine( to: CGPoint( x: x, y: size.height ) )
            grid.move( to: CGPoint( x: 0, y: y ) )
            grid.addLine( to: CGPoint( x: size.width, y: y ) )
        }

        context.stroke( grid, with: .color( .white.opacity( 0.08 ) ), lineWidth: 1 )

        // Identity reference (bottom-left to top-right).
        var identity = Path()

        identity.move( to: CGPoint( x: 0, y: size.height ) )
        identity.addLine( to: CGPoint( x: size.width, y: 0 ) )

        context.stroke( identity, with: .color( .white.opacity( 0.12 ) ), style: StrokeStyle( lineWidth: 1, dash: [ 4, 4 ] ) )

        // The interpolated curve, sampled across the width.
        let curve   = Processors.Curves.Curve( points: self.points )
        let samples  = max( 2, Int( size.width ) )
        var curvePath = Path()

        for step in 0 ... samples
        {
            let x     = Double( step ) / Double( samples )
            let y     = curve.value( at: x )
            let point = self.canvasPoint( x: x, y: y, size: size )

            if step == 0
            {
                curvePath.move( to: point )
            }
            else
            {
                curvePath.addLine( to: point )
            }
        }

        context.stroke( curvePath, with: .color( self.tint ), lineWidth: 2 )

        // Control-point markers.
        for point in self.points
        {
            let centre = self.canvasPoint( x: point.x, y: point.y, size: size )
            let rect   = CGRect( x: centre.x - Self.markerRadius, y: centre.y - Self.markerRadius, width: Self.markerRadius * 2, height: Self.markerRadius * 2 )

            context.fill( Path( ellipseIn: rect ), with: .color( self.tint ) )
            context.stroke( Path( ellipseIn: rect ), with: .color( .black.opacity( 0.6 ) ), lineWidth: 1 )
        }
    }

    // MARK: - Gesture

    /// The drag gesture handling add, move and remove.
    private func drag( in size: CGSize ) -> some Gesture
    {
        DragGesture( minimumDistance: 0 )
            .onChanged
            {
                value in

                if self.draggingIndex == nil
                {
                    self.draggingIndex = self.beginDrag( at: value.startLocation, size: size )
                }

                guard let index = self.draggingIndex
                else
                {
                    return
                }

                self.movePoint( at: index, to: value.location, size: size )

                self.onChange()
            }
            .onEnded
            {
                value in

                if let index = self.draggingIndex, self.isOutside( value.location, size: size )
                {
                    self.removePoint( at: index )
                }

                self.draggingIndex = nil

                self.onChange()
            }
    }

    /// Resolves what a drag starting at `location` acts on: an existing point
    /// within the hit radius, otherwise a freshly inserted interior point.
    ///
    /// - Returns: The index of the point to drag, or `nil` if none could be made.
    private func beginDrag( at location: CGPoint, size: CGSize ) -> Int?
    {
        if let nearest = self.nearestPoint( to: location, size: size, indices: Array( self.points.indices ) ), nearest.distance <= Self.hitRadius
        {
            return nearest.index
        }

        return self.insertPoint( at: location, size: size )
    }

    /// Inserts a new interior control point at the dragged location, keeping the
    /// points ordered by `x`.
    ///
    /// - Returns: The index of the inserted point, or `nil` if it cannot fit.
    private func insertPoint( at location: CGPoint, size: CGSize ) -> Int?
    {
        guard let first = self.points.first, let last = self.points.last
        else
        {
            return nil
        }

        let value = self.value( at: location, size: size )
        let x      = min( last.x - Self.minimumGap, max( first.x + Self.minimumGap, value.x ) )

        guard x > first.x, x < last.x
        else
        {
            return nil
        }

        let index = self.points.firstIndex { $0.x > x } ?? self.points.count - 1

        self.points.insert( .init( x: x, y: value.y ), at: index )

        return index
    }

    /// Moves the point at `index` to `location`, locking the end points in `x`
    /// and keeping interior points ordered between their neighbours.
    private func movePoint( at index: Int, to location: CGPoint, size: CGSize )
    {
        guard self.points.indices.contains( index )
        else
        {
            return
        }

        let value = self.value( at: location, size: size )
        let x: Double

        if index == 0
        {
            x = 0
        }
        else if index == self.points.count - 1
        {
            x = 1
        }
        else
        {
            x = min( self.points[ index + 1 ].x - Self.minimumGap, max( self.points[ index - 1 ].x + Self.minimumGap, value.x ) )
        }

        self.points[ index ] = .init( x: x, y: value.y )
    }

    /// Removes the point at `index`, unless it is an end point.
    private func removePoint( at index: Int )
    {
        guard self.points.count > 2, index > 0, index < self.points.count - 1
        else
        {
            return
        }

        self.points.remove( at: index )
    }

    /// The nearest control point to `location` among `indices`, with its distance.
    private func nearestPoint( to location: CGPoint, size: CGSize, indices: [ Int ] ) -> ( index: Int, distance: CGFloat )?
    {
        indices
            .map { ( index: $0, distance: self.distance( from: location, to: self.points[ $0 ], size: size ) ) }
            .min { $0.distance < $1.distance }
    }

    /// The distance from a canvas location to a control point's marker.
    private func distance( from location: CGPoint, to point: Processors.Curves.Point, size: CGSize ) -> CGFloat
    {
        let centre = self.canvasPoint( x: point.x, y: point.y, size: size )

        return hypot( centre.x - location.x, centre.y - location.y )
    }

    /// Whether a location lies far enough outside the chart to remove a point.
    private func isOutside( _ location: CGPoint, size: CGSize ) -> Bool
    {
        location.x < -Self.removalMargin
            || location.x > size.width + Self.removalMargin
            || location.y < -Self.removalMargin
            || location.y > size.height + Self.removalMargin
    }

    // MARK: - Coordinate mapping

    /// Maps a curve coordinate (`x`, `y` in `0...1`) to a canvas point (origin
    /// top-left, `y` increasing downward).
    private func canvasPoint( x: Double, y: Double, size: CGSize ) -> CGPoint
    {
        CGPoint( x: CGFloat( x ) * size.width, y: ( 1 - CGFloat( y ) ) * size.height )
    }

    /// Maps a canvas location to a clamped curve coordinate.
    private func value( at location: CGPoint, size: CGSize ) -> ( x: Double, y: Double )
    {
        let x = size.width  > 0 ? Double( location.x / size.width ) : 0
        let y = size.height > 0 ? Double( 1 - location.y / size.height ) : 0

        return ( min( 1, max( 0, x ) ), min( 1, max( 0, y ) ) )
    }
}
