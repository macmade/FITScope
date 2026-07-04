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

/// The placeholder shown in the Session Metrics window when no files are open to
/// chart.
struct SessionMetricsUnavailableView: View
{
    /// The view's content.
    var body: some View
    {
        VStack( spacing: 10 )
        {
            Image( systemName: "chart.line.uptrend.xyaxis" )
                .font( .system( size: 38 ) )
                .foregroundStyle( .secondary )

            Text( "No Session Metrics" )
                .font( .headline )

            Text( "Open FITS files to chart their metrics across the session." )
                .foregroundStyle( .secondary )
                .multilineTextAlignment( .center )
        }
        .padding( 40 )
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .accessibilityIdentifier( AccessibilityIdentifier.SessionMetricsWindowView.unavailable )
    }
}

#Preview
{
    SessionMetricsUnavailableView()
        .frame( width: 640, height: 420 )
}
