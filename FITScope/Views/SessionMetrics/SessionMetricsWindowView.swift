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

/// The root of the single, app-wide Session Metrics window.
///
/// Like the Levels and Curves editors, it is a singleton scene that follows the
/// frontmost document window: it reads the key window's model from the shared
/// ``AppModel`` and re-targets as the user switches windows. Unlike those editors —
/// which act on the selected file — this trends every open file, so it reads the
/// whole model rather than just its selection.
///
/// The window's pieces live in their own files: ``SessionMetricsActiveModelView``
/// bridges the frontmost window's model, ``SessionMetricsChartView`` is the chart,
/// and ``SessionMetricsUnavailableView`` is the no-files placeholder.
public struct SessionMetricsWindowView: View
{
    /// The app-wide coordination object that tracks the frontmost window.
    @EnvironmentObject private var appModel: AppModel

    /// Creates the window root.
    public init()
    {}

    /// The view's content.
    public var body: some View
    {
        Group
        {
            if let model = self.appModel.activeModel
            {
                SessionMetricsActiveModelView( model: model )
            }
            else
            {
                SessionMetricsUnavailableView()
            }
        }
        // Minimum size matches the default, so the window can grow but never shrink
        // below its opening size (which would crowd the fixed SNR curve and the
        // metric chart).
        .frame( minWidth: 900, minHeight: 760 )
        .background
        {
            Rectangle()
                .fill( .windowBackground )
                .overlay( Color.black.opacity( 0.05 ) )
        }
        .persistsWindowFrame( autosaveName: "SessionMetricsWindow", centeredWhenUnsaved: true )
    }
}
