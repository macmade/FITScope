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

/// A layout that arranges its subviews left to right, wrapping onto a new line
/// when the next subview would overflow the available width — a "flow" or "tag
/// cloud" of leading-aligned items, used for inline pills.
public struct FlowLayout: Layout
{
    /// The horizontal gap between items on the same line.
    private let horizontalSpacing: CGFloat

    /// The vertical gap between wrapped lines.
    private let verticalSpacing: CGFloat

    /// Creates a flow layout.
    ///
    /// - Parameters:
    ///   - horizontalSpacing: The gap between items on a line. Defaults to `6`.
    ///   - verticalSpacing:   The gap between lines. Defaults to `6`.
    public init( horizontalSpacing: CGFloat = 6, verticalSpacing: CGFloat = 6 )
    {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing   = verticalSpacing
    }

    public func sizeThatFits( proposal: ProposedViewSize, subviews: Subviews, cache: inout Void ) -> CGSize
    {
        let maxWidth = proposal.width ?? .infinity
        let rows     = self.rows( maxWidth: maxWidth, subviews: subviews )

        // Broken into sub-expressions: the single-expression form was too complex
        // for the type-checker to solve in reasonable time.
        let rowWidths = rows.map
        {
            row in

            let itemsWidth   = row.map { $0.size.width }.reduce( 0, + )
            let spacingWidth = CGFloat( max( 0, row.count - 1 ) ) * self.horizontalSpacing

            return itemsWidth + spacingWidth
        }

        let rowHeights    = rows.map { row in row.map { $0.size.height }.max() ?? 0 }
        let spacingHeight = CGFloat( max( 0, rows.count - 1 ) ) * self.verticalSpacing

        let width  = rowWidths.max() ?? 0
        let height = rowHeights.reduce( 0, + ) + spacingHeight

        return CGSize( width: maxWidth.isFinite ? maxWidth : width, height: height )
    }

    public func placeSubviews( in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void )
    {
        let rows = self.rows( maxWidth: bounds.width, subviews: subviews )
        var y    = bounds.minY

        for row in rows
        {
            var x         = bounds.minX
            let rowHeight = row.map { $0.size.height }.max() ?? 0

            for item in row
            {
                item.subview.place( at: CGPoint( x: x, y: y ), anchor: .topLeading, proposal: ProposedViewSize( item.size ) )

                x += item.size.width + self.horizontalSpacing
            }

            y += rowHeight + self.verticalSpacing
        }
    }

    /// A subview paired with its measured size.
    private struct Item
    {
        let subview: LayoutSubview
        let size:    CGSize
    }

    /// Groups the subviews into rows that each fit within `maxWidth`.
    ///
    /// - Parameters:
    ///   - maxWidth: The available width to wrap within.
    ///   - subviews: The subviews to lay out.
    /// - Returns: The rows of items, in order.
    private func rows( maxWidth: CGFloat, subviews: Subviews ) -> [ [ Item ] ]
    {
        var rows: [ [ Item ] ] = [ [] ]
        var rowWidth: CGFloat  = 0

        for subview in subviews
        {
            let size = subview.sizeThatFits( .unspecified )

            if rows[ rows.count - 1 ].isEmpty == false, rowWidth + self.horizontalSpacing + size.width > maxWidth
            {
                rows.append( [] )

                rowWidth = 0
            }

            let spacing = rows[ rows.count - 1 ].isEmpty ? 0 : self.horizontalSpacing

            rows[ rows.count - 1 ].append( Item( subview: subview, size: size ) )

            rowWidth += spacing + size.width
        }

        return rows
    }
}
