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

/// Tests for ``HeaderExport``: serializing image metadata to CSV and TSV, with
/// the field escaping each format requires.
@Suite( "HeaderExport" )
struct HeaderExportTests
{
    /// The column header row both formats begin with.
    private static let header = "Section,Index,Name,Kind,Value,Comment"

    /// A small two-section metadata snapshot for the integration cases.
    private static func sampleInfo() -> ImageMetadata
    {
        let primary = ImageMetadataSection(
            index:   0,
            title:   "Primary Header",
            properties:
            [
                ImageMetadataProperty( index: 0, name: "SIMPLE",  kind: "Logical", value: "T",     comment: "conforms to FITS standard" ),
                ImageMetadataProperty( index: 1, name: "OBJECT",  kind: "String",  value: "M31",   comment: "" ),
            ]
        )

        let extensionSection = ImageMetadataSection( index: 1, title: "Extension: IMAGE", properties: [ ImageMetadataProperty( index: 0, name: "EXTNAME", kind: "String", value: "SCI", comment: "" ) ] )

        return ImageMetadata( url: URL( fileURLWithPath: "/tmp/sample.fits" ), sections: [ primary, extensionSection ] )
    }

    // MARK: - CSV escaping

    /// A plain field with no special characters is emitted unchanged in CSV.
    @Test
    func csvLeavesPlainFieldUnquoted() async
    {
        #expect( HeaderExport.escape( "BITPIX", for: .csv ) == "BITPIX" )
    }

    /// A field containing a comma is wrapped in double quotes.
    @Test
    func csvQuotesFieldWithComma() async
    {
        #expect( HeaderExport.escape( "1, 2, 3", for: .csv ) == "\"1, 2, 3\"" )
    }

    /// A field containing a double quote is wrapped and its quotes doubled.
    @Test
    func csvDoublesEmbeddedQuotes() async
    {
        #expect( HeaderExport.escape( "say \"hi\"", for: .csv ) == "\"say \"\"hi\"\"\"" )
    }

    /// A field containing a newline is wrapped in double quotes (RFC 4180 allows a
    /// newline inside a quoted field).
    @Test
    func csvQuotesFieldWithNewline() async
    {
        #expect( HeaderExport.escape( "line1\nline2", for: .csv ) == "\"line1\nline2\"" )
    }

    // MARK: - TSV escaping

    /// A plain field is emitted unchanged in TSV.
    @Test
    func tsvLeavesPlainFieldUnchanged() async
    {
        #expect( HeaderExport.escape( "M31", for: .tsv ) == "M31" )
    }

    /// A tab inside a field is replaced with a space, since TSV has no quoting.
    @Test
    func tsvReplacesTab() async
    {
        #expect( HeaderExport.escape( "a\tb", for: .tsv ) == "a b" )
    }

    /// Newlines (including CRLF) inside a field are replaced with a single space.
    @Test
    func tsvReplacesNewlines() async
    {
        #expect( HeaderExport.escape( "a\r\nb", for: .tsv ) == "a b" )
        #expect( HeaderExport.escape( "a\nb",   for: .tsv ) == "a b" )
        #expect( HeaderExport.escape( "a\rb",   for: .tsv ) == "a b" )
    }

    // MARK: - Rows

    /// A CSV row joins escaped fields with commas.
    @Test
    func csvRowJoinsWithCommas() async
    {
        #expect( HeaderExport.row( [ "a", "b,c", "d" ], for: .csv ) == "a,\"b,c\",d" )
    }

    /// A TSV row joins escaped fields with tabs.
    @Test
    func tsvRowJoinsWithTabs() async
    {
        #expect( HeaderExport.row( [ "a", "b\tc", "d" ], for: .tsv ) == "a\tb c\td" )
    }

    // MARK: - Full export

    /// The CSV export begins with the column header and uses CRLF row separators.
    @Test
    func csvExportHasHeaderAndCRLFRows() async
    {
        let output = HeaderExport.export( Self.sampleInfo(), as: .csv )
        let lines  = output.components( separatedBy: "\r\n" )

        #expect( lines.first == Self.header )
        #expect( lines.count == 4 ) // header + 3 properties
        #expect( lines.contains( "Primary Header,0,SIMPLE,Logical,T,conforms to FITS standard" ) )
        #expect( lines.contains( "Extension: IMAGE,0,EXTNAME,String,SCI," ) )
    }

    /// The TSV export begins with the tab-joined header and uses LF row separators.
    @Test
    func tsvExportHasHeaderAndLFRows() async
    {
        let output = HeaderExport.export( Self.sampleInfo(), as: .tsv )
        let lines  = output.components( separatedBy: "\n" )

        #expect( lines.first == "Section\tIndex\tName\tKind\tValue\tComment" )
        #expect( lines.count == 4 )
        #expect( lines.contains( "Primary Header\t0\tSIMPLE\tLogical\tT\tconforms to FITS standard" ) )
        #expect( output.contains( "\r\n" ) == false )
    }

    /// The export covers every section, prefixing each row with the section title.
    @Test
    func exportIncludesAllSections() async
    {
        let output = HeaderExport.export( Self.sampleInfo(), as: .csv )

        #expect( output.contains( "Primary Header," ) )
        #expect( output.contains( "Extension: IMAGE," ) )
    }

    /// The sections overload serializes only the sections it is given, so the
    /// displayed-section export omits the others.
    @Test
    func exportSerializesOnlyTheGivenSections() async
    {
        let primary = Self.sampleInfo().sections[ 0 ]
        let output  = HeaderExport.export( [ primary ], as: .csv )
        let lines   = output.components( separatedBy: "\r\n" )

        #expect( lines.count == 3 ) // header + 2 properties
        #expect( lines.contains( "Primary Header,0,SIMPLE,Logical,T,conforms to FITS standard" ) )
        #expect( output.contains( "Extension: IMAGE" ) == false )
    }
}
