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

/// Tests for ``SessionMetricSeries``: turning the per-file session samples into
/// ordered, plottable points for one metric, and for ``SessionMetric`` reading
/// the right value out of a sample.
@Suite( "SessionMetricSeries" )
struct SessionMetricSeriesTests
{
    /// Builds a sample, defaulting every metric to absent so each test names only
    /// the fields it cares about.
    private func sample( name: String, date: Date? = nil, stars: Int? = nil, noise: Double? = nil, fwhm: Double? = nil, hfr: Double? = nil, eccentricity: Double? = nil, background: Double? = nil, exposure: Double? = nil ) -> SessionMetricSample
    {
        SessionMetricSample( id: UUID(), name: name, observationDate: date, starCount: stars, noise: noise, fwhm: fwhm, hfr: hfr, eccentricity: eccentricity, background: background, exposure: exposure )
    }

    /// A date `seconds` after a fixed reference, so ordering tests read clearly.
    private func date( _ seconds: TimeInterval ) -> Date
    {
        Date( timeIntervalSinceReferenceDate: seconds )
    }

    /// No samples yield no points.
    @Test
    func emptyInputYieldsNoPoints()
    {
        #expect( SessionMetricSeries.points( for: .stars, from: [] ).isEmpty )
    }

    /// When every sample carries an observation date, the points are ordered
    /// chronologically regardless of the input order, and numbered 1…N.
    @Test
    func ordersByObservationDateWhenAllPresent()
    {
        let samples =
            [
                self.sample( name: "c", date: self.date( 300 ), stars: 30 ),
                self.sample( name: "a", date: self.date( 100 ), stars: 10 ),
                self.sample( name: "b", date: self.date( 200 ), stars: 20 ),
            ]
        let points = SessionMetricSeries.points( for: .stars, from: samples )

        #expect( points.map { $0.name }     == [ "a", "b", "c" ] )
        #expect( points.map { $0.position } == [ 1, 2, 3 ] )
        #expect( points.map { $0.value }    == [ 10, 20, 30 ] )
    }

    /// When any sample lacks a date, the acquisition (opened) order is preserved
    /// rather than partially sorting a mix of dated and undated frames.
    @Test
    func preservesOpenedOrderWhenAnyDateMissing()
    {
        let samples =
            [
                self.sample( name: "first",  date: self.date( 300 ), stars: 30 ),
                self.sample( name: "second", date: nil,              stars: 20 ),
                self.sample( name: "third",  date: self.date( 100 ), stars: 10 ),
            ]
        let points = SessionMetricSeries.points( for: .stars, from: samples )

        #expect( points.map { $0.name }     == [ "first", "second", "third" ] )
        #expect( points.map { $0.position } == [ 1, 2, 3 ] )
    }

    /// A sample missing the requested metric is skipped, but its position in the
    /// session is kept — so a ruined frame shows as a gap rather than shifting the
    /// others.
    @Test
    func skipsSamplesMissingTheMetricButKeepsTheirPosition()
    {
        let samples =
            [
                self.sample( name: "a", fwhm: 2.0 ),
                self.sample( name: "b", fwhm: nil ),
                self.sample( name: "c", fwhm: 4.0 ),
            ]
        let points = SessionMetricSeries.points( for: .fwhm, from: samples )

        #expect( points.map { $0.name }     == [ "a", "c" ] )
        #expect( points.map { $0.position } == [ 1, 3 ] )
        #expect( points.map { $0.value }    == [ 2.0, 4.0 ] )
    }

    /// Each metric reads its own field out of a sample; the star count is exposed
    /// as a `Double` for the shared numeric axis, and the background is scaled from
    /// its 0…1 fraction to a percentage.
    @Test
    func metricReadsItsOwnValueFromASample()
    {
        let sample = self.sample( name: "x", stars: 42, noise: 3.5, fwhm: 2.1, hfr: 1.7, eccentricity: 0.3, background: 0.25 )

        #expect( SessionMetric.stars.value( in: sample )        == 42 )
        #expect( SessionMetric.noise.value( in: sample )        == 3.5 )
        #expect( SessionMetric.fwhm.value( in: sample )         == 2.1 )
        #expect( SessionMetric.hfr.value( in: sample )          == 1.7 )
        #expect( SessionMetric.eccentricity.value( in: sample ) == 0.3 )
        #expect( SessionMetric.background.value( in: sample )   == 25 )
    }

