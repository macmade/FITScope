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

/// Tests for ``ImageWeighting``: turning per-image metrics and a formula into a
/// per-image weight, with set-wide min/max normalization.
@Suite( "ImageWeighting" )
struct ImageWeightingTests
{
    /// A formula that needs set-wide min/max cannot rank a single image, so its
    /// weight is absent.
    @Test
    func singleImageWithSetWideFormulaHasNoWeight() throws
    {
        let formula = try WeightFormula( source: "FWHM - FWHMMin" )
        let weights = ImageWeighting.weights( for: [ [ .fwhm: 2 ] ], using: formula )

        #expect( weights == [ nil ] )
    }

    /// With two images, a min/max-normalized formula ranks them across the set:
    /// the minimum normalizes to 0, the maximum to 1.
    @Test
    func normalizesEachImageAcrossTheSet() throws
    {
        let formula = try WeightFormula( source: "100 * ( FWHM - FWHMMin ) / ( FWHMMax - FWHMMin )" )
        let weights = ImageWeighting.weights( for: [ [ .fwhm: 2 ], [ .fwhm: 4 ] ], using: formula )

        #expect( weights == [ 0, 100 ] )
    }

    /// When every image shares the same value for a metric, its set-wide range is
    /// degenerate; the normalized term is then a neutral 0.5 rather than `NaN`.
    @Test
    func degenerateMetricRangeNormalizesToNeutralHalf() throws
    {
        let formula = try WeightFormula( source: "100 * ( FWHM - FWHMMin ) / ( FWHMMax - FWHMMin )" )
        let weights = ImageWeighting.weights( for: [ [ .fwhm: 3 ], [ .fwhm: 3 ] ], using: formula )

        #expect( weights == [ 50, 50 ] )
    }

    /// An image missing a metric the formula requires gets no weight, and is
    /// excluded from the set-wide min/max the others are ranked against.
    @Test
    func imageMissingARequiredMetricHasNoWeightAndIsExcluded() throws
    {
        let formula = try WeightFormula( source: "FWHM - FWHMMin" )
        let weights = ImageWeighting.weights( for: [ [ .fwhm: 2 ], [ .fwhm: 4 ], [ : ] ], using: formula )

        #expect( weights == [ 0, 2, nil ] )
    }

    /// A purely per-image formula (no set-wide variables) is computable for a
    /// single image — the single-image guard only applies to set-wide ranking.
    @Test
    func perImageOnlyFormulaComputesForASingleImage() throws
    {
        let formula = try WeightFormula( source: "100 - FWHM" )
        let weights = ImageWeighting.weights( for: [ [ .fwhm: 3 ] ], using: formula )

        #expect( weights == [ 97 ] )
    }

    /// End-to-end with the default formula: an image at the midpoint of every
    /// metric across the set scores 75 (the documented midpoint value).
    @Test
    func defaultFormulaScoresMidpointImageSeventyFive() throws
    {
        let formula = try WeightFormula( source: WeightFormula.defaultExpression )
        let images: [ ImageWeighting.Metrics ] =
            [
                [ .fwhm: 1, .eccentricity: 0.1, .snrWeight: 10 ],
                [ .fwhm: 2, .eccentricity: 0.2, .snrWeight: 20 ],
                [ .fwhm: 3, .eccentricity: 0.3, .snrWeight: 30 ],
            ]
        let weights = ImageWeighting.weights( for: images, using: formula )
        let middle  = try #require( weights[ 1 ] )

        #expect( abs( middle - 75 ) < 1e-9 )
    }

    // MARK: - Metrics from detection results

    /// A measured image maps its star-field medians, star count and SNR weight to
    /// the matching formula variables.
    @Test
    func metricsMapsStarFieldAndSignalToNoise() throws
    {
        let field   = StarField( stars: [ Star( x: 0, y: 0, flux: 1, hfr: 2, fwhm: 3, eccentricity: 0.4 ) ] )
        let snr     = SignalToNoise( noise: 2 )
        let metrics = ImageWeighting.metrics( starField: field, signalToNoise: snr )

        #expect( metrics[ .fwhm ]         == 3 )
        #expect( metrics[ .hfr ]          == 2 )
        #expect( metrics[ .eccentricity ] == 0.4 )
        #expect( metrics[ .stars ]        == 1 )
        #expect( metrics[ .snrWeight ]    == 0.25 )
    }

    /// With neither detection nor an SNR estimate, no metric is available.
    @Test
    func metricsIsEmptyWithoutSources() throws
    {
        #expect( ImageWeighting.metrics( starField: nil, signalToNoise: nil ).isEmpty )
    }

    /// A star-less field still reports a (zero) star count, but no medians; a
    /// missing SNR estimate contributes no SNR weight.
    @Test
    func metricsFromStarlessFieldHasOnlyAStarCount() throws
    {
        let metrics = ImageWeighting.metrics( starField: StarField( stars: [] ), signalToNoise: nil )

        #expect( metrics[ .stars ]     == 0 )
        #expect( metrics[ .fwhm ]      == nil )
        #expect( metrics[ .snrWeight ] == nil )
    }
}
