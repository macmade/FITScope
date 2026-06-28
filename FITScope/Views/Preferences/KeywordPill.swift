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

/// A tappable pill for one placeholder keyword, used in the Astro preferences
/// palette. Its tint matches the inline keyword pills in the formula editor, so
/// the palette reads as the same vocabulary.
public struct KeywordPill: View
{
    /// The keyword shown and inserted.
    private let keyword: String

    /// The tooltip describing what the keyword represents.
    private let tooltip: String

    /// The action run when the pill is clicked.
    private let action: () -> Void

    /// Creates a keyword pill.
    ///
    /// - Parameters:
    ///   - keyword: The keyword to show and insert.
    ///   - tooltip: A description of what the keyword represents.
    ///   - action:  The action run on click.
    public init( _ keyword: String, tooltip: String, action: @escaping () -> Void )
    {
        self.keyword = keyword
        self.tooltip = tooltip
        self.action  = action
    }

    /// The view's content.
    public var body: some View
    {
        Button( action: self.action )
        {
            Text( self.keyword )
                .font( .system( .caption, design: .monospaced ) )
                .padding( .horizontal, 8 )
                .padding( .vertical, 3 )
                .background( Capsule().fill( Color( nsColor: PillTint.background ) ) )
                .foregroundStyle( Color( nsColor: PillTint.foreground ) )
        }
        .buttonStyle( .plain )
        .help( self.tooltip )
    }
}

#Preview
{
    KeywordPill( "FWHMMin", tooltip: "Smallest image FWHM across all open images." ) {}
        .padding()
}
