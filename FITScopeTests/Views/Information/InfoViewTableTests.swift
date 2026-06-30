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
import SwiftUI
import Testing

/// Tests for ``InfoViewTable``: the per-kind capsule tint used in the Kind column.
@Suite( "InfoViewTable" )
struct InfoViewTableTests
{
    /// Each recognized value-type kind maps to its own distinct colour.
    @Test
    func recognizedKindsMapToDistinctColors()
    {
        #expect( InfoViewTable.color( forKind: "Logical" ) == .green )
        #expect( InfoViewTable.color( forKind: "Integer" ) == .blue )
        #expect( InfoViewTable.color( forKind: "Float" )   == .purple )
        #expect( InfoViewTable.color( forKind: "String" )  == .orange )

        let named = Set( [ Color.green, .blue, .purple, .orange ] )

        #expect( named.count == 4, "The recognized kinds must use four distinct colours." )
    }

    /// Undefined and unknown kinds share the neutral grey.
    @Test
    func undefinedAndUnknownAreGrey()
    {
        #expect( InfoViewTable.color( forKind: "Undefined" ) == .gray )
        #expect( InfoViewTable.color( forKind: "Unknown" )   == .gray )
    }

    /// Any unrecognized kind falls back to the neutral grey rather than crashing
    /// or picking a recognized colour.
    @Test
    func unrecognizedKindFallsBackToGrey()
    {
        #expect( InfoViewTable.color( forKind: "Banana" ) == .gray )
        #expect( InfoViewTable.color( forKind: "" )       == .gray )
    }
}
