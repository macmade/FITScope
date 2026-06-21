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

/// The histogram section of the controls panel: a mode picker (RGB vs
/// luminance), the ``HistogramView`` itself, and toggles for separating the
/// colour channels and showing summary statistics.
public struct HistogramControlView: View
{
    /// Which histogram is displayed.
    public enum Mode: CaseIterable, CustomStringConvertible
    {
        /// The per-channel red/green/blue histogram.
        case rgb

        /// The single-channel luminance histogram.
        case luminance

        /// The single-channel histogram of a monochrome image.
        case mono

        /// The picker label for the mode.
        public var description: String
        {
            switch self
            {
                case .rgb:       return "RGB"
                case .luminance: return "Luminance"
                case .mono:      return "Mono"
            }
        }

        /// The modes a histogram offers for an image, given whether it is
        /// monochrome: a single ``mono`` mode for mono images, or the RGB and
        /// luminance choice for colour images.
        ///
        /// - Parameter isMono: Whether the rendered image is monochrome.
        /// - Returns: The selectable modes, in display order.
        public static func availableModes( isMono: Bool ) -> [ Mode ]
        {
            isMono ? [ .mono ] : [ .rgb, .luminance ]
        }

        /// Resolves the mode actually shown for an image, clamping a stored mode
        /// that no longer applies: a mono image is always shown in ``mono`` mode,
        /// and a stale ``mono`` selection carried over to a colour image falls
        /// back to ``rgb``.
        ///
        /// - Parameters:
        ///   - stored: The mode last selected by the user.
        ///   - isMono: Whether the rendered image is monochrome.
        /// - Returns: The mode to display.
        public static func effectiveMode( stored: Mode, isMono: Bool ) -> Mode
        {
            if isMono
            {
                return .mono
            }

            return stored == .mono ? .rgb : stored
        }
    }

    /// Whether the RGB channels are drawn stacked separately rather than
    /// overlaid. Has no effect in luminance mode.
    @State private var separateChannels = false

    /// Whether the summary statistics panel is shown.
    @State private var showStatistics   = false

    /// Whether the original (unprocessed) histogram is shown instead of the
    /// current processed one.
    @State private var showOriginal     = false

    /// The currently displayed histogram mode.
    @State private var mode             = Mode.rgb

    /// The processed histograms to display.
    public let histogram:  FITSImageRenderer.Histogram

    /// The per-channel statistics for the processed image.
    public let statistics: FITSImageRenderer.HistogramStatistics

    /// The original (unprocessed) histogram and statistics, or `nil` if not yet
    /// computed. When present, the user can switch the display to it.
    public let original:   FITSImageRenderer.HistogramSet?

    /// The view's content.
    public var body: some View
    {
        VStack( alignment: .leading )
        {
            HStack( spacing: 6 )
            {
                SegmentedControlView( selection: self.modeBinding, values: self.availableModes, title: { $0.description } )
                    .frame( maxWidth: .infinity )
                    .accessibilityIdentifier( AccessibilityIdentifier.HistogramControlView.mode )

                self.optionsButton
            }

            HistogramView(
                histogram:        self.displayedHistogram,
                separateChannels: self.separateChannels && self.effectiveMode == .rgb,
                mode:             self.effectiveMode
            )
            .frame( height: 110 )
            .padding( 6 )
            .background( Color.black.opacity( 0.35 ) )
            .clipShape( RoundedRectangle( cornerRadius: 10 ) )
            .overlay( RoundedRectangle( cornerRadius: 10 ).strokeBorder( .white.opacity( 0.08 ), lineWidth: 1 ) )

            if self.showStatistics
            {
                HStack
                {
                    HistogramStatisticsView( statistics: self.displayedStatistics, mode: self.effectiveMode )
                        .padding( 12 )
                }
                .frame( maxWidth: .infinity, alignment: .leading )
                .background( Color.black.opacity( 0.35 ) )
                .clipShape( RoundedRectangle( cornerRadius: 10 ) )
                .overlay( RoundedRectangle( cornerRadius: 10 ).strokeBorder( .white.opacity( 0.08 ), lineWidth: 1 ) )
                .accessibilityIdentifier( AccessibilityIdentifier.HistogramControlView.statisticsPanel )
            }
        }
    }

