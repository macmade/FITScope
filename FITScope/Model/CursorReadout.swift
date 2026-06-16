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

import Foundation

/// A formatted snapshot of the cursor position and raw pixel value for the
/// status bar. An absent position yields placeholder text.
public struct CursorReadout: Equatable, Sendable
{
    /// The column under the cursor, or `nil` when off-image.
    public let x:        Int?

    /// The row under the cursor, or `nil` when off-image.
    public let y:        Int?

    /// The raw pixel value, or `nil` when off-image.
    public let value:    Double?

    /// The value's fraction of full scale, or `nil`.
    public let fraction: Double?

    /// The empty readout, shown when the cursor is off-image.
    public static let empty = CursorReadout( x: nil, y: nil, value: nil, fraction: nil )

    /// Creates a readout.
    public init( x: Int?, y: Int?, value: Double?, fraction: Double? )
    {
        self.x        = x
        self.y        = y
        self.value    = value
        self.fraction = fraction
    }

    /// The `x:` field text.
    public var xText: String
    {
        "x: \( self.x.map( String.init ) ?? "—" )"
    }

    /// The `y:` field text.
    public var yText: String
    {
        "y: \( self.y.map( String.init ) ?? "—" )"
    }

    /// The `Value:` field text, with a percentage when a fraction is present.
    public var valueText: String
    {
        guard let value = self.value
        else
        {
            return "Value: —"
        }

        let valueString = Self.formatted( value )

        if let fraction = self.fraction
        {
            let percent = String( format: "%.2f%%", fraction * 100 )

            return "Value: \( valueString ) (\( percent ))"
        }

        return "Value: \( valueString )"
    }

    /// Formats a value as an integer when whole, otherwise with up to three
    /// fractional digits.
    private static func formatted( _ value: Double ) -> String
    {
        if value.rounded() == value
        {
            return String( Int( value ) )
        }

        return String( format: "%g", value )
    }
}
