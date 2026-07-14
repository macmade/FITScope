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
import SwiftXISF

/// XISF adapter for ``ImageMetadataProperty``: builds a format-neutral display
/// property from an XISF property or embedded FITS keyword, flattening the value
/// into a display string and describing its value type.
public extension ImageMetadataProperty
{
    /// Builds a display property from an XISF property.
    ///
    /// - Parameters:
    ///   - index:    The property's position within its section.
    ///   - property: The parsed XISF property.
    init( index: Int, property: XISFProperty )
    {
        self.init(
            index:   index,
            name:    property.id,
            kind:    property.value.kind.description,
            value:   Self.stringForXISFValue( property.value ) ?? "",
            comment: property.comment ?? ""
        )
    }

    /// Builds a display property from an embedded XISF FITS keyword.
    ///
    /// SwiftXISF exposes the *raw* FITS value string, so a string card keeps its
    /// enclosing single quotes (e.g. `'M 42'`, `'2026-01-01T22:47:49.936'`). Rather
    /// than re-implement FITS string parsing, the value is unquoted by SwiftFITS'
    /// own value parser (see ``fitsValue(name:rawValue:)``), so it displays cleanly
    /// and ``FITSMetadata`` parses it for the astrometry fields exactly as for a
    /// genuine FITS header.
    ///
    /// - Parameters:
    ///   - index:   The property's position within its section.
    ///   - keyword: The embedded FITS keyword.
    init( index: Int, keyword: XISFFITSKeyword )
    {
        let value = Self.fitsValue( name: keyword.name, rawValue: keyword.value )

        self.init(
            index:   index,
            name:    keyword.name,
            kind:    value.kind,
            value:   value.value,
            comment: keyword.comment ?? ""
        )
    }

    /// Interprets an embedded XISF FITS keyword's *raw* value field by reusing
    /// SwiftFITS' own value parser, so FITS string parsing (quote stripping, doubled
    /// `''` unescaping, the significant-space rule) is never re-implemented here.
    ///
    /// The raw field is parsed directly through ``FITSProperty/init(name:rawValue:comment:options:)``
    /// — no 80-character card is reconstructed, so there is no length or truncation
    /// limit and a non-ASCII string is interpreted rather than shown raw. A field
    /// that still cannot be parsed (a malformed value, or a non-standard name) falls
    /// back to the raw value unchanged. Only a *string* card is taken from the parser
    /// (its unquoted text); a numeric or logical field keeps its raw spelling
    /// verbatim, so high-precision values are not rounded by display formatting.
    ///
    /// - Parameters:
    ///   - name:     The keyword name.
    ///   - rawValue: The raw FITS value field, or `nil`.
    /// - Returns: The display value and its value-type description.
    static func fitsValue( name: String, rawValue: String? ) -> ( value: String, kind: String )
    {
        guard let rawValue
        else
        {
            return ( "", "String" )
        }

        guard let property = try? FITSProperty( name: name, rawValue: rawValue, options: .lenient )
        else
        {
            return ( rawValue, "String" )
        }

        // Take the canonically-unquoted text for a string card; keep the raw field
        // for a number/logical so its full precision survives (the display formatter
        // would round a float to six significant figures — and this value feeds
        // FITSMetadata).
        if case .string( let string ) = property.value
        {
            return ( string, property.value.kind.description )
        }

        return ( rawValue.trimmingCharacters( in: .whitespaces ), property.value.kind.description )
    }

    /// Formats an XISF property value for display, dispatching on its case.
    ///
    /// - Parameter value: The value to format.
    /// - Returns: The formatted value, or `nil` when it has no representation.
    static func stringForXISFValue( _ value: XISFValue ) -> String?
    {
        switch value
        {
            case .boolean( let boolean ):

                return boolean ? "true" : "false"

            case .integer( let integer ):

                return String( integer )

            case .unsignedInteger( let unsignedInteger ):

                return String( unsignedInteger )

            case .float( let float ):

                return String( format: "%g", float )

            case .complex( let real, let imaginary ):

                return String( format: "%g %+gi", real, imaginary )

            case .string( let string ):

                return string

            case .timePoint( let date ):

                return ISO8601DateFormatter().string( from: date )

            case .data( let data ):

                return "\( data.count ) bytes"

            @unknown default:

                return nil
        }
    }
}
