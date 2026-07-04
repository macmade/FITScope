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

/// A compact strip summarizing the session's total integration time and the
/// relative signal-to-noise it buys, versus a reference the user picks.
///
/// Driven by an ``IntegrationSummary`` (the √t figures); the reference is chosen
/// once, from the menu, so the three figures stay plainly labelled. When no
/// summary is available — no frame carries an exposure time — a short note stands
/// in, so the absence is explained rather than silent.
struct SessionMetricsSummaryView: View
{
    /// The session's integration figures, or `nil` when no exposure time is known.
    let summary: IntegrationSummary?

    /// The reference the figures are compared against, chosen from the menu.
    @Binding var reference: IntegrationReference

    /// The view's content.
    var body: some View
    {
        VStack( spacing: 8 )
        {
            if let summary = self.summary
            {
                self.referencePicker

                HStack( spacing: 0 )
                {
                    self.stat( "Total Integration", value: Self.durationText( summary.totalSeconds ), help: "Total exposure of all open frames (the sum of each frame's EXPTIME)." )
                    self.separator
                    self.stat( "Relative SNR", value: Self.snrText( summary.relativeSNR ), help: "Signal-to-noise of the stacked result relative to the selected reference. SNR grows as the square root of total integration: √(total ÷ reference)." )
                    self.separator
                    self.stat( "Gain", value: Self.gainText( summary.gain ), help: "How much more (or less) SNR than the reference: Relative SNR − 1." )
                    self.separator
                    self.stat( "Noise", value: Self.noiseText( summary.relativeNoise ), help: "Noise of the stacked result relative to the reference (noise falls as 1 ÷ √time): 1 ÷ Relative SNR." )
                }
            }
            else
            {
                Text( "Integration time unavailable — no exposure (EXPTIME) in the headers." )
                    .font( .system( size: 11 ) )
                    .foregroundStyle( .secondary )
                    .frame( maxWidth: .infinity, alignment: .center )
            }
        }
        .padding( .horizontal, 16 )
        .padding( .vertical, 10 )
        .accessibilityIdentifier( AccessibilityIdentifier.SessionMetricsWindowView.summary )
    }

    /// The reference selector: a native pop-up offering a single-frame baseline,
    /// then the target-hour options. Its own label ("Relative to") keeps it aligned,
    /// and the pop-up chrome makes it read as clickable. The chosen reference labels
    /// the whole strip.
    private var referencePicker: some View
    {
        HStack( spacing: 0 )
        {
            Picker( "Relative to", selection: self.$reference )
            {
                Text( "Single frame" ).tag( IntegrationReference.singleFrame )

                Section
                {
                    ForEach( IntegrationReference.hourOptions, id: \.self )
                    {
                        hours in Text( "\( hours ) h" ).tag( IntegrationReference.hours( hours ) )
                    }
                }
            }
            .pickerStyle( .menu )
            .fixedSize()
            .accessibilityIdentifier( AccessibilityIdentifier.SessionMetricsWindowView.referencePicker )

            Spacer()
        }
    }

    /// A vertical divider sized to the strip's height.
    private var separator: some View
    {
        Divider().frame( height: 28 )
    }

    /// One labelled figure: the value above its caption, sharing the strip width
    /// equally with the others, with an explanatory tooltip.
    ///
    /// - Parameters:
    ///   - label: The caption.
    ///   - value: The formatted value.
    ///   - help:  The tooltip explaining what the figure means.
    /// - Returns: The stat cell.
    private func stat( _ label: String, value: String, help: String ) -> some View
    {
        VStack( spacing: 2 )
        {
            Text( value )
                .font( .system( size: 15, weight: .semibold ) )
                .monospacedDigit()

            Text( label )
                .font( .system( size: 10 ) )
                .foregroundStyle( .secondary )
        }
        .frame( maxWidth: .infinity )
        .contentShape( Rectangle() )
        .help( help )
    }

    /// Formats an integration time as a compact `"3h 30m"` / `"1m 30s"` / `"50s"`.
    ///
    /// - Parameter seconds: The integration time, in seconds.
    /// - Returns: The display string.
    private static func durationText( _ seconds: Double ) -> String
    {
        let total   = Int( seconds.rounded() )
        let hours   = total / 3600
        let minutes = ( total % 3600 ) / 60
        let secs    = total % 60

        if hours > 0
        {
            return minutes > 0 ? "\( hours )h \( minutes )m" : "\( hours )h"
        }

        if minutes > 0
        {
            return secs > 0 ? "\( minutes )m \( secs )s" : "\( minutes )m"
        }

        return "\( secs )s"
    }

    /// Formats the relative SNR as `"1.87×"`.
    ///
    /// - Parameter value: The relative SNR.
    /// - Returns: The display string.
    private static func snrText( _ value: Double ) -> String
    {
        value.formatted( .number.precision( .fractionLength( 2 ) ) ) + "×"
    }

    /// Formats the gain as a signed percentage, `"+87%"` / `"-29%"` (`"0%"` at the
    /// reference).
    ///
    /// - Parameter gain: The gain fraction (`relativeSNR − 1`).
    /// - Returns: The display string.
    private static func gainText( _ gain: Double ) -> String
    {
        ( gain * 100 ).formatted( .number.precision( .fractionLength( 0 ) ).sign( strategy: .always( includingZero: false ) ) ) + "%"
    }

    /// Formats the relative noise as a percentage of the reference noise, `"53%"`.
    ///
    /// - Parameter value: The relative noise fraction.
    /// - Returns: The display string.
    private static func noiseText( _ value: Double ) -> String
    {
        ( value * 100 ).formatted( .number.precision( .fractionLength( 0 ) ) ) + "%"
    }
}

#Preview( "With integration" )
{
    SessionMetricsSummaryView( summary: IntegrationSummary( totalSeconds: 3.5 * 3600, frameCount: 42, reference: .hours( 1 ) ), reference: .constant( .hours( 1 ) ) )
        .frame( width: 640 )
}

#Preview( "No exposure data" )
{
    SessionMetricsSummaryView( summary: nil, reference: .constant( .hours( 1 ) ) )
        .frame( width: 640 )
}
