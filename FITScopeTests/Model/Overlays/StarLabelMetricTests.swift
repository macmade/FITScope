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
import SwiftAstro
import Testing

/// Tests for ``StarLabelMetric``: which per-star measurement it selects, that
/// ``StarLabelMetric/none`` yields no label, and that values render to one
/// decimal place.
@Suite( "StarLabelMetric" )
struct StarLabelMetricTests
{
    /// A star with distinct HFR and FWHM, so a wrong-field selection is caught.
    private static func star( hfr: Double, fwhm: Double ) -> Star
    {
        Star( x: 0, y: 0, flux: 1, hfr: hfr, fwhm: fwhm, eccentricity: 0 )
    }

    /// The three cases exist, in a stable order, for the picker.
    @Test
    func offersNoneHFRAndFWHM()
    {
        #expect( StarLabelMetric.allCases == [ .none, .hfr, .fwhm ] )
    }

    /// ``StarLabelMetric/hfr`` selects the star's half-flux radius.
    @Test
    func hfrSelectsTheHalfFluxRadius()
    {
        let star = Self.star( hfr: 2.3, fwhm: 5.4 )

        #expect( StarLabelMetric.hfr.value( for: star ) == 2.3 )
    }

    /// ``StarLabelMetric/fwhm`` selects the star's full width at half maximum.
    @Test
    func fwhmSelectsTheFullWidthAtHalfMaximum()
    {
        let star = Self.star( hfr: 2.3, fwhm: 5.4 )

        #expect( StarLabelMetric.fwhm.value( for: star ) == 5.4 )
    }

    /// ``StarLabelMetric/none`` selects no value and draws no label.
    @Test
    func noneHasNoValueAndNoLabel()
    {
        let star = Self.star( hfr: 2.3, fwhm: 5.4 )

        #expect( StarLabelMetric.none.value( for: star ) == nil )
        #expect( StarLabelMetric.none.label( for: star ) == nil )
    }

    /// HFR and FWHM both produce a (non-nil) label.
    @Test
    func hfrAndFWHMProduceALabel()
    {
        let star = Self.star( hfr: 2.3, fwhm: 5.4 )

        #expect( StarLabelMetric.hfr.label( for: star )  != nil )
        #expect( StarLabelMetric.fwhm.label( for: star ) != nil )
    }

    /// The label renders to a single decimal place, rounding the last digit —
    /// asserted on the trailing digit so the check is independent of the locale's
    /// decimal separator.
    @Test
    func labelRendersToOneDecimalPlace()
    {
        #expect( StarLabelMetric.format( 2.34 ).hasSuffix( "3" ) )
        #expect( StarLabelMetric.format( 2.36 ).hasSuffix( "4" ) )
        #expect( StarLabelMetric.format( 2.0 ).hasSuffix( "0" ) )
    }
}
