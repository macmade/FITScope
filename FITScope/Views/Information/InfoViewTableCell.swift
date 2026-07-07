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

/// A single text cell used inside ``InfoViewTable``, rendering a string at a
/// fixed point size in a caller-chosen shape style.
public struct InfoViewTableCell: View
{
    /// The text to display.
    public let value: String

    /// The font point size.
    public let size: Double

    /// The foreground shape style (e.g. `.primary`, `.secondary`).
    public let style: any ShapeStyle

    /// Whether to render in a monospaced font, so columns of fixed-width metadata
    /// values (index, keyword name, value) align cleanly.
    public let monospaced: Bool

    /// Creates a table cell.
    ///
    /// - Parameters:
    ///   - value:      The text to display.
    ///   - size:       The font point size.
    ///   - style:      The foreground shape style.
    ///   - monospaced: Whether to use a monospaced font. Defaults to `false`.
    public init( value: String, size: Double, style: any ShapeStyle, monospaced: Bool = false )
    {
        self.value      = value
        self.size       = size
        self.style      = style
        self.monospaced = monospaced
    }

    /// The view's content.
    public var body: some View
    {
        Text( self.value )
            .foregroundStyle( self.style )
            .font( .system( size: self.size, design: self.monospaced ? .monospaced : .default ) )
    }
}

#Preview
{
    VStack( alignment: .leading )
    {
        InfoViewTableCell( value: "Lorem Ipsum",    size: 10, style: .primary )
        InfoViewTableCell( value: "Dolor Sit Amet", size: 10, style: .secondary )
    }
    .padding()
}
