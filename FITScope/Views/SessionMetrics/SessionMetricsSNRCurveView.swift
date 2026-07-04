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

import Charts
import SwiftUI

/// A compact curve of the session's cumulative relative SNR — how the stacked
/// signal-to-noise grows, versus the chosen reference, as each frame's integration
/// is added.
///
/// Drawn in its own dedicated colour, distinct from the per-frame metrics' rainbow.
/// When there is no integration data yet, a short note stands in for the curve.
struct SessionMetricsSNRCurveView: View
{
    /// The cumulative relative-SNR points, in acquisition order.
    let points: [ SessionMetricSeries.Point ]

    /// The reference the curve is relative to, for the caption (e.g. "1 h").
    let referenceTitle: String

    /// The curve's dedicated colour, kept clear of the metrics' rainbow palette.
    static let color: Color = .teal

    /// The view's content.
    var body: some View
    {
        VStack( alignment: .leading, spacing: 4 )
        {
            Text( "Cumulative SNR vs \( self.referenceTitle )" )
                .font( .system( size: 11, weight: .semibold ) )
                .foregroundStyle( .secondary )

            if self.points.isEmpty
            {
                Text( "No integration data yet." )
                    .font( .system( size: 11 ) )
                    .foregroundStyle( .secondary )
                    .frame( maxWidth: .infinity, maxHeight: .infinity )
            }
            else
            {
                self.chart
            }
        }
        .padding( .horizontal, 16 )
        .padding( .vertical, 10 )
    }

    /// The cumulative relative-SNR line, marked per frame.
    private var chart: some View
    {
        Chart( self.points )
        {
            point in

            LineMark( x: .value( "Frame", point.position ), y: .value( "Relative SNR", point.value ) )
                .foregroundStyle( Self.color )

            PointMark( x: .value( "Frame", point.position ), y: .value( "Relative SNR", point.value ) )
                .foregroundStyle( Self.color )
        }
        .chartXAxisLabel( "Acquisition order" )
        .chartYAxisLabel( "Rel. SNR (×)" )
        .accessibilityIdentifier( AccessibilityIdentifier.SessionMetricsWindowView.snrCurve )
    }
}

#Preview( "Rising" )
{
    SessionMetricsSNRCurveView(
        points: ( 1 ... 8 ).map { SessionMetricSeries.Point( id: UUID(), position: $0, name: "f\( $0 )", value: Double( $0 ).squareRoot() ) },
        referenceTitle: "1 h"
    )
    .frame( width: 640, height: 160 )
}

#Preview( "No data" )
{
    SessionMetricsSNRCurveView( points: [], referenceTitle: "1 h" )
        .frame( width: 640, height: 160 )
}
