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

/// Tests for `InfoField`: the enumeration of every value the Image Information
/// panel can show, which drives both the panel and its Preferences editor.
@Suite( "InfoField" )
struct InfoFieldTests
{
    /// Every field has a non-empty, human-readable label.
    @Test
    func everyFieldHasALabel()
    {
        for field in InfoField.allCases
        {
            #expect( field.label.isEmpty == false, "\( field ) must have a display label" )
        }
    }

    /// A field's raw value is a stable identifier (used for persistence) and is
    /// distinct from every other field's.
    @Test
    func rawValuesAreUniqueAndStable()
    {
        let rawValues = InfoField.allCases.map { $0.rawValue }

        #expect( Set( rawValues ).count == InfoField.allCases.count, "raw values must be unique" )
        #expect( rawValues.allSatisfy { $0.isEmpty == false } )
    }

    /// The canonical order begins with the geometry fields, matching the panel's
    /// historical top-to-bottom layout.
    @Test
    func canonicalOrderLeadsWithGeometry()
    {
        #expect( InfoField.allCases.prefix( 3 ) == [ .dimensions, .bitDepth, .channels ] )
    }
}
