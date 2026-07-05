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

/// Tests for ``IntegrationSummary``: the √t relative-SNR figures derived from a
/// session's total integration time, referenced to one hour.
@Suite( "IntegrationSummary" )
struct IntegrationSummaryTests
{
    /// At exactly the one-hour reference, the relative SNR is 1, there is no gain,
    /// and the noise is the full 100 % of the reference.
    @Test
    func atTheHourReferenceIsUnity() throws
    {
        let summary = try #require( IntegrationSummary( exposures: [ 3600 ], reference: .hours( 1 ) ) )

        #expect( summary.relativeSNR   == 1 )
        #expect( summary.gain          == 0 )
        #expect( summary.relativeNoise == 1 )
    }

    /// Four hours against the one-hour reference doubles the SNR (√4 = 2), a +100 %
    /// gain, and halves the noise.
    @Test
    func fourHoursVersusOneDoublesSNR() throws
    {
        let summary = try #require( IntegrationSummary( exposures: [ 3600, 3600, 3600, 3600 ], reference: .hours( 1 ) ) )

        #expect( summary.relativeSNR   == 2 )
        #expect( summary.gain          == 1 )
        #expect( summary.relativeNoise == 0.5 )
    }

    /// The target hours drive the reference: two hours of data against a four-hour
    /// target is √(2/4) of the way there.
    @Test
    func targetHoursSetTheReference() throws
    {
        let summary = try #require( IntegrationSummary( exposures: [ 2 * 3600.0 ], reference: .hours( 4 ) ) )

        #expect( summary.referenceSeconds == 4 * 3600 )
        #expect( abs( summary.relativeSNR - ( 0.5 ).squareRoot() ) < 1e-9 )
    }

    /// The single-frame reference reads a session of `N` equal frames as `√N` —
    /// e.g. five 10 s subs give √5, independent of the sub length.
    @Test
    func singleFrameReferenceIsRootN() throws
    {
        let summary = try #require( IntegrationSummary( exposures: [ 10, 10, 10, 10, 10 ], reference: .singleFrame ) )

        #expect( summary.totalSeconds == 50 )
        #expect( abs( summary.relativeSNR - 5.0.squareRoot() ) < 1e-9 )
    }

    /// The single-frame reference uses the mean sub-exposure, so unequal subs still
    /// resolve to √N (two frames → √2).
    @Test
    func singleFrameReferenceUsesMeanSub() throws
    {
        let summary = try #require( IntegrationSummary( exposures: [ 10, 30 ], reference: .singleFrame ) )

        #expect( abs( summary.relativeSNR - 2.0.squareRoot() ) < 1e-9 )
    }

    /// The exposures initializer sums only the positive, present exposures, and
    /// counts them.
    @Test
    func sumsPositivePresentExposures() throws
    {
        let summary = try #require( IntegrationSummary( exposures: [ 300, nil, 300, -5, 0 ], reference: .hours( 1 ) ) )

        #expect( summary.totalSeconds == 600 )
        #expect( summary.frameCount   == 2 )
    }

    /// With no positive exposure — none present, or a non-positive total — there is
    /// no meaningful summary.
    @Test
    func noPositiveExposureHasNoSummary()
    {
        #expect( IntegrationSummary( exposures: [ nil, nil ], reference: .hours( 1 ) )        == nil )
        #expect( IntegrationSummary( exposures: [], reference: .hours( 1 ) )                  == nil )
        #expect( IntegrationSummary( totalSeconds: 0, frameCount: 0, reference: .hours( 1 ) ) == nil )
    }
}