    /// A metric absent from the sample reads as `nil`.
    @Test
    func metricIsNilWhenAbsentFromTheSample()
    {
        let sample = self.sample( name: "x" )

        #expect( SessionMetric.stars.value( in: sample )      == nil )
        #expect( SessionMetric.noise.value( in: sample )      == nil )
        #expect( SessionMetric.background.value( in: sample ) == nil )
    }

    /// The cumulative SNR curve rises as √(running integration / reference): three
    /// one-hour frames against a one-hour reference reach 1, √2, √3.
    @Test
    func cumulativeSNRRisesAsRootOfIntegration()
    {
        let samples =
            [
                self.sample( name: "a", exposure: 3600 ),
                self.sample( name: "b", exposure: 3600 ),
                self.sample( name: "c", exposure: 3600 ),
            ]
        let points = SessionMetricSeries.cumulativeRelativeSNRPoints( from: samples, referenceSeconds: 3600 )

        #expect( points.map { $0.position } == [ 1, 2, 3 ] )
        #expect( abs( points[ 0 ].value - 1 )                  < 1e-9 )
        #expect( abs( points[ 1 ].value - 2.0.squareRoot() )   < 1e-9 )
        #expect( abs( points[ 2 ].value - 3.0.squareRoot() )   < 1e-9 )
    }

    /// A frame without an exposure contributes nothing to the running integration
    /// and gets no point, but keeps its position.
    @Test
    func cumulativeSNRSkipsFramesWithoutExposure()
    {
        let samples =
            [
                self.sample( name: "a", exposure: 3600 ),
                self.sample( name: "b", exposure: nil ),
                self.sample( name: "c", exposure: 3600 ),
            ]
        let points = SessionMetricSeries.cumulativeRelativeSNRPoints( from: samples, referenceSeconds: 3600 )

        #expect( points.map { $0.position } == [ 1, 3 ] )
        #expect( abs( points[ 1 ].value - 2.0.squareRoot() ) < 1e-9 )
    }

    /// The acquisition-order domain spans the frames with a small margin each side,
    /// so the points nearly fill the plot rather than leaving empty end slots.
    @Test
    func acquisitionDomainMarginsTheFrameRange()
    {
        let domain = SessionMetricSeries.acquisitionDomain( frameCount: 5 )

        #expect( abs( domain.lowerBound - 0.88 ) < 1e-9 )
        #expect( abs( domain.upperBound - 5.12 ) < 1e-9 )
    }

    /// A single frame gets a symmetric unit window (it cannot span a range).
    @Test
    func acquisitionDomainForOneFrameIsCentred()
    {
        #expect( SessionMetricSeries.acquisitionDomain( frameCount: 1 ) == 0.5 ... 1.5 )
        #expect( SessionMetricSeries.acquisitionDomain( frameCount: 0 ) == 0.5 ... 1.5 )
    }

    // MARK: - Overlay rescaling

    /// Rescaling maps a series' own min–max linearly onto the target range,
    /// preserving positions — so an overlay fills the primary's plot area and its
    /// trend stays comparable.
    @Test
    func rescaleMapsMinMaxOntoTheTargetRange()
    {
        let points   = SessionMetricSeries.points( for: .fwhm, from: [ self.sample( name: "a", fwhm: 1 ), self.sample( name: "b", fwhm: 3 ), self.sample( name: "c", fwhm: 5 ) ] )
        let rescaled = SessionMetricSeries.rescale( points, to: 0 ... 100 )

        #expect( rescaled.map { $0.position } == [ 1, 2, 3 ] )
        #expect( rescaled.map { $0.value }    == [ 0, 50, 100 ] )
    }

    /// A non-zero constant series has no trend to stretch, so it maps to the target
    /// range's midpoint.
    @Test
    func rescaleMapsANonZeroConstantSeriesToTheMidpoint()
    {
        let points   = SessionMetricSeries.points( for: .stars, from: [ self.sample( name: "a", stars: 4 ), self.sample( name: "b", stars: 4 ) ] )
        let rescaled = SessionMetricSeries.rescale( points, to: 0 ... 10 )

        #expect( rescaled.map { $0.value } == [ 5, 5 ] )
    }

    /// An all-zero constant series pins to the floor (the range's lower bound), so
    /// it reads as zero rather than floating mid-plot.
    @Test
    func rescaleMapsAZeroConstantSeriesToTheFloor()
    {
        let points   = SessionMetricSeries.points( for: .stars, from: [ self.sample( name: "a", stars: 0 ), self.sample( name: "b", stars: 0 ) ] )
        let rescaled = SessionMetricSeries.rescale( points, to: 2 ... 10 )

        #expect( rescaled.map { $0.value } == [ 2, 2 ] )
    }
}
