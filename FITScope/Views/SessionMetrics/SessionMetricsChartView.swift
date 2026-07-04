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

/// Plots one selected metric across the session's frames.
///
/// A metric selector sits above a line chart of the metric versus acquisition
/// order. The view is driven by plain ``SessionMetricSample`` values, so it is
/// self-contained and previewable; ``SessionMetricSeries`` turns the samples into
/// the plotted points, skipping any frame that lacks the chosen metric. When no
/// frame carries the selected metric yet (e.g. detection is still running), an
/// inline placeholder stands in for the chart.
struct SessionMetricsChartView: View
{
    /// The session's per-file samples, in the order they were opened.
    let samples: [ SessionMetricSample ]

    /// The metric currently plotted.
    @State private var metric: SessionMetric = .stars

    /// The view's content.
    var body: some View
    {
        let points = SessionMetricSeries.points( for: self.metric, from: self.samples )

        VStack( spacing: 12 )
        {
            SegmentedControlView( selection: self.$metric, values: SessionMetric.allCases, title: { $0.title }, icon: { $0.systemImageName } )
                .accessibilityIdentifier( AccessibilityIdentifier.SessionMetricsWindowView.metricPicker )

            if points.isEmpty
            {
                StatusMessageView( systemImage: self.metric.systemImageName, title: "No \( self.metric.title ) Data Yet", message: "It appears as the open files finish analysis." )
                    .clipShape( RoundedRectangle( cornerRadius: 8 ) )
            }
            else
            {
                self.chart( points )
            }
        }
        .padding()
        .frame( maxWidth: .infinity, maxHeight: .infinity )
    }

    /// The rainbow palette the metrics draw their dedicated colours from, in order.
    static let palette: [ Color ] = [ .red, .orange, .yellow, .green, .blue, .purple ]

    /// The dedicated line colour for a metric: its position in the metric order
    /// mapped onto the rainbow ``palette``, so the colours stay a rainbow whatever
    /// the metric order and a metric always reads in the same colour.
    ///
    /// - Parameter metric: The metric to colour.
    /// - Returns: Its colour.
    static func color( for metric: SessionMetric ) -> Color
    {
        guard let index = SessionMetric.allCases.firstIndex( of: metric ), index < Self.palette.count
        else
        {
            return .accentColor
        }

        return Self.palette[ index ]
    }

    /// The line chart of the selected metric against acquisition order, one marked
    /// point per frame — pinning a sensible value domain for a constant series and
    /// labelling only whole-number ticks for count-type metrics.
    ///
    /// - Parameter points: The plotted points, in acquisition order.
    /// - Returns: The chart.
    private func chart( _ points: [ SessionMetricSeries.Point ] ) -> some View
    {
        self.integerAxisIfNeeded( self.scaledChart( points ) )
    }

    /// The bare line chart with its axis labels, pinning a padded value domain when
    /// every point shares the same value.
    ///
    /// A constant series (e.g. every frame is starless, so the star count is a flat
    /// `0`) collapses Swift Charts' automatic Y domain to a single point, floating
    /// the line mid-height with no value labels; the pinned domain keeps the labels
    /// and seats the line sensibly. A varying series auto-scales.
    ///
    /// - Parameter points: The plotted points.
    /// - Returns: The scaled chart.
    @ViewBuilder
    private func scaledChart( _ points: [ SessionMetricSeries.Point ] ) -> some View
    {
        let chart = Chart( points )
        {
            point in

            LineMark( x: .value( "Frame", point.position ), y: .value( self.metric.title, point.value ) )
                .foregroundStyle( Self.color( for: self.metric ) )

            PointMark( x: .value( "Frame", point.position ), y: .value( self.metric.title, point.value ) )
                .foregroundStyle( Self.color( for: self.metric ) )
        }
        .chartXAxisLabel( "Acquisition order" )
        .chartYAxisLabel( self.metric.valueAxisTitle )
        .accessibilityIdentifier( AccessibilityIdentifier.SessionMetricsWindowView.chart )

        if let domain = self.constantValueDomain( points )
        {
            chart.chartYScale( domain: domain )
        }
        else
        {
            chart
        }
    }

    /// Restricts the value axis to whole-number ticks for count-type metrics, so a
    /// star count never shows a meaningless fractional label (e.g. "0.5"); other
    /// metrics keep the automatic axis.
    ///
    /// - Parameter chart: The chart to label.
    /// - Returns: The chart, with an integer value axis when the metric is a count.
    @ViewBuilder
    private func integerAxisIfNeeded< Content: View >( _ chart: Content ) -> some View
    {
        if self.metric.usesIntegerValues
        {
            chart.chartYAxis
            {
                AxisMarks
                {
                    value in

                    if let number = value.as( Double.self ), number == number.rounded()
                    {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel { Text( number.formatted( .number.precision( .fractionLength( 0 ) ) ) ) }
                    }
                }
            }
        }
        else
        {
            chart
        }
    }

    /// A padded value-axis domain for the degenerate case where every plotted point
    /// shares the same value — which collapses Swift Charts' automatic Y domain to a
    /// single point, floating the line mid-height with no value labels. Returns
    /// `nil` when the values vary, letting the chart auto-scale.
    ///
    /// - Parameter points: The plotted points.
    /// - Returns: A non-degenerate domain to pin the axis to, or `nil`.
    private func constantValueDomain( _ points: [ SessionMetricSeries.Point ] ) -> ClosedRange< Double >?
    {
        let values = points.map { $0.value }

        guard let low = values.min(), let high = values.max(), low == high
        else
        {
            return nil
        }

        // An all-zero series (e.g. every frame starless) reads best pinned to the
        // axis floor, so the flat line sits at the bottom rather than the middle.
        guard high != 0
        else
        {
            return 0 ... 1
        }

        let padding = abs( high ) * 0.5

        return ( high - padding ) ... ( high + padding )
    }
}

#Preview( "Trend" )
{
    SessionMetricsChartView( samples: SessionMetricSample.previewSamples )
        .frame( width: 640, height: 420 )
}

#Preview( "Selected metric missing" )
{
    SessionMetricsChartView( samples: [ SessionMetricSample( id: UUID(), name: "light-001.fits", observationDate: nil, starCount: nil, noise: nil, fwhm: nil, hfr: nil, eccentricity: nil, background: nil, exposure: nil ) ] )
        .frame( width: 640, height: 420 )
}

private extension SessionMetricSample
{
    /// A handful of frames with a gentle focus drift, for the chart previews.
    static var previewSamples: [ SessionMetricSample ]
    {
        ( 0 ..< 8 ).map
        {
            index in

            let drift = Double( index )

            return SessionMetricSample(
                id:              UUID(),
                name:            String( format: "light-%03d.fits", index + 1 ),
                observationDate: Date( timeIntervalSinceReferenceDate: Double( index ) * 120 ),
                starCount:       420  - index * 12,
                noise:           24   + drift * 1.5,
                fwhm:            2.8  + drift * 0.15,
                hfr:             1.9  + drift * 0.08,
                eccentricity:    0.35 + drift * 0.01,
                background:      0.08 + drift * 0.02,
                exposure:        300
            )
        }
    }
}
