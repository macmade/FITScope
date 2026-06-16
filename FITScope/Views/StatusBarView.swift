/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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

/// The full-width status bar below the panes: a status message, the cursor
/// readout, and the image dimensions / bit depth on the trailing edge.
public struct StatusBarView: View
{
    /// The leading status message (e.g. "Ready").
    public let status:    String

    /// The cursor readout fields.
    public let readout:   CursorReadout

    /// The trailing dimensions / bit-depth summary, or `nil` when no file.
    public let dimensions: String?

    /// Creates the status bar.
    public init( status: String, readout: CursorReadout, dimensions: String? )
    {
        self.status     = status
        self.readout    = readout
        self.dimensions = dimensions
    }

    /// The view's content.
    public var body: some View
    {
        HStack( spacing: 0 )
        {
            self.segment( self.status )
            self.segment( self.readout.xText )
            self.segment( self.readout.yText )
            self.segment( self.readout.valueText )

            Spacer()

            if let dimensions = self.dimensions
            {
                self.segment( dimensions, trailing: true )
            }
        }
        .font( .system( size: 10, design: .monospaced ) )
        .foregroundStyle( .secondary )
        .frame( height: 24 )
        .background( .bar )
        .overlay( alignment: .top ) { Divider() }
    }

    /// A status-bar segment with consistent padding.
    private func segment( _ text: String, trailing: Bool = false ) -> some View
    {
        Text( text )
            .padding( .horizontal, 10 )
            .lineLimit( 1 )
    }
}

#Preview
{
    StatusBarView( status: "Ready", readout: CursorReadout( x: 3120, y: 2080, value: 1823, fraction: 1823.0 / 65535.0 ), dimensions: "6240 × 4160 • 16-bit" )
}
