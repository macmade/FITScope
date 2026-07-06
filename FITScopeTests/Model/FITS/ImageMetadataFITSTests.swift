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
import SwiftFITS
import Testing

/// Tests for the FITS adapter of the format-neutral metadata model: the value
/// formatting per keyword kind, and the mapping from parsed FITS sections and
/// properties into ``ImageMetadataSection`` / ``ImageMetadataProperty``.
@Suite( "ImageMetadataFITS" )
struct ImageMetadataFITSTests
{
    // MARK: - Value formatting

    /// A logical value formats as `"T"` / `"F"`, and rejects a non-logical value.
    @Test
    func formatsLogicalValues()
    {
        #expect( ImageMetadataProperty.stringForLogicalValue( .logical( true ) )  == "T" )
        #expect( ImageMetadataProperty.stringForLogicalValue( .logical( false ) ) == "F" )
        #expect( ImageMetadataProperty.stringForLogicalValue( .integer( 1 ) )     == nil )
    }

    /// An integer value formats in base 10, and rejects a non-integer value.
    @Test
    func formatsIntegerValues()
    {
        #expect( ImageMetadataProperty.stringForIntegerValue( .integer( 16 ) )   == "16" )
        #expect( ImageMetadataProperty.stringForIntegerValue( .integer( -42 ) )  == "-42" )
        #expect( ImageMetadataProperty.stringForIntegerValue( .float( 1.0 ) )    == nil )
    }

    /// A float value formats compactly (`%g`), and rejects a non-float value.
    @Test
    func formatsFloatValues()
    {
        #expect( ImageMetadataProperty.stringForFloatValue( .float( 1.5 ) )     == "1.5" )
        #expect( ImageMetadataProperty.stringForFloatValue( .string( "1.5" ) )  == nil )
    }

    /// A string value passes through unchanged, and a non-string value is rejected.
    @Test
    func formatsStringValues()
    {
        #expect( ImageMetadataProperty.stringForStringValue( .string( "M31" ) ) == "M31" )
        #expect( ImageMetadataProperty.stringForStringValue( .integer( 1 ) )    == nil )
    }

    /// An undefined value has no representation.
    @Test
    func formatsUndefinedValue()
    {
        #expect( ImageMetadataProperty.stringForUndefinedValue( .undefined ) == nil )
    }

    /// An unknown-kind value returns its raw text, and rejects a parsed value.
    @Test
    func formatsUnknownValue()
    {
        #expect( ImageMetadataProperty.stringForUnknownValue( .unknown( "raw text" ) ) == "raw text" )
        #expect( ImageMetadataProperty.stringForUnknownValue( .integer( 1 ) )          == nil )
    }

    /// The dispatch entry point formats each value by its kind — verified end to
    /// end against a real parsed keyword.
    @Test
    func dispatchesOnPropertyKind() throws
    {
        let section = try Self.primaryHeader()

        let simple = try #require( section.properties.first { $0.name == "SIMPLE" } )
        let bitpix = try #require( section.properties.first { $0.name == "BITPIX" } )

        #expect( ImageMetadataProperty.stringForPropertyValue( simple ) == "T" )
        #expect( ImageMetadataProperty.stringForPropertyValue( bitpix ) == "8" )
    }

    // MARK: - Property adapter

    /// A property built from a parsed keyword carries the mapped display fields.
    @Test
    func propertyMapsAParsedKeyword() throws
    {
        let section  = try Self.primaryHeader()
        let bitpix   = try #require( section.properties.first { $0.name == "BITPIX" } )
        let property = ImageMetadataProperty( index: 7, property: bitpix )

        #expect( property.index == 7 )
        #expect( property.name  == "BITPIX" )
        #expect( property.kind  == "Integer" )
        #expect( property.value == "8" )
    }

    /// The FITS adapter preserves the empty-string value's identity as distinct
    /// from an absent value: an empty FITS string (`''`) maps to an empty display
    /// value, and the FITS `id` keeps that empty value distinct — whereas the
    /// format-neutral memberwise init collapses an empty value to `<nil>` in its
    /// `id`. This is the sole reason the two `id` formulas differ, so it guards
    /// against the FITS formula silently drifting to match the plain one.
    @Test
    func preservesEmptyStringValueIdentity() throws
    {
        let record   = "FOOBAR  = ''".padding( toLength: 80, withPad: " ", startingAt: 0 )
        let keyword   = try FITSProperty( string: record, options: .lenient )
        let mapped    = ImageMetadataProperty( index: 0, property: keyword )
        let asNeutral = ImageMetadataProperty( index: mapped.index, name: mapped.name, kind: mapped.kind, value: mapped.value, comment: mapped.comment )

        #expect( mapped.kind  == "String" )
        #expect( mapped.value == "" )
        #expect( mapped.id.contains( "-String--" ) ) // empty value segment, not "<nil>"
        #expect( mapped.id != asNeutral.id )          // the plain init collapses "" to "<nil>"
    }

