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

/// Bridges the frontmost window's model to the session charts, snapshotting every
/// open file's metrics and keeping the charts live as those metrics arrive.
///
/// The model is observed for the file set changing; a ``SessionMetricsFilesObserver``
/// covers the metrics arriving asynchronously *within* the files (which the model
/// does not itself re-publish). On any change, the samples are re-snapshotted from
/// the current files.
struct SessionMetricsActiveModelView: View
{
    /// The frontmost window's model, observed so opening or closing a file
    /// re-snapshots the session.
    @ObservedObject var model: WindowModel

    /// Watches every open file so a file finishing its analysis refreshes the
    /// charts, not just adding or removing one.
    @StateObject private var filesObserver = SessionMetricsFilesObserver()

    /// The reference the relative-SNR figures and curve are compared against;
    /// defaults to one hour.
    @State private var reference: IntegrationReference = .hours( 1 )

    /// The view's content.
    var body: some View
    {
        Group
        {
            if self.model.files.isEmpty
            {
                SessionMetricsUnavailableView()
            }
            else
            {
                self.content
            }
        }
        .onAppear
        {
            self.filesObserver.observe( self.model.files )
        }
        .onChange( of: self.model.files.map { $0.id } )
        {
            _, _ in self.filesObserver.observe( self.model.files )
        }
    }

    /// The integration summary strip, the cumulative-SNR curve (when there is
    /// integration data), and the per-frame metric chart — all fed from one
    /// snapshot of the open files.
    private var content: some View
    {
        let samples   = self.model.files.map { SessionMetricSample( file: $0 ) }
        let summary   = IntegrationSummary( exposures: samples.map { $0.exposure }, reference: self.reference )
        let snrPoints = summary.map { SessionMetricSeries.cumulativeRelativeSNRPoints( from: samples, referenceSeconds: $0.referenceSeconds ) } ?? []

        return VStack( spacing: 0 )
        {
            SessionMetricsSummaryView( summary: summary, reference: self.$reference )

            if summary != nil
            {
                Divider()

                // A fixed height, so only the per-frame metric chart below grows when
                // the window is resized.
                SessionMetricsSNRCurveView( points: snrPoints, referenceTitle: self.reference.title )
                    .frame( height: 180 )
            }

            Divider()

            SessionMetricsChartView( samples: samples )
        }
    }
}
