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

/// Tests for the format-neutral metadata model: ``ImageMetadataProperty``,
/// ``ImageMetadataSection`` and ``ImageMetadata`` — their field mapping, stable
/// identities and `Codable`/`Hashable` conformances.
@Suite( "ImageMetadata" )
struct ImageMetadataTests
{
    // MARK: - ImageMetadataProperty

    /// A property carries its display fields verbatim.
    @Test
    func propertyKeepsItsFields()
    {
        let property = ImageMetadataProperty( index: 3, name: "BITPIX", kind: "Integer", value: "16", comment: "bits per pixel" )

        #expect( property.index   == 3 )
        #expect( property.name    == "BITPIX" )
        #expect( property.kind    == "Integer" )
        #expect( property.value   == "16" )
        #expect( property.comment == "bits per pixel" )
    }

    /// The identity combines every field, so two rows differing only in one field
    /// never collide.
    @Test
    func propertyIdentityCombinesEveryField()
    {
        let a = ImageMetadataProperty( index: 0, name: "N", kind: "String", value: "a", comment: "c" )
        let b = ImageMetadataProperty( index: 0, name: "N", kind: "String", value: "b", comment: "c" )

        #expect( a.id != b.id )
    }

    /// An empty value or comment reads as `<nil>` in the identity, so a blank
    /// field still yields a well-formed, stable id.
    @Test
    func propertyIdentityUsesPlaceholderForEmptyFields()
    {
        let property = ImageMetadataProperty( index: 1, name: "OBJECT", kind: "String", value: "", comment: "" )

        #expect( property.id == "1-OBJECT-String-<nil>-<nil>" )
    }

    /// A property survives a `Codable` round-trip unchanged.
    @Test
    func propertyRoundTripsThroughCodable() throws
    {
        let property = ImageMetadataProperty( index: 2, name: "EXPTIME", kind: "Float", value: "30", comment: "seconds" )
        let data     = try JSONEncoder().encode( property )
        let decoded  = try JSONDecoder().decode( ImageMetadataProperty.self, from: data )

        #expect( decoded == property )
    }

    // MARK: - ImageMetadataSection

    /// A section carries its parts and derives a stable identity from index and
    /// title.
    @Test
    func sectionKeepsItsPartsAndIdentity()
    {
        let property = ImageMetadataProperty( index: 0, name: "SIMPLE", kind: "Logical", value: "T", comment: "" )
        let section  = ImageMetadataSection( index: 4, title: "Primary Header", properties: [ property ] )

        #expect( section.index      == 4 )
        #expect( section.title      == "Primary Header" )
        #expect( section.properties == [ property ] )
        #expect( section.id         == "4-Primary Header" )
    }

    /// A section survives a `Codable` round-trip unchanged.
    @Test
    func sectionRoundTripsThroughCodable() throws
    {
        let section = ImageMetadataSection(
            index:      0,
            title:      "Primary Header",
            properties: [ ImageMetadataProperty( index: 0, name: "SIMPLE", kind: "Logical", value: "T", comment: "" ) ]
        )

        let data    = try JSONEncoder().encode( section )
        let decoded = try JSONDecoder().decode( ImageMetadataSection.self, from: data )

        #expect( decoded == section )
    }

    // MARK: - ImageMetadata

    /// A metadata snapshot carries its URL and sections.
    @Test
    func metadataKeepsURLAndSections()
    {
        let section  = ImageMetadataSection( index: 0, title: "Primary Header", properties: [] )
        let url       = URL( fileURLWithPath: "/tmp/sample.fits" )
        let metadata  = ImageMetadata( url: url, sections: [ section ] )

        #expect( metadata.url      == url )
        #expect( metadata.sections == [ section ] )
    }

    /// A metadata snapshot survives a `Codable` round-trip unchanged, so it can be
    /// carried across SwiftUI's value-based scenes.
    @Test
    func metadataRoundTripsThroughCodable() throws
    {
        let metadata = ImageMetadata(
            url:      URL( fileURLWithPath: "/tmp/sample.fits" ),
            sections:
            [
                ImageMetadataSection(
                    index:      0,
                    title:      "Primary Header",
                    properties: [ ImageMetadataProperty( index: 0, name: "SIMPLE", kind: "Logical", value: "T", comment: "conforms" ) ]
                ),
            ]
        )

        let data    = try JSONEncoder().encode( metadata )
        let decoded = try JSONDecoder().decode( ImageMetadata.self, from: data )

        #expect( decoded == metadata )
    }
}
