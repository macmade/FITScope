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

/// Tests for `FileSortKey`: each key orders files correctly, missing numeric
/// values always sort last, and ties resolve stably.
@Suite( "FileSortKey" )
@MainActor
struct FileSortKeyTests
{
    /// A stand-in sortable file, so the sort logic can be tested without loading
    /// real images.
    private struct StubFile: FileSortable
    {
        let displayName: String
        let weight:      Double?
        let metrics:     ImageWeighting.Metrics

        init( _ name: String, weight: Double? = nil, fwhm: Double? = nil, hfr: Double? = nil, eccentricity: Double? = nil, stars: Double? = nil, snrWeight: Double? = nil )
        {
            self.displayName = name
            self.weight      = weight

            var metrics: ImageWeighting.Metrics = [ : ]

            metrics[ .fwhm ]         = fwhm
            metrics[ .hfr ]          = hfr
            metrics[ .eccentricity ] = eccentricity
            metrics[ .stars ]        = stars
            metrics[ .snrWeight ]    = snrWeight

            self.metrics = metrics
        }
    }

    @Test
    func openedKeepsNaturalOrderAndReverses()
    {
        let files = [ StubFile( "c" ), StubFile( "a" ), StubFile( "b" ) ]

        #expect( FileSortKey.opened.sorted( files, ascending: true ).map  { $0.displayName } == [ "c", "a", "b" ] )
        #expect( FileSortKey.opened.sorted( files, ascending: false ).map { $0.displayName } == [ "b", "a", "c" ] )
    }

    @Test
    func sortsByNameCaseInsensitively()
    {
        let files = [ StubFile( "Banana" ), StubFile( "apple" ), StubFile( "Cherry" ) ]

        #expect( FileSortKey.name.sorted( files, ascending: true ).map  { $0.displayName } == [ "apple", "Banana", "Cherry" ] )
        #expect( FileSortKey.name.sorted( files, ascending: false ).map { $0.displayName } == [ "Cherry", "Banana", "apple" ] )
    }

    @Test
    func sortsByWeightWithMissingValuesLast()
    {
        let files =
            [
                StubFile( "a", weight: 3 ),
                StubFile( "b", weight: nil ),
                StubFile( "c", weight: 1 ),
                StubFile( "d", weight: 2 ),
            ]

        #expect( FileSortKey.weight.sorted( files, ascending: true ).map { $0.displayName } == [ "c", "d", "a", "b" ] )
    }

    @Test
    func sortsByMetricWithMissingValuesLast()
    {
        let files =
            [
                StubFile( "a", fwhm: 2.5 ),
                StubFile( "b" ),
                StubFile( "c", fwhm: 1.5 ),
            ]

        #expect( FileSortKey.fwhm.sorted( files, ascending: true ).map  { $0.displayName } == [ "c", "a", "b" ] )
        #expect( FileSortKey.fwhm.sorted( files, ascending: false ).map { $0.displayName } == [ "a", "c", "b" ] )
    }

    @Test
    func missingValuesStayLastWhenDescending()
    {
        let files =
            [
                StubFile( "a", weight: nil ),
                StubFile( "b", weight: 1 ),
                StubFile( "c", weight: nil ),
                StubFile( "d", weight: 2 ),
            ]

        // Present weights ranked high-to-low, then the nil files (stable by name).
        #expect( FileSortKey.weight.sorted( files, ascending: false ).map { $0.displayName } == [ "d", "b", "a", "c" ] )
    }

    @Test
    func equalValuesBreakTiesByName()
    {
        let files = [ StubFile( "zeta", weight: 5 ), StubFile( "alpha", weight: 5 ) ]

        #expect( FileSortKey.weight.sorted( files, ascending: true ).map  { $0.displayName } == [ "alpha", "zeta" ] )
        #expect( FileSortKey.weight.sorted( files, ascending: false ).map { $0.displayName } == [ "alpha", "zeta" ] )
    }

    @Test
    func pillTextShowsWeightForNonMetricKeys()
    {
        let file = StubFile( "a", weight: 12.3 )

        #expect( FileSortKey.opened.pillText( for: file, formattedWeight: "12.3" ) == "12.3" )
        #expect( FileSortKey.name.pillText( for: file, formattedWeight: "12.3" ) == "12.3" )
        #expect( FileSortKey.weight.pillText( for: file, formattedWeight: "12.3" ) == "12.3" )
    }

    @Test
    func pillTextShowsSelectedMetricFormatted()
    {
        let file = StubFile( "a", fwhm: 2.5, hfr: 3.456, eccentricity: 0.4, stars: 1234, snrWeight: 9.87 )

        #expect( FileSortKey.fwhm.pillText( for: file, formattedWeight: "0.0" ) == "2.50" )
        #expect( FileSortKey.hfr.pillText( for: file, formattedWeight: "0.0" ) == "3.46" )
        #expect( FileSortKey.eccentricity.pillText( for: file, formattedWeight: "0.0" ) == "0.40" )
        #expect( FileSortKey.stars.pillText( for: file, formattedWeight: "0.0" ) == "1234" )
        #expect( FileSortKey.snrWeight.pillText( for: file, formattedWeight: "0.0" ) == "9.9" )
    }

    @Test
    func pillTextIsNilWhenSelectedMetricIsMissing()
    {
        let file = StubFile( "a", weight: 5 )

        #expect( FileSortKey.fwhm.pillText( for: file, formattedWeight: "5.0" ) == nil )
        #expect( FileSortKey.stars.pillText( for: file, formattedWeight: "5.0" ) == nil )
    }
}
