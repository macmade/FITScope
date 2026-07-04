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

import AppKit
import SwiftPixel
import SwiftUI

/// The histogram section of the controls panel: a mode picker (RGB vs
/// luminance), the ``HistogramView`` itself, and toggles for separating the
/// colour channels and showing summary statistics.
public struct HistogramControlView: View
{
    /// Which histogram is displayed. Defined on the model as ``HistogramMode`` so
    /// the per-image ``HistogramViewOptions`` can store it; aliased here for the
    /// view's call sites.
    public typealias Mode = HistogramMode

    /// The fixed height of the histogram graph box. Shared with
    /// ``HistogramPlaceholderView`` so the loading placeholder reserves the same
    /// height and the sections below the histogram do not shift when it appears.
    public static let graphHeight: CGFloat = 110

    /// The per-image histogram view options this control reads and writes. Held
    /// on the image, so the choices persist across selection changes even though
    /// the inspector is rebuilt for each image.
    @ObservedObject private var options: HistogramViewOptions

    /// The processed histograms to display.
    public let histogram: FITSImageRenderer.Histogram

    /// The per-channel statistics for the processed image.
    public let statistics: FITSImageRenderer.HistogramStatistics

    /// The original (unprocessed) histogram and statistics, or `nil` if not yet
    /// computed. When present, the user can switch the display to it.
    public let original: FITSImageRenderer.HistogramSet?

    /// Creates the histogram control.
    ///
    /// - Parameters:
    ///   - histogram:  The processed histograms to display.
    ///   - statistics: The per-channel statistics for the processed image.
    ///   - original:   The original histogram and statistics, or `nil`.
    ///   - options:    The image's persistent histogram view options.
    public init( histogram: FITSImageRenderer.Histogram, statistics: FITSImageRenderer.HistogramStatistics, original: FITSImageRenderer.HistogramSet?, options: HistogramViewOptions )
    {
        self.histogram  = histogram
        self.statistics = statistics
        self.original   = original
        self.options    = options
    }

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
                    .help( "Choose Which Channels the Histogram Shows" )

                self.optionsButton
            }

            HistogramView(
                histogram:        self.displayedHistogram,
                separateChannels: self.options.separateChannels && self.effectiveMode == .rgb,
                mode:             self.effectiveMode,
                logScale:         self.options.logScale
            )
            .frame( height: Self.graphHeight )
            .padding( 6 )
            .background( Color( nsColor: .textBackgroundColor ) )
            .clipShape( RoundedRectangle( cornerRadius: 10 ) )
            .overlay( RoundedRectangle( cornerRadius: 10 ).strokeBorder( .quaternary, lineWidth: 0.5 ) )

            if self.options.showStatistics
            {
                HStack
                {
                    HistogramStatisticsView( statistics: self.displayedStatistics, mode: self.effectiveMode )
                        .padding( 12 )
                }
                .frame( maxWidth: .infinity, alignment: .leading )
                .background( Color( nsColor: .textBackgroundColor ) )
                .clipShape( RoundedRectangle( cornerRadius: 10 ) )
                .overlay( RoundedRectangle( cornerRadius: 10 ).strokeBorder( .quaternary, lineWidth: 0.5 ) )
                .accessibilityIdentifier( AccessibilityIdentifier.HistogramControlView.statisticsPanel )
            }
        }
    }

    /// The view-options menu. A native pull-down menu opened from this button
    /// collects the toggles into checkmark menu items, keeping every option
    /// reachable in little vertical space.
    ///
    /// Menu items carry no accessibility identifier (only their title), so the UI
    /// tests drive them by title — hence no per-toggle identifiers here.
    private var optionsButton: some View
    {
        Menu
        {
            Toggle( isOn: self.$options.showOriginal )
            {
                Label( "Show Original", systemImage: "photo" )
            }
            .disabled( self.original == nil )

            Toggle( isOn: self.$options.separateChannels )
            {
                Label( "Separate Channels", systemImage: "chart.bar.xaxis" )
            }
            .disabled( self.effectiveMode != .rgb )

            Toggle( isOn: self.$options.logScale )
            {
                Label( "Logarithmic", systemImage: "function" )
            }

            Toggle( isOn: self.$options.showStatistics )
            {
                Label( "Statistics", systemImage: "tablecells" )
            }
        }
        label:
        {
            // Sized to fill the row height so the button matches the segmented
            // control beside it; the shared chrome gives it the same rounded track
            // and soft, backdrop-independent border.
            Image( systemName: "slider.horizontal.3" )
                .frame( width: 30 )
                .frame( maxHeight: .infinity )
                .contentShape( Rectangle() )
                .customControlChrome()
        }
        .menuStyle( .button )
        .buttonStyle( .plain )
        .menuIndicator( .hidden )
        .foregroundStyle( .secondary )
        .help( "Histogram View Options" )
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
        Mode.effectiveMode( stored: self.options.mode, isMono: self.isMono )
    }

    /// A binding that drives the picker from ``effectiveMode`` while recording the
    /// user's choice in the options' mode, so a stored colour mode survives a
    /// detour through a mono image.
    private var modeBinding: Binding< Mode >
    {
        Binding( get: { self.effectiveMode }, set: { self.options.mode = $0 } )
    }

    /// The histograms to draw: the original when "Show Original" is on and the
    /// original is available, otherwise the processed ones.
    private var displayedHistogram: FITSImageRenderer.Histogram
    {
        if self.options.showOriginal, let original = self.original
        {
            return original.histogram
        }

        return self.histogram
    }

    /// The statistics to show, matching ``displayedHistogram``.
    private var displayedStatistics: FITSImageRenderer.HistogramStatistics
    {
        if self.options.showOriginal, let original = self.original
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
        original:   FITSImageRenderer.HistogramSet( histogram: PreviewHelper.histogram(), statistics: PreviewHelper.statistics() ),
        options:    HistogramViewOptions()
    )
    .frame( maxWidth: .infinity, alignment: .leading )
    .frame( maxHeight: .infinity, alignment: .top )
    .padding()
}
