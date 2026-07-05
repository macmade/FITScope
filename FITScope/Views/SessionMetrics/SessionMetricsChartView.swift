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

/// Plots one selected metric across the session's frames, optionally overlaying
/// other metrics to compare their trends.
///
/// A metric selector sits at the top; below it, an "Overlays" menu picks additional
/// metrics to co-plot on the metric currently shown — the overlay choice is
/// remembered per metric. The focused metric keeps its real, absolute value axis
/// (adding an overlay never rescales it); overlays — which usually have very
/// different units — are rescaled onto that same range so every curve fills the
/// plot and their *trends* line up (e.g. stars falling as HFR rises), with a legend
/// naming each colour. The view is driven by plain ``SessionMetricSample`` values,
/// so it is self-contained and previewable; ``SessionMetricSeries`` turns the
/// samples into the plotted points, skipping any frame that lacks a metric. When
/// the focused metric has no data yet, an inline placeholder stands in.
struct SessionMetricsChartView: View
{
    /// The session's per-file samples, in the order they were opened.
    let samples: [ SessionMetricSample ]

    /// The metric currently plotted as the focus (its axis is the absolute one).
    @State private var metric: SessionMetric = .stars

    /// The overlays chosen for each focused metric — kept per metric, so each tab
    /// remembers its own overlay set. The focused metric is never overlaid on
    /// itself.
    @State private var overlaysByMetric: [ SessionMetric: Set< SessionMetric > ] = [ : ]

    /// Whether the overlays selection popover is open.
    @State private var showingOverlays = false

