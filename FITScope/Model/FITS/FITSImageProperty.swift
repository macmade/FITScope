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
import SwiftFITS

/// A display-ready, `Codable` snapshot of a single FITS header keyword.
///
/// Flattens a `FITSProperty` into plain strings — the keyword, its value
/// formatted for display, its type description and comment — so it can populate
/// a `Table` and travel across SwiftUI's value-based scenes.
public struct FITSImageProperty: Codable, Hashable, Identifiable
{
    /// A stable identity combining the index, name, kind, value and comment, so
    /// distinct rows never collide even when keywords repeat.
    public let id: String

    /// The property's position within its section.
    public let index: Int

    /// The keyword name (e.g. `BITPIX`).
    public let name: String

    /// A human-readable description of the value's type (logical, integer, …).
    public let kind: String

    /// The value formatted as a display string, or `""` when absent.
    public let value: String

    /// The keyword's comment, or `""` when absent.
    public let comment: String

    /// Builds a display property from a parsed header property.
    ///
    /// - Parameters:
    ///   - index:    The property's position within its section.
    ///   - property: The parsed FITS header property.
    public init( index: Int, property: FITSProperty )
    {
        let value    = Self.stringForPropertyValue( property )
        self.index   = index
        self.name    = property.name
        self.kind    = property.value.kind.description
        self.value   = value ?? ""
        self.comment = property.comment ?? ""
        self.id      = "\( index )-\( property.name )-\( property.value.kind.description )-\( value ?? "<nil>" )-\( property.comment ?? "<nil>" )"
    }

    /// Formats a property's value for display, dispatching on its kind.
    ///
    /// - Parameter property: The header property whose value to format.
    /// - Returns: The formatted value, or `nil` when it cannot be represented.
    public static func stringForPropertyValue( _ property: FITSProperty ) -> String?
    {
        switch property.value.kind
        {
            case .logical:    return self.stringForLogicalValue(   property.value )
            case .integer:    return self.stringForIntegerValue(   property.value )
            case .float:      return self.stringForFloatValue(     property.value )
            case .string:     return self.stringForStringValue(    property.value )
            case .undefined:  return self.stringForUndefinedValue( property.value )
            case .unknown:    return self.stringForUnknownValue(   property.value )
            @unknown default: return nil
        }
    }

    /// Formats a logical value as `"T"` or `"F"`.
    ///
    /// - Parameter value: The value to format.
    /// - Returns: `"T"` / `"F"`, or `nil` when the value is not logical.
    public static func stringForLogicalValue( _ value: FITSValue ) -> String?
    {
        guard let value = value.logical
        else
        {
            return nil
        }

        return value ? "T" : "F"
    }

    /// Formats an integer value in base 10.
    ///
    /// - Parameter value: The value to format.
    /// - Returns: The decimal string, or `nil` when the value is not an integer.
    public static func stringForIntegerValue( _ value: FITSValue ) -> String?
    {
        guard let value = value.integer
        else
        {
            return nil
        }

        return String( format: "%lli", value )
    }

    /// Formats a floating-point value using the compact `%g` representation.
    ///
    /// - Parameter value: The value to format.
    /// - Returns: The formatted string, or `nil` when the value is not a float.
    public static func stringForFloatValue( _ value: FITSValue ) -> String?
    {
        guard let value = value.float
        else
        {
            return nil
        }

        return String( format: "%g", value )
    }

    /// Returns a string value unchanged.
    ///
    /// - Parameter value: The value to format.
    /// - Returns: The underlying string, or `nil` when the value is not a string.
    public static func stringForStringValue( _ value: FITSValue ) -> String?
    {
        value.string
    }

    /// Formats an undefined value, which has no representation.
    ///
    /// - Parameter value: The value to format (ignored).
    /// - Returns: Always `nil`.
    public static func stringForUndefinedValue( _ value: FITSValue ) -> String?
    {
        nil
    }

    /// Returns the raw text of an unparsed (unknown-kind) value.
    ///
    /// - Parameter value: The value to format.
    /// - Returns: The raw text, or `nil` when the value is not of unknown kind.
    public static func stringForUnknownValue( _ value: FITSValue ) -> String?
    {
        guard case .unknown( let value ) = value
        else
        {
            return nil
        }

        return value
    }
}
