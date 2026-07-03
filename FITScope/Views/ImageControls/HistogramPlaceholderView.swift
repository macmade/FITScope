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

/// A loading placeholder for the inspector's Histogram section, shown before the
/// first render result is available.
///
/// It is a single dashed-border box spanning the full height of
/// ``HistogramControlView``'s default layout — the mode-picker row, the spacing
/// and the graph box — with a short message centred inside. Occupying that whole
/// height keeps the sections below it from shifting when the real histogram
/// appears, without mocking the picker controls.
public struct HistogramPlaceholderView: View
{
    /// Creates the placeholder.
    public init()
    {}

    /// The view's content.
    public var body: some View
    {
        ZStack
        {
            // Reserves the exact height of HistogramControlView's default layout
            // — the picker row, the inter-row spacing and the graph box — without
            // drawing anything, so the dashed box spans the same space and the
            // sections below do not shift when the real histogram appears.
            VStack( alignment: .leading )
            {
                Text( " " )
                    .font( .system( size: 11 ) )
                    .padding( .vertical, 3 )
                    .padding( 2 )

                Color.clear
                    .frame( height: HistogramControlView.graphHeight )
                    .padding( 6 )
            }
            .frame( maxWidth: .infinity )
            .hidden()

            Text( "Computing histogram\u{2026}" )
                .font( .caption )
                .foregroundStyle( .secondary )
        }
        .overlay( RoundedRectangle( cornerRadius: 10 ).strokeBorder( Color.secondary.opacity( 0.35 ), style: StrokeStyle( lineWidth: 1, dash: [ 5, 4 ] ) ) )
    }
}

#Preview
{
    HistogramPlaceholderView()
        .frame( width: 255 )
        .padding()
}
