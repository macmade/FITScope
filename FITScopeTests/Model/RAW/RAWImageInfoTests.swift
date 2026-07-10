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
import SwiftRAW
import Testing

/// Tests ``RAWImageInfo``'s colour-filter-array pattern derivation, which reads the
/// visible mosaic's Bayer phase at the crop origin so the pattern stays correct after
/// the optical-black margins are removed.
@Suite( "RAWImageInfo" )
struct RAWImageInfoTests
{
    /// The Bayer `filters` value for a canonical RGGB sensor (LibRAW encoding).
    private static let rggbFilters: UInt32 = 0x9494_9494

    /// With no margins, the pattern is the sensor's native phase.
    @Test
    func derivesNativePattern()
    {
        let cfa = RAWCFAPattern( filters: Self.rggbFilters, colorDescription: "RGBG" )

        #expect( RAWImageInfo.cfaPatternString( cfa: cfa, leftMargin: 0, topMargin: 0 ) == "RGGB" )
    }

    /// An odd left margin shifts the phase by one column (RGGB → GRBG).
    @Test
    func oddLeftMarginShiftsColumn()
    {
        let cfa = RAWCFAPattern( filters: Self.rggbFilters, colorDescription: "RGBG" )

        #expect( RAWImageInfo.cfaPatternString( cfa: cfa, leftMargin: 1, topMargin: 0 ) == "GRBG" )
    }

    /// An odd top margin shifts the phase by one row (RGGB → GBRG).
    @Test
    func oddTopMarginShiftsRow()
    {
        let cfa = RAWCFAPattern( filters: Self.rggbFilters, colorDescription: "RGBG" )

        #expect( RAWImageInfo.cfaPatternString( cfa: cfa, leftMargin: 0, topMargin: 1 ) == "GBRG" )
    }

    /// A non-Bayer sensor (no CFA) has no pattern, so it renders as monochrome.
    @Test
    func nonBayerSensorHasNoPattern()
    {
        let cfa = RAWCFAPattern( filters: 0, colorDescription: "" )

        #expect( RAWImageInfo.cfaPatternString( cfa: cfa, leftMargin: 0, topMargin: 0 ) == nil )
    }
}
