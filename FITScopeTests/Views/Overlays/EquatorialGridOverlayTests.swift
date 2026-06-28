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
import SwiftFITS
import Testing

/// Tests for ``EquatorialGridOverlay``: availability gates the toolbar toggle on
/// whether a WCS projection can be built, and the pure helpers pick a nice grid
/// step for a field span and format RA/Dec values in sexagesimal (RA in hours and
/// minutes, Dec in degrees and arcminutes) at a precision matching the step.
@Suite( "EquatorialGridOverlay" )
struct EquatorialGridOverlayTests
{
    /// A full WCS (reference point, reference pixel, and CD matrix) sufficient for
    /// a projection.
    private static func wcs() -> FITSMetadata
    {
        FITSMetadata( properties: [ "CRVAL1": 10.0, "CRVAL2": 20, "CRPIX1": 100, "CRPIX2": 100, "CD1_1": -0.001, "CD1_2": 0, "CD2_1": 0, "CD2_2": 0.001 ].map { FITSPropertySnapshot( name: $0.key, value: .float( $0.value ) ) } )
    }

    @Test
    func isUnavailableWithoutWCS() throws
    {
        #expect( EquatorialGridOverlay( wcs: nil ).isAvailable == false )
    }

    @Test
    func isUnavailableWithoutAProjection() throws
    {
        // A CD matrix with no reference point cannot project, so the grid is
        // unavailable and its toggle is hidden.
        let metadata = FITSMetadata( properties: [ "CD1_1", "CD1_2", "CD2_1", "CD2_2" ].map { FITSPropertySnapshot( name: $0, value: .float( 0.001 ) ) } )

        #expect( EquatorialGridOverlay( wcs: metadata ).isAvailable == false )
    }

    @Test
    func isAvailableWithAFullWCS() throws
    {
        #expect( EquatorialGridOverlay( wcs: Self.wcs() ).isAvailable )
    }

    @Test
    func hasAStableNonDisplayIdentifier() throws
    {
        #expect( EquatorialGridOverlay( wcs: nil ).id == "grid" )
    }

    @Test
    func niceStepPicksTheSmallestStepWithinTheTargetCount() throws
    {
        // span / step must be at most the target count, so the smallest candidate
        // at least span/target is chosen: 100 / 5 = 20 → the smallest candidate
        // ≥ 20 is 30.
        #expect( EquatorialGridOverlay.niceStep( span: 100, candidates: [ 1, 2, 5, 10, 30, 60 ], targetCount: 5 ) == 30 )
    }

    @Test
    func niceStepFallsBackToTheLargestCandidateForAHugeSpan() throws
    {
        // No candidate keeps the count within target, so the largest is used.
        #expect( EquatorialGridOverlay.niceStep( span: 1000, candidates: [ 1, 2, 5, 10 ], targetCount: 5 ) == 10 )
    }

    @Test
    func niceStepIsNilForANonPositiveSpan() throws
    {
        #expect( EquatorialGridOverlay.niceStep( span: 0, candidates: [ 1, 2, 5 ], targetCount: 5 ) == nil )
    }

    @Test
    func formatsRightAscensionInHoursAndMinutes() throws
    {
        // 83.8° = 5h 35.2m; at a 0.5° (2 min) step the precision is hours+minutes.
        #expect( EquatorialGridOverlay.formatRA( degrees: 83.8, stepDegrees: 0.5 ) == "5h 35m" )
    }

    @Test
    func padsRightAscensionMinutesToTwoDigits() throws
    {
        // 76.0° = 5h 04m — the minutes are zero-padded.
        #expect( EquatorialGridOverlay.formatRA( degrees: 76.0, stepDegrees: 0.5 ) == "5h 04m" )
    }

    @Test
    func formatsRightAscensionInHoursForACoarseStep() throws
    {
        // A 15° (1 hour) step drops to whole hours.
        #expect( EquatorialGridOverlay.formatRA( degrees: 90, stepDegrees: 15 ) == "6h" )
    }

    @Test
    func formatsRightAscensionWithSecondsForAFineStep() throws
    {
        // A 0.001° (~0.24 s) step shows seconds: 83.8° = 5h 35m 12s.
        #expect( EquatorialGridOverlay.formatRA( degrees: 83.8, stepDegrees: 0.001 ) == "5h 35m 12s" )
    }

    @Test
    func formatsDeclinationInDegreesAndArcminutes() throws
    {
        // -5.4° = -5° 24′; at a ~0.33° (20′) step the precision is degrees+arcmin.
        #expect( EquatorialGridOverlay.formatDec( degrees: -5.4, stepDegrees: 0.3333 ) == "-5°24′" )
    }

    @Test
    func padsDeclinationArcminutesToTwoDigits() throws
    {
        // -5.0° = -5° 00′ — arcminutes are zero-padded; a round value keeps its sign.
        #expect( EquatorialGridOverlay.formatDec( degrees: -5.0, stepDegrees: 0.3333 ) == "-5°00′" )
    }

    @Test
    func formatsDeclinationInDegreesForACoarseStep() throws
    {
        // A 1° step drops to whole degrees, with an explicit sign.
        #expect( EquatorialGridOverlay.formatDec( degrees: 20, stepDegrees: 1 ) == "+20°" )
    }
}
