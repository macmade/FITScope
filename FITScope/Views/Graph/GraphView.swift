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

/// Plots a ``GraphSeries`` as a line chart, filling the detail region in place of
/// the image canvas for a graph FITS file. A single-spectrum file (`NAXIS=1` — a
/// spectrum, a light curve) draws one accent-coloured line; a stacked-spectra file
/// (`NAXIS=2`) draws one coloured line per spectrum with a naming legend. The axes
/// are labelled from the series (physical when the source carries a coordinate
/// scaling, otherwise the sample number) and shared by every line.
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

    /// The line chart of the series, with axis labels from the series: a single
    /// accent-coloured line for a one-spectrum graph, or one coloured line per
    /// spectrum with a legend for a stacked-spectra graph.
    @ViewBuilder
    private var chart: some View
    {
        if self.series.isMultiLine
        {
            self.multiLineChart
        }
        else
        {
            self.singleLineChart
        }
    }

    /// A single line over the samples, drawn in the accent colour with no legend.
    private var singleLineChart: some View
    {
        self.styled(
            Chart( self.series.points )
            {
                point in

                LineMark( x: .value( self.series.xAxisLabel, point.x ), y: .value( self.series.yAxisLabel, point.y ) )
                    .foregroundStyle( Color.accentColor )
            }
            .chartLegend( .hidden )
        )
    }

    /// One line per spectrum, each coloured and named by its row, with a legend so
    /// the rows can be told apart. Points are grouped into a line by their spectrum
    /// name.
    private var multiLineChart: some View
    {
        self.styled(
            Chart( self.series.lines )
            {
                line in

                ForEach( line.points )
                {
                    point in

                    LineMark( x: .value( self.series.xAxisLabel, point.x ), y: .value( self.series.yAxisLabel, point.y ) )
                        .foregroundStyle( by: .value( "Spectrum", line.name ?? "Row \( line.index + 1 )" ) )
                }
            }
            .chartLegend( .visible )
        )
    }

    /// Pins both axes to the data's own range and applies the shared axis labels.
    ///
    /// Both axes are pinned rather than letting Swift Charts auto-scale — its default
    /// domain includes zero, which for a spectrum (whose wavelengths start in the
    /// thousands) would squeeze the whole curve into a corner. Pinning to the data
    /// extent (across every line) makes the curves fill the plot.
    ///
    /// - Parameter chart: The chart to style.
    /// - Returns: The styled chart.
    private func styled< Content: View >( _ chart: Content ) -> some View
    {
        chart
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

#Preview( "Single spectrum" )
{
    // A synthesised damped sine wave over a physical axis, for the preview.
    let points = ( 0 ..< 240 ).map
    {
        index -> GraphSeries.Point in

        let x = 400.0 + Double( index ) * 2.5

        return GraphView.previewPoint( index: index, x: x, phase: 0 )
    }

    return GraphView( series: GraphSeries( points: points, xAxisLabel: "Wavelength (Angstrom)", yAxisLabel: "Flux" ) )
        .frame( width: 640, height: 420 )
}

#Preview( "Stacked spectra" )
{
    // Three damped sine waves, offset in phase and amplitude, over a shared physical
    // axis — a stacked-spectra graph with one named line per row.
    let lines = ( 0 ..< 3 ).map
    {
        row -> GraphSeries.Line in

        let points = ( 0 ..< 240 ).map
        {
            index in GraphView.previewPoint( index: index, x: 400.0 + Double( index ) * 2.5, phase: Double( row ) * 0.6 )
        }

        return GraphSeries.Line( index: row, name: "Row \( row + 1 )", points: points )
    }

    return GraphView( series: GraphSeries( lines: lines, xAxisLabel: "Wavelength (Angstrom)", yAxisLabel: "Flux" ) )
        .frame( width: 640, height: 420 )
}

private extension GraphView
{
    /// A synthesised damped-sine sample for the previews, phase-shifted so stacked
    /// preview rows are distinguishable.
    ///
    /// - Parameters:
    ///   - index: The zero-based sample index.
    ///   - x:     The horizontal-axis position.
    ///   - phase: The phase offset, in radians, distinguishing stacked rows.
    /// - Returns: The synthesised point.
    static func previewPoint( index: Int, x: Double, phase: Double ) -> GraphSeries.Point
    {
        let y = 1000 + 800 * ( -Double( index ) / 120 ).exponential * ( Double( index ) * 0.15 + phase ).sine

        return GraphSeries.Point( index: index, x: x, y: y )
    }
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