    // MARK: - Section adapter

    /// The primary header maps to a section titled "Primary Header" carrying its
    /// keywords in order.
    @Test
    func mapsPrimaryHeaderSection() throws
    {
        let file    = try Self.imageFile()
        let section = try #require( ImageMetadataSection( index: 0, section: file.sections[ 0 ] ) )

        #expect( section.index == 0 )
        #expect( section.title == "Primary Header" )
        #expect( section.properties.contains { $0.name == "SIMPLE" && $0.value == "T" } )
        #expect( section.properties.contains { $0.name == "NAXIS1" && $0.value == "4" } )
    }

    /// A pure data section carries no displayable keywords, so the adapter drops
    /// it (`nil`).
    @Test
    func rejectsDataSection() throws
    {
        let file = try Self.imageFile()

        let dataIndex = try #require( file.sections.firstIndex { $0.kind == .data }, "a minimal image file has a data section" )

        #expect( ImageMetadataSection( index: dataIndex, section: file.sections[ dataIndex ] ) == nil )
    }

    /// A header section's derived title is "Primary Header".
    @Test
    func derivesPrimaryHeaderTitle() throws
    {
        let file = try Self.imageFile()

        #expect( ImageMetadataSection.title( for: file.sections[ 0 ] ) == "Primary Header" )
    }

    /// An `IMAGE` extension maps to a section titled from its `XTENSION` keyword
    /// ("Extension: IMAGE"), carrying its keywords.
    @Test
    func mapsExtensionSection() throws
    {
        let file  = try Self.multiHDUFile()
        let index = try #require( file.sections.firstIndex { $0.kind == .xtension }, "the file has an IMAGE extension" )
        let extn  = file.sections[ index ]

        #expect( ImageMetadataSection.title( for: extn ) == "Extension: IMAGE" )

        let section = try #require( ImageMetadataSection( index: index, section: extn ) )

        #expect( section.index == index )
        #expect( section.title == "Extension: IMAGE" )
        #expect( section.properties.contains { $0.name == "XTENSION" && $0.value == "IMAGE" } )
    }

    // MARK: - Helpers

    /// Builds a minimal in-memory 4×4 image FITS file, so section/property tests
    /// don't depend on a bundled fixture. The header carries keywords of several
    /// value kinds (logical, integer).
    private static func imageFile() throws -> FITSFile
    {
        let records =
            [
                "SIMPLE  = T",
                "BITPIX  = 8",
                "NAXIS   = 2",
                "NAXIS1  = 4",
                "NAXIS2  = 4",
                "END",
            ]

        let header = records.map { $0.padding( toLength: 80, withPad: " ", startingAt: 0 ) }.joined()
        var data   = Data( header.padding( toLength: FITSFile.blockSize, withPad: " ", startingAt: 0 ).utf8 )

        data.append( Data( count: FITSFile.blockSize ) ) // 4×4 bytes fit in one data block.

        return try FITSFile( data: data, options: .lenient )
    }

    /// The parsed primary header section of the minimal image file.
    private static func primaryHeader() throws -> FITSSection
    {
        try self.imageFile().sections[ 0 ]
    }

    /// Builds a minimal in-memory FITS file with an empty (`NAXIS = 0`) primary
    /// HDU followed by a 4×4 `IMAGE` extension, so the extension-title branch of
    /// the section adapter can be exercised on a genuinely parsed extension.
    private static func multiHDUFile() throws -> FITSFile
    {
        func block( _ records: [ String ] ) -> Data
        {
            let header = records.map { $0.padding( toLength: 80, withPad: " ", startingAt: 0 ) }.joined()

            return Data( header.padding( toLength: FITSFile.blockSize, withPad: " ", startingAt: 0 ).utf8 )
        }

        let primary =
            [
                "SIMPLE  = T",
                "BITPIX  = 8",
                "NAXIS   = 0",
                "END",
            ]

        let extension_ =
            [
                "XTENSION= 'IMAGE   '",
                "BITPIX  = 8",
                "NAXIS   = 2",
                "NAXIS1  = 4",
                "NAXIS2  = 4",
                "PCOUNT  = 0",
                "GCOUNT  = 1",
                "END",
            ]

        var data = block( primary )

        data.append( block( extension_ ) )
        data.append( Data( count: FITSFile.blockSize ) ) // 4×4 extension pixels fit in one data block.

        return try FITSFile( data: data, options: .lenient )
    }
}
