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

/// A compact, tinted text capsule ("pill") for surfacing a short value inline —
/// a metric, a count, a status.
///
/// The `tint` colours both the text and, at `backgroundOpacity`, the capsule
/// behind it. Anything call-site-specific — a tooltip, an accessibility id, or a
/// context-dependent tint (e.g. switching to white on a selected row) — is left
/// to the caller, so the pill stays reusable.
public struct Pill: View
{
    /// The text shown in the pill.
    private let text: String

    /// The colour of the text and, at reduced opacity, the capsule.
    private let tint: Color

    /// The opacity of the capsule fill, relative to ``tint``.
    private let backgroundOpacity: Double

    /// Creates a pill.
    ///
    /// - Parameters:
    ///   - text:              The text to show.
    ///   - tint:              The text and capsule colour. Defaults to the accent.
    ///   - backgroundOpacity: The capsule fill opacity. Defaults to `0.15`.
    public init( _ text: String, tint: Color = .accentColor, backgroundOpacity: Double = 0.15 )
    {
        self.text              = text
        self.tint              = tint
        self.backgroundOpacity = backgroundOpacity
    }

    /// The view's content.
    public var body: some View
    {
        Text( self.text )
            .font( .system( size: 10, weight: .medium ) )
            .monospacedDigit()
            .foregroundStyle( self.tint )
            .padding( .horizontal, 6 )
            .padding( .vertical, 2 )
            .background( Capsule().fill( self.tint.opacity( self.backgroundOpacity ) ) )
    }
}

#Preview
{
    VStack( alignment: .trailing, spacing: 8 )
    {
        Pill( "79.6" )

        Pill( "Processing" )

        Pill( "79.6", tint: .white, backgroundOpacity: 0.25 )
            .padding( 6 )
            .background( Color.accentColor )
    }
    .padding()
}
