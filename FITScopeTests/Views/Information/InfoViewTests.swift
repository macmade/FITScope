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

/// Tests for ``InfoView``: the keyword filtering shown in the headers window and
/// the count label that summarizes how many keywords are shown.
@Suite( "InfoView" )
struct InfoViewTests
{
    /// A small set of header keywords to filter.
    private static var properties: [ FITSImageProperty ]
    {
        [
            FITSImageProperty( index: 0, name: "SIMPLE", kind: "Logical", value: "T",   comment: "conforms to FITS standard" ),
            FITSImageProperty( index: 1, name: "BITPIX", kind: "Integer", value: "16",  comment: "bits per pixel"            ),
            FITSImageProperty( index: 2, name: "OBJECT", kind: "String",  value: "M31", comment: "Andromeda Galaxy"          ),
        ]
    }

    // MARK: - Filtering

    /// An empty query returns every keyword, unchanged and in order.
    @Test
    func emptyQueryReturnsEverything()
    {
        #expect( InfoView.filter( properties: Self.properties, text: "" ) == Self.properties )
    }

    /// The query matches against the keyword name.
    @Test
    func matchesOnName()
    {
        let result = InfoView.filter( properties: Self.properties, text: "BITPIX" )

        #expect( result.map( \.name ) == [ "BITPIX" ] )
    }

    /// The query matches against the value.
    @Test
    func matchesOnValue()
    {
        let result = InfoView.filter( properties: Self.properties, text: "M31" )

        #expect( result.map( \.name ) == [ "OBJECT" ] )
    }

    /// The query matches against the comment.
    @Test
    func matchesOnComment()
    {
        let result = InfoView.filter( properties: Self.properties, text: "Andromeda" )

        #expect( result.map( \.name ) == [ "OBJECT" ] )
    }

    /// The query matches against the kind.
    @Test
    func matchesOnKind()
    {
        let result = InfoView.filter( properties: Self.properties, text: "Logical" )

        #expect( result.map( \.name ) == [ "SIMPLE" ] )
    }

    /// Matching ignores case.
    @Test
    func matchingIsCaseInsensitive()
    {
        let result = InfoView.filter( properties: Self.properties, text: "object" )

        #expect( result.map( \.name ) == [ "OBJECT" ] )
    }

    /// A query that matches nothing returns no keywords.
    @Test
    func nonMatchingQueryReturnsEmpty()
    {
        #expect( InfoView.filter( properties: Self.properties, text: "ZZZZ" ).isEmpty )
    }

    // MARK: - Count label

    /// With nothing filtered out, the label is a plain total with a pluralized noun.
    @Test
    func countLabelShowsPluralTotalWhenUnfiltered()
    {
        #expect( InfoView.countLabel( shown: 142, total: 142 ) == "142 keywords" )
    }

    /// A single keyword uses the singular noun.
    @Test
    func countLabelUsesSingularForOne()
    {
        #expect( InfoView.countLabel( shown: 1, total: 1 ) == "1 keyword" )
    }

    /// An empty section reads as zero keywords (plural).
    @Test
    func countLabelHandlesZero()
    {
        #expect( InfoView.countLabel( shown: 0, total: 0 ) == "0 keywords" )
    }

    /// When a filter hides some keywords, the label shows the shown-of-total form.
    @Test
    func countLabelShowsShownOfTotalWhenFiltering()
    {
        #expect( InfoView.countLabel( shown: 12, total: 142 ) == "12 of 142 keywords" )
    }

    /// The shown-of-total form pluralizes on the total, so a single match of one
    /// keyword still reads in the plural total.
    @Test
    func countLabelPluralizesShownOfTotalOnTheTotal()
    {
        #expect( InfoView.countLabel( shown: 1, total: 142 ) == "1 of 142 keywords" )
    }
}