    /// The view's content.
    var body: some View
    {
        let points = SessionMetricSeries.points( for: self.metric, from: self.samples )

        VStack( spacing: 12 )
        {
            SegmentedControlView( selection: self.$metric, values: SessionMetric.allCases, title: { $0.title }, icon: { $0.systemImageName } )
                .accessibilityIdentifier( AccessibilityIdentifier.SessionMetricsWindowView.metricPicker )

            HStack( spacing: 0 )
            {
                self.overlaysMenu

                Spacer()
            }

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

    /// The metrics that can be overlaid on the focused one — every metric but it.
    private var overlayableMetrics: [ SessionMetric ]
    {
        SessionMetric.allCases.filter { $0 != self.metric }
    }

    /// The overlays drawn on the focused metric: its own remembered selection, in
    /// the metric order, never including the focused metric itself.
    private var activeOverlays: [ SessionMetric ]
    {
        let selection = self.overlaysByMetric[ self.metric ] ?? []

        return self.overlayableMetrics.filter { selection.contains( $0 ) }
    }

    /// The overlay selector: an "Overlays" label beside a pop-up button that reads
    /// "Choose" (or the chosen metrics, each with a colour dot). Tapping opens a
    /// popover of the other metrics, each with its colour dot and a check when
    /// selected; a metric with no data is disabled. Built as a custom control rather
    /// than a native `Menu` because macOS strips the dots' colours from menu labels.
    private var overlaysMenu: some View
    {
        HStack( spacing: 8 )
        {
            Text( "Overlays" )

            Button
            {
                self.showingOverlays.toggle()
            }
            label:
            {
                HStack( spacing: 8 )
                {
                    self.overlaysLabel

                    Image( systemName: "chevron.up.chevron.down" )
                        .font( .system( size: 9 ) )
                        .foregroundStyle( .secondary )
                }
            }
            .buttonStyle( .bordered )
            .fixedSize()
            .accessibilityIdentifier( AccessibilityIdentifier.SessionMetricsWindowView.overlaysMenu )
            .popover( isPresented: self.$showingOverlays, arrowEdge: .bottom )
            {
                self.overlaysList
            }
        }
    }

    /// The popover body: one selectable row per overlayable metric.
    private var overlaysList: some View
    {
        VStack( alignment: .leading, spacing: 8 )
        {
            ForEach( self.overlayableMetrics )
            {
                metric in self.overlayRow( metric )
            }
        }
        .padding( 10 )
        .frame( minWidth: 180, alignment: .leading )
    }

    /// One overlay row: a check when selected, the metric's colour dot and name.
    /// Disabled (and dimmed) when the metric has no data.
    ///
    /// - Parameter metric: The metric the row toggles.
    /// - Returns: The row.
    private func overlayRow( _ metric: SessionMetric ) -> some View
    {
        let enabled  = self.hasData( metric )
        let selected = ( self.overlaysByMetric[ self.metric ] ?? [] ).contains( metric )

        return Button
        {
            self.toggleOverlay( metric )
        }
        label:
        {
            HStack( spacing: 6 )
            {
                Image( systemName: "checkmark" )
                    .font( .system( size: 10, weight: .semibold ) )
                    .opacity( selected ? 1 : 0 )
                    .frame( width: 12 )

                Circle().fill( Self.color( for: metric ) ).frame( width: 8, height: 8 )

                Text( metric.title )

                Spacer( minLength: 12 )
            }
            .contentShape( Rectangle() )
        }
        .buttonStyle( .plain )
        .disabled( enabled == false )
        .opacity( enabled ? 1 : 0.4 )
    }

    /// Toggles a metric in the focused metric's overlay set.
    ///
    /// - Parameter metric: The overlay to toggle.
    private func toggleOverlay( _ metric: SessionMetric )
    {
        var selection = self.overlaysByMetric[ self.metric ] ?? []

        if selection.contains( metric )
        {
            selection.remove( metric )
        }
        else
        {
            selection.insert( metric )
        }

        self.overlaysByMetric[ self.metric ] = selection
    }

    /// The overlay menu's current-value label: "Choose" when none are selected, else
    /// a colour dot and name for each chosen metric.
    @ViewBuilder     private var overlaysLabel: some View
    {
        let active = self.activeOverlays

        if active.isEmpty
        {
            Text( "Choose" )
        }
        else
        {
            HStack( spacing: 10 )
            {
                ForEach( active )
                {
                    metric in

                    HStack( spacing: 4 )
                    {
                        Circle().fill( Self.color( for: metric ) ).frame( width: 7, height: 7 )

                        Text( metric.title )
                    }
                }
            }
        }
    }

    /// Whether a metric has any plottable points in the session — so a metric with
    /// no data can be disabled in the overlay menu.
    ///
    /// - Parameter metric: The metric to check.
    /// - Returns: `true` when the metric has at least one point.
    private func hasData( _ metric: SessionMetric ) -> Bool
    {
        SessionMetricSeries.points( for: metric, from: self.samples ).isEmpty == false
    }

    /// The chart for the focused metric, with any active overlays. Both paths pin
    /// the value scale only for a constant series and label integer ticks for a
    /// count, so the focused metric's axis is identical with or without overlays.
    ///
    /// - Parameter points: The focused metric's plotted points.
    /// - Returns: The chart.
    @ViewBuilder
    private func chart( _ points: [ SessionMetricSeries.Point ] ) -> some View
    {
        if self.activeOverlays.isEmpty
        {
            self.integerAxisIfNeeded( self.singleChart( points ).chartYScale( domain: self.focusedDomain( points ) ).chartXScale( domain: self.xDomain ) )
        }
        else
        {
            self.integerAxisIfNeeded( self.overlayChart( points ).chartYScale( domain: self.focusedDomain( points ) ).chartXScale( domain: self.xDomain ) )
        }
    }

    /// The X-axis domain: the acquisition-order slots (1…frame count) with a small
    /// margin each side, so the points span nearly the full plot width without Swift
    /// Charts' automatic "nice bounds" padding leaving empty slots at the ends.
    private var xDomain: ClosedRange< Double >
    {
        SessionMetricSeries.acquisitionDomain( frameCount: self.samples.count )
    }

    /// The single-metric line chart with its axis labels, points marked per frame.
    ///
    /// - Parameter points: The plotted points.
    /// - Returns: The chart.
    private func singleChart( _ points: [ SessionMetricSeries.Point ] ) -> some View
    {
        Chart( points )
        {
            point in

            LineMark( x: .value( "Frame", Double( point.position ) ), y: .value( self.metric.title, point.value ) )
                .foregroundStyle( Self.color( for: self.metric ) )

            PointMark( x: .value( "Frame", Double( point.position ) ), y: .value( self.metric.title, point.value ) )
                .foregroundStyle( Self.color( for: self.metric ) )
        }
        .chartXAxisLabel( "Acquisition order" )
        .chartYAxisLabel( self.metric.valueAxisTitle )
        .accessibilityIdentifier( AccessibilityIdentifier.SessionMetricsWindowView.chart )
    }

    /// The overlay chart: the focused metric on its real axis, plus each overlay
    /// rescaled onto that axis' range so all trends are comparable, distinguished by
    /// the metrics' rainbow colours with a naming legend.
    ///
    /// The overlays are rescaled to stay within the focused metric's own value
    /// range, so the axis' data extent — and therefore its scale — is unchanged from
    /// the single-metric view.
    ///
    /// - Parameter points: The focused metric's plotted points.
    /// - Returns: The chart.
    private func overlayChart( _ points: [ SessionMetricSeries.Point ] ) -> some View
    {
        let shown  = [ self.metric ] + self.activeOverlays
        let series = self.overlaySeries( focusedPoints: points, shown: shown, domain: self.valueDomain( points ) )

        return Chart( series )
        {
            point in

            LineMark( x: .value( "Frame", Double( point.position ) ), y: .value( "Value", point.value ) )
                .foregroundStyle( by: .value( "Metric", point.metricTitle ) )

            PointMark( x: .value( "Frame", Double( point.position ) ), y: .value( "Value", point.value ) )
                .foregroundStyle( by: .value( "Metric", point.metricTitle ) )
        }
        .chartForegroundStyleScale( domain: shown.map { $0.title }, range: shown.map { Self.color( for: $0 ) } )
        // No chart legend — it either shrank the plot (below) or drew over the data
        // (overlay). The colours are named by the dots in the Overlays picker.
        .chartLegend( .hidden )
        .chartXAxisLabel( "Acquisition order" )
        .chartYAxisLabel( self.metric.valueAxisTitle )
        .accessibilityIdentifier( AccessibilityIdentifier.SessionMetricsWindowView.chart )
    }

    /// Flattens the focused metric and its overlays into one plottable series, the
    /// focused points kept at their real values and each overlay rescaled onto the
    /// focused domain.
    ///
    /// - Parameters:
    ///   - focusedPoints: The focused metric's points, at their real values.
    ///   - shown:         The metrics to plot, focused first.
    ///   - domain:        The focused metric's value range, the overlays' target.
    /// - Returns: The combined points, tagged by metric.
    private func overlaySeries( focusedPoints: [ SessionMetricSeries.Point ], shown: [ SessionMetric ], domain: ClosedRange< Double > ) -> [ OverlaySeriesPoint ]
    {
        shown.flatMap
        {
            metric -> [ OverlaySeriesPoint ] in

            let points = metric == self.metric
                ? focusedPoints
                : SessionMetricSeries.rescale( SessionMetricSeries.points( for: metric, from: self.samples ), to: domain )

            return points.map { OverlaySeriesPoint( metricTitle: metric.title, position: $0.position, value: $0.value ) }
        }
    }

    /// The focused metric's Y-axis domain: a small pad around its data's min–max so
    /// the series fills the plot without touching the edges (or the padded domain
    /// for a constant series). Pinned explicitly — rather than letting Swift Charts
    /// auto-scale — so a metric renders identically whether it is the focused graph
    /// or an overlay: overlays are rescaled to the *unpadded* data range
    /// (``valueDomain(_:)``), so they fill the same inner region with the same shape
    /// the metric shows on its own tab, and adding an overlay never changes the
    /// focused metric's scale.
    ///
    /// - Parameter points: The focused metric's points.
    /// - Returns: The value-axis domain.
    private func focusedDomain( _ points: [ SessionMetricSeries.Point ] ) -> ClosedRange< Double >
    {
        if let constant = self.constantValueDomain( points )
        {
            return constant
        }

        let values = points.map { $0.value }

        guard let low = values.min(), let high = values.max(), high > low
        else
        {
            return 0 ... 1
        }

        let padding = ( high - low ) * 0.05

        return ( low - padding ) ... ( high + padding )
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

    /// The focused metric's value range for rescaling overlays: its data's min–max,
    /// or the padded domain when the values are constant. Overlays are mapped into
    /// this so they stay within the focused metric's own range.
    ///
    /// - Parameter points: The focused metric's points.
    /// - Returns: The value range.
    private func valueDomain( _ points: [ SessionMetricSeries.Point ] ) -> ClosedRange< Double >
    {
        if let constant = self.constantValueDomain( points )
        {
            return constant
        }

        let values = points.map { $0.value }

        guard let low = values.min(), let high = values.max()
        else
        {
            return 0 ... 1
        }

        return low ... high
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

/// One point of the combined overlay series: a value at a frame position, tagged
/// by the metric it belongs to (for colouring and the legend).
private struct OverlaySeriesPoint: Identifiable
{
    /// The metric's display name, driving its colour and legend entry.
    let metricTitle: String

    /// The frame's 1-based position.
    let position: Int

    /// The plotted value (the focused metric's real value, or an overlay rescaled
    /// onto the focused range).
    let value: Double

    /// A stable identity from the metric and position.
    var id: String
    {
        "\( self.metricTitle )-\( self.position )"
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