    /// The view-options menu. The toggles were previously three full-width rows;
    /// collapsing them into a native pull-down menu opened from this button keeps
    /// every option reachable in far less vertical space.
    ///
    /// The toggles render as checkmark menu items. Menu items carry no
    /// accessibility identifier (only their title), so the UI tests drive them by
    /// title — hence no per-toggle identifiers here.
    private var optionsButton: some View
    {
        Menu
        {
            Toggle( isOn: self.$showOriginal )
            {
                Label( "Show Original", systemImage: "photo" )
            }
            .disabled( self.original == nil )

            Toggle( isOn: self.$separateChannels )
            {
                Label( "Separate Channels", systemImage: "chart.bar.xaxis" )
            }
            .disabled( self.effectiveMode != .rgb )

            Toggle( isOn: self.$showStatistics )
            {
                Label( "Statistics", systemImage: "tablecells" )
            }
        }
        label:
        {
            // Sized to fill the row height so the button matches the segmented
            // control beside it; the rounded track mirrors that control's style.
            Image( systemName: "slider.horizontal.3" )
                .frame( width: 30 )
                .frame( maxHeight: .infinity )
                .contentShape( Rectangle() )
                .background( Color.black.opacity( 0.25 ), in: RoundedRectangle( cornerRadius: 7 ) )
                .overlay( RoundedRectangle( cornerRadius: 7 ).strokeBorder( .white.opacity( 0.08 ), lineWidth: 1 ) )
        }
        .menuStyle( .button )
        .buttonStyle( .plain )
        .menuIndicator( .hidden )
        .foregroundStyle( .secondary )
        .help( "Histogram view options" )
        .accessibilityIdentifier( AccessibilityIdentifier.HistogramControlView.viewOptions )
    }

    /// Whether the rendered image is monochrome, in which case the histogram is
    /// shown as a single mono channel rather than RGB/luminance.
    private var isMono: Bool
    {
        self.histogram.isMono
    }

    /// The modes the picker offers for the current image.
    private var availableModes: [ Mode ]
    {
        Mode.availableModes( isMono: self.isMono )
    }

    /// The mode actually displayed, clamping the stored selection to one that
    /// applies to the current image (see ``Mode/effectiveMode(stored:isMono:)``).
    private var effectiveMode: Mode
    {
        Mode.effectiveMode( stored: self.mode, isMono: self.isMono )
    }

    /// A binding that drives the picker from ``effectiveMode`` while recording the
    /// user's choice in ``mode``, so a stored colour mode survives a detour
    /// through a mono image.
    private var modeBinding: Binding< Mode >
    {
        Binding( get: { self.effectiveMode }, set: { self.mode = $0 } )
    }

    /// The histograms to draw: the original when "Show Original" is on and the
    /// original is available, otherwise the processed ones.
    private var displayedHistogram: FITSImageRenderer.Histogram
    {
        if self.showOriginal, let original = self.original
        {
            return original.histogram
        }

        return self.histogram
    }

    /// The statistics to show, matching ``displayedHistogram``.
    private var displayedStatistics: FITSImageRenderer.HistogramStatistics
    {
        if self.showOriginal, let original = self.original
        {
            return original.statistics
        }

        return self.statistics
    }
}

#Preview
{
    HistogramControlView(
        histogram:  PreviewHelper.histogram(),
        statistics: PreviewHelper.statistics(),
        original:   FITSImageRenderer.HistogramSet( histogram: PreviewHelper.histogram(), statistics: PreviewHelper.statistics() )
    )
    .frame( maxWidth: .infinity, alignment: .leading )
    .frame( maxHeight: .infinity, alignment: .top )
    .padding()
}
