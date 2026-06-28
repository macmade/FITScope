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

import Foundation
import SwiftAstro

/// Computes a per-image weight from a ``WeightFormula`` and the metrics measured
/// for each open image, ranking the images against one another.
///
/// The formula's `…Min` / `…Max` placeholders are **set-wide**: the minimum and
/// maximum of a metric across the whole set, so a `( x − min ) / ( max − min )`
/// term normalizes each image to where it falls within the set (à la PixInsight's
/// SubframeSelector). Two consequences follow:
///
/// - A formula that uses any set-wide placeholder cannot rank a lone image — the
///   set's min and max are then the same value — so such an image gets **no
///   weight**. A purely per-image formula has no such dependency and is computed
///   even for a single image.
/// - When every image shares the same value for a metric, that metric's set-wide
///   range is degenerate (`max == min`). Rather than let the normalization divide
///   by zero, the `…Min` / `…Max` bindings are spread symmetrically around the
///   common value so the normalized term evaluates to a neutral **0.5** — the
///   metric simply stops discriminating between images instead of poisoning the
///   whole weight with `NaN`.
///
/// An image missing a metric the formula needs gets no weight and is excluded
/// from the set-wide min/max the others are ranked against.
public enum ImageWeighting
{
    /// The metrics measured for one image, keyed by the formula's per-image
    /// (non-aggregate) variables. Only the metrics actually measured are present;
    /// a missing key means the metric is unavailable for that image.
    public typealias Metrics = [ WeightFormula.Variable: Double ]

    /// Half the width of the symmetric bracket placed around a degenerate metric's
    /// common value, chosen so the normalized term resolves to exactly `0.5`.
    private static let degenerateHalfWidth = 0.5

    /// Maps an image's detection results to the per-image formula variables.
    ///
    /// Only the metrics actually available become entries: the star-field medians
    /// and count come from detection, the SNR weight from the noise estimate. A
    /// star-less field still reports a zero count, but no medians.
    ///
    /// - Parameters:
    ///   - starField:     The detected stars and their medians, or `nil` when
    ///                    detection has not run or found nothing.
    ///   - signalToNoise: The image's noise estimate, or `nil` when unavailable.
    /// - Returns: The metrics available for the image.
    public static func metrics( starField: StarField?, signalToNoise: SignalToNoise? ) -> Metrics
    {
        var metrics: Metrics = [ : ]

        metrics[ .fwhm ]         = starField?.medianFWHM
        metrics[ .hfr ]          = starField?.medianHFR
        metrics[ .eccentricity ] = starField?.medianEccentricity
        metrics[ .stars ]        = starField.map { Double( $0.count ) }
        metrics[ .snrWeight ]    = signalToNoise?.weight

        return metrics
    }

    /// Computes the weight of every image, in the same order as `images`.
    ///
    /// - Parameters:
    ///   - images:  The per-image metrics, one entry per open image.
    ///   - formula: The weighting formula.
    /// - Returns: The weight for each image, or `nil` where it is absent (the
    ///   image lacks a required metric, or the set cannot be ranked).
    public static func weights( for images: [ Metrics ], using formula: WeightFormula ) -> [ Double? ]
    {
        let referenced  = formula.referencedVariables
        let usesSetWide = referenced.contains { Self.isAggregate( $0 ) }

        // Every image must provide the base metric of each referenced variable —
        // both the bare per-image metrics and the bases the set-wide aggregates
        // are derived from.
        let requiredBases = Set( referenced.map { Self.base( of: $0 ) } )

        let eligibleIndices = images.indices.filter
        {
            index in requiredBases.allSatisfy { images[ index ][ $0 ] != nil }
        }

        // A set-wide formula needs at least two ranked images to be meaningful.
        if usesSetWide, eligibleIndices.count < 2
        {
            return images.map { _ in nil }
        }

        let ranges = Self.setWideRanges( bases: requiredBases, eligibleIndices: eligibleIndices, images: images )

        return images.indices.map
        {
            index in

            guard eligibleIndices.contains( index )
            else
            {
                return nil
            }

            let bindings = Self.bindings( referenced: referenced, metrics: images[ index ], ranges: ranges )
            let weight   = formula.evaluate( bindings )

            return weight.isFinite ? weight : nil
        }
    }

    /// The set-wide minimum and maximum of each base metric over the eligible
    /// images.
    ///
    /// - Parameters:
    ///   - bases:           The base metrics to summarize.
    ///   - eligibleIndices: The images contributing to the ranges.
    ///   - images:          All images' metrics.
    /// - Returns: The `(min, max)` per base metric.
    private static func setWideRanges( bases: Set< WeightFormula.Variable >, eligibleIndices: [ Int ], images: [ Metrics ] ) -> [ WeightFormula.Variable: ( min: Double, max: Double ) ]
    {
        bases.reduce( into: [ : ] )
        {
            ranges, base in

            let values = eligibleIndices.compactMap { images[ $0 ][ base ] }

            guard let minimum = values.min(), let maximum = values.max()
            else
            {
                return
            }

            ranges[ base ] = ( minimum, maximum )
        }
    }

    /// Builds the variable bindings for one image: its own value for each
    /// per-image variable, and the set-wide minimum/maximum for each aggregate —
    /// spread around the common value when the range is degenerate so the
    /// normalized term is a neutral `0.5`.
    ///
    /// - Parameters:
    ///   - referenced: The variables the formula uses.
    ///   - metrics:    The image's own metrics.
    ///   - ranges:     The set-wide ranges per base metric.
    /// - Returns: The value to bind to each referenced variable.
    private static func bindings( referenced: Set< WeightFormula.Variable >, metrics: Metrics, ranges: [ WeightFormula.Variable: ( min: Double, max: Double ) ] ) -> [ WeightFormula.Variable: Double ]
    {
        referenced.reduce( into: [ : ] )
        {
            bindings, variable in

            guard Self.isAggregate( variable )
            else
            {
                bindings[ variable ] = metrics[ variable ]

                return
            }

            guard let range = ranges[ Self.base( of: variable ) ]
            else
            {
                return
            }

            if range.min == range.max
            {
                let common = range.min

                bindings[ variable ] = Self.isMaximum( variable ) ? common + Self.degenerateHalfWidth : common - Self.degenerateHalfWidth
            }
            else
            {
                bindings[ variable ] = Self.isMaximum( variable ) ? range.max : range.min
            }
        }
    }

    /// Whether a variable is a set-wide `…Min` / `…Max` aggregate.
    private static func isAggregate( _ variable: WeightFormula.Variable ) -> Bool
    {
        variable.rawValue.hasSuffix( "Min" ) || variable.rawValue.hasSuffix( "Max" )
    }

    /// Whether a variable is the set-wide `…Max` aggregate.
    private static func isMaximum( _ variable: WeightFormula.Variable ) -> Bool
    {
        variable.rawValue.hasSuffix( "Max" )
    }

    /// The per-image base metric behind a variable: the variable itself for a
    /// per-image metric, or the metric a `…Min` / `…Max` aggregate summarizes.
    private static func base( of variable: WeightFormula.Variable ) -> WeightFormula.Variable
    {
        guard Self.isAggregate( variable )
        else
        {
            return variable
        }

        let name = String( variable.rawValue.dropLast( 3 ) )

        return WeightFormula.Variable( rawValue: name ) ?? variable
    }
}
