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

import Foundation

/// A formatted snapshot of the cursor position and pixel value(s) for the status
/// bar. An absent position yields placeholder text.
///
/// The value(s) are carried per channel: a single entry for a monochrome or
/// colour-filter-array source (shown as one `Value:` field), or three entries for
/// a colour (RGB) source (shown as `R:`/`G:`/`B:` fields).
public struct CursorReadout: Equatable, Sendable
{
    /// The column under the cursor, or `nil` when off-image.
    public let x: Int?

    /// The row under the cursor, or `nil` when off-image.
    public let y: Int?

    /// The decoded pixel value(s) under the cursor: empty when off-image, one entry
    /// for a single-channel source, or three (red, green, blue) for a colour source.
    public let values: [ ImageProcessor.PixelValue ]

    /// The channel labels for a three-channel (RGB) read-out.
    private static let rgbLabels = [ "R", "G", "B" ]

    /// The empty readout, shown when the cursor is off-image.
    public static let empty = CursorReadout( x: nil, y: nil, values: [] )

    /// Creates a readout.
    ///
    /// - Parameters:
    ///   - x:      The column under the cursor, or `nil` when off-image.
    ///   - y:      The row under the cursor, or `nil` when off-image.
    ///   - values: The per-channel pixel values (empty, one, or three).
    public init( x: Int?, y: Int?, values: [ ImageProcessor.PixelValue ] )
    {
        self.x      = x
        self.y      = y
        self.values = values
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

    /// The value field(s): a single `Value:` segment for a single-channel (or
    /// off-image) read-out, or an `R:`/`G:`/`B:` segment per channel for a
    /// three-channel colour read-out. Each segment carries a percentage when the
    /// channel has a full-scale fraction.
    public var valueSegments: [ String ]
    {
        guard self.values.isEmpty == false
        else
        {
            return [ Self.segment( label: nil, value: nil, fraction: nil ) ]
        }

        guard self.values.count == 3
        else
        {
            return self.values.map { Self.segment( label: nil, value: $0.value, fraction: $0.fraction ) }
        }

        return zip( Self.rgbLabels, self.values ).map
        {
            Self.segment( label: $0, value: $1.value, fraction: $1.fraction )
        }
    }

    /// Formats one value segment: `"<name>: <value> (<percent>)"`, where `name`
    /// defaults to `"Value"`, the value falls back to a dash, and the percentage is
    /// shown only when a fraction is present.
    ///
    /// - Parameters:
    ///   - label:    The channel label, or `nil` for the generic `"Value"` field.
    ///   - value:    The value, or `nil` for a placeholder.
    ///   - fraction: The full-scale fraction, or `nil` to omit the percentage.
    /// - Returns: The formatted segment text.
    private static func segment( label: String?, value: Double?, fraction: Double? ) -> String
    {
        let name = label ?? "Value"

        guard let value
        else
        {
            return "\( name ): —"
        }

        let valueString = Self.formatted( value )

        guard let fraction
        else
        {
            return "\( name ): \( valueString )"
        }

        let percent = String( format: "%.2f%%", fraction * 100 )

        return "\( name ): \( valueString ) (\( percent ))"
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
