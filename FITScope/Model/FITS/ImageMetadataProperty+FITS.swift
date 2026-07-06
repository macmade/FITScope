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

/// FITS adapter for ``ImageMetadataProperty``: builds a format-neutral display
/// property from a parsed FITS header keyword, flattening its value into a
/// display string and describing its value type.
public extension ImageMetadataProperty
{
    /// Builds a display property from a parsed FITS header property.
    ///
    /// Preserves the exact identity the FITS keyword snapshot used previously:
    /// the id keeps the value/comment `nil` distinct from an empty string, so an
    /// undefined-valued keyword never collides with an empty-string one.
    ///
    /// - Parameters:
    ///   - index:    The property's position within its section.
    ///   - property: The parsed FITS header property.
    init( index: Int, property: FITSProperty )
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
    static func stringForPropertyValue( _ property: FITSProperty ) -> String?
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
    static func stringForLogicalValue( _ value: FITSValue ) -> String?
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
    static func stringForIntegerValue( _ value: FITSValue ) -> String?
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
    static func stringForFloatValue( _ value: FITSValue ) -> String?
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
    static func stringForStringValue( _ value: FITSValue ) -> String?
    {
        value.string
    }

    /// Formats an undefined value, which has no representation.
    ///
    /// - Parameter value: The value to format (ignored).
    /// - Returns: Always `nil`.
    static func stringForUndefinedValue( _ value: FITSValue ) -> String?
    {
        nil
    }

    /// Returns the raw text of an unparsed (unknown-kind) value.
    ///
    /// - Parameter value: The value to format.
    /// - Returns: The raw text, or `nil` when the value is not of unknown kind.
    static func stringForUnknownValue( _ value: FITSValue ) -> String?
    {
        guard case .unknown( let value ) = value
        else
        {
            return nil
        }

        return value
    }
}
