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

@testable import FITScope
import Foundation
import Testing

/// Tests for ``ImageMetadataProperty/fitsValue(name:rawValue:)``: an embedded XISF
/// FITS keyword's *raw* value field is interpreted through SwiftFITS' own value
/// parser, so a string card is unquoted while a number or logical keeps its raw
/// spelling, and the value field has no 80-column card length limit.
@Suite( "ImageMetadataProperty+XISF" )
struct ImageMetadataPropertyXISFTests
{
    @Test
    func unquotesAStringCard() throws
    {
        let result = ImageMetadataProperty.fitsValue( name: "OBJECT", rawValue: "'M 42'" )

        #expect( result.value == "M 42" )
        #expect( result.kind  == "String" )
    }

    @Test
    func keepsANumberRawSpellingAndItsKind() throws
    {
        // The raw spelling is preserved verbatim so a high-precision float is not
        // rounded by display formatting (the value also feeds FITSMetadata).
        let result = ImageMetadataProperty.fitsValue( name: "EXPTIME", rawValue: "300.000000123" )

        #expect( result.value == "300.000000123" )
        #expect( result.kind  == "Float" )
    }

    @Test
    func classifiesIntegerAndLogicalKeepingTheRawValue() throws
    {
        let integer = ImageMetadataProperty.fitsValue( name: "XBINNING", rawValue: "2" )
        let logical = ImageMetadataProperty.fitsValue( name: "SIMPLE",   rawValue: "T" )

        #expect( integer.value == "2" )
        #expect( integer.kind  == "Integer" )
        #expect( logical.value == "T" )
        #expect( logical.kind  == "Logical" )
    }

    @Test
    func unescapesDoubledQuotesInAStringCard() throws
    {
        let result = ImageMetadataProperty.fitsValue( name: "OBSERVER", rawValue: "'O''Brien'" )

        #expect( result.value == "O'Brien" )
        #expect( result.kind  == "String" )
    }

    @Test
    func unquotesALongStringWithoutTruncation() throws
    {
        // A quoted string whose card would exceed 80 columns: the old hand-built
        // card bailed out and showed the raw quoted field; parsing the value field
        // directly unquotes the whole string.
        let text   = String( repeating: "A", count: 100 )
        let result = ImageMetadataProperty.fitsValue( name: "OBJECT", rawValue: "'\( text )'" )

        #expect( result.value == text )
        #expect( result.kind  == "String" )
    }

    @Test
    func unquotesANonASCIIStringValue() throws
    {
        // A value field with non-ASCII characters can no longer be modelled as an
        // 80-byte card, so it is unquoted directly rather than shown raw.
        let result = ImageMetadataProperty.fitsValue( name: "OBSERVER", rawValue: "'Müller'" )

        #expect( result.value == "Müller" )
        #expect( result.kind  == "String" )
    }

    @Test
    func returnsAnEmptyStringForAValuelessKeyword() throws
    {
        let result = ImageMetadataProperty.fitsValue( name: "HISTORY", rawValue: nil )

        #expect( result.value == "" )
        #expect( result.kind  == "String" )
    }
}
