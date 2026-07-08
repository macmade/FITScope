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

/// Plots a one-dimensional ``GraphSeries`` as a line chart, filling the detail
/// region in place of the image canvas for a `NAXIS=1` FITS file (a spectrum, a
/// light curve). One `LineMark` series over the samples, its axes labelled from the
/// series (physical when the source carries a coordinate scaling, otherwise the
/// sample number).
///
/// Rendered on the same black field the image canvas uses, with a dark colour
/// scheme forced so the axes stay legible whatever the window's appearance.
public struct GraphView: View
{
    /// The decoded series to plot.
    private let series: GraphSeries

    /// Creates the graph view.
    ///
    /// - Parameter series: The one-dimensional series to plot.
    public init( series: GraphSeries )
    {
        self.series = series
    }

    /// The view's content.
    public var body: some View
    {
        Group
        {
            if self.series.isEmpty
            {
                StatusMessageView( systemImage: "chart.xyaxis.line", title: "No Data", message: "This file's data set is empty." )
            }
            else
            {
                self.chart
            }
        }
        .padding( 24 )
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .background( Color.black )
        .environment( \.colorScheme, .dark )
        .accessibilityIdentifier( AccessibilityIdentifier.GraphView.chart )
    }

    /// The line chart of the series' samples, with axis labels from the series.
    ///
    /// Both axes are pinned to the data's own range rather than letting Swift Charts
    /// auto-scale — its default domain includes zero, which for a spectrum (whose
    /// wavelengths start in the thousands) would squeeze the whole curve into a
    /// corner. Pinning to the data extent makes the curve fill the plot.
    private var chart: some View
    {
        Chart( self.series.points )
        {
            point in

            LineMark( x: .value( self.series.xAxisLabel, point.x ), y: .value( self.series.yAxisLabel, point.y ) )
                .foregroundStyle( Color.accentColor )
        }
        .chartXScale( domain: self.xDomain )
        .chartYScale( domain: self.yDomain )
        .chartXAxisLabel( self.series.xAxisLabel )
        .chartYAxisLabel( self.series.yAxisLabel )
    }

    /// The horizontal-axis domain: the samples' `x` range, so the curve spans the
    /// full plot width. Falls back to a unit range for a degenerate (single-value)
    /// axis.
    private var xDomain: ClosedRange< Double >
    {
        Self.domain( of: self.series.points.map { $0.x }, padFraction: 0 )
    }

    /// The vertical-axis domain: the samples' value range with a small margin, so the
    /// curve fills the plot height without touching the top and bottom edges.
    private var yDomain: ClosedRange< Double >
    {
        Self.domain( of: self.series.points.map { $0.y }, padFraction: 0.05 )
    }

    /// Builds a plotting domain from a set of values: their min–max, optionally
    /// padded by a fraction of the span. Returns a small non-degenerate range when
    /// the values are empty or all equal, so the axis never collapses to a point.
    ///
    /// - Parameters:
    ///   - values:      The values to bound.
    ///   - padFraction: The margin to add on each side, as a fraction of the span.
    /// - Returns: The axis domain.
    private static func domain( of values: [ Double ], padFraction: Double ) -> ClosedRange< Double >
    {
        guard let low = values.min(), let high = values.max()
        else
        {
            return 0 ... 1
        }

        guard high > low
        else
        {
            // A flat series: centre it in a unit-tall band so the line is visible.
            return ( low - 0.5 ) ... ( high + 0.5 )
        }

        let padding = ( high - low ) * padFraction

        return ( low - padding ) ... ( high + padding )
    }
}

#Preview
{
    // A synthesised damped sine wave over a physical axis, for the preview.
    let points = ( 0 ..< 240 ).map
    {
        index -> GraphSeries.Point in

        let x = 400.0 + Double( index ) * 2.5
        let y = 1000 + 800 * ( -Double( index ) / 120 ).exponential * ( Double( index ) * 0.15 ).sine

        return GraphSeries.Point( index: index, x: x, y: y )
    }

    return GraphView( series: GraphSeries( points: points, xAxisLabel: "Wavelength (Angstrom)", yAxisLabel: "Flux" ) )
        .frame( width: 640, height: 420 )
}

/// Small `Double` conveniences for the preview's synthesised waveform, kept private
/// so they do not leak into the app.
private extension Double
{
    /// `e` raised to this value.
    var exponential: Double { Foundation.exp( self ) }

    /// The sine of this value (in radians).
    var sine: Double { Foundation.sin( self ) }
}
