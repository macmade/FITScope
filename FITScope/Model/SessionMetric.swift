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

/// A per-file metric that can be trended across an imaging session.
///
/// Each case knows how to read its value out of a ``SessionMetricSample``, how to
/// label itself, and which SF Symbol to show — the icons match those the Analysis
/// sidebar tab already uses for the same quantities, so the two panels read
/// consistently.
public enum SessionMetric: String, CaseIterable, Identifiable, Sendable
{
    /// The number of detected stars.
    case stars

    /// The median full-width-at-half-maximum (px).
    case fwhm

    /// The median half-flux radius (px).
    case hfr

    /// The median star eccentricity.
    case eccentricity

    /// The robust background noise (σ, in ADU).
    case noise

    /// The sky-background level, as a fraction of the frame's value range.
    case background

    /// A stable identifier, so the metric can drive a `SegmentedControlView`.
    public var id: String
    {
        self.rawValue
    }

    /// Whether the metric takes only whole-number values, so its chart axis should
    /// label integer ticks only (a fractional "0.5 stars" is meaningless).
    public var usesIntegerValues: Bool
    {
        self == .stars
    }

    /// The metric's short label, shown in the metric selector and as the chart's
    /// value-axis title.
    public var title: String
    {
        switch self
        {
            case .stars:        return "Stars"
            case .noise:        return "Noise"
            case .fwhm:         return "FWHM"
            case .hfr:          return "HFR"
            case .eccentricity: return "Eccentricity"
            case .background:   return "Background"
        }
    }

    /// The metric's value-axis title, carrying the unit where one applies — the
    /// noise is in ADU and the background reads as a percentage, so both are
    /// labelled accordingly.
    public var valueAxisTitle: String
    {
        switch self
        {
            case .noise:      return "Noise (ADU)"
            case .background: return "Background (%)"
            default:          return self.title
        }
    }

    /// The SF Symbol shown beside the metric, matching the Analysis tab's icons.
    public var systemImageName: String
    {
        switch self
        {
            case .stars:        return "sparkles"
            case .noise:        return "waveform"
            case .fwhm:         return "circle.dotted"
            case .hfr:          return "smallcircle.filled.circle"
            case .eccentricity: return "oval"
            case .background:   return "circle.lefthalf.filled"
        }
    }

    /// Reads this metric's value from a sample, or `nil` when the sample does not
    /// carry it. The star count is surfaced as a `Double` so every metric shares
    /// the chart's numeric value axis.
    ///
    /// - Parameter sample: The per-file sample to read.
    /// - Returns: The metric's value, or `nil` when unavailable.
    public func value( in sample: SessionMetricSample ) -> Double?
    {
        switch self
        {
            case .stars:        return sample.starCount.map { Double( $0 ) }
            case .noise:        return sample.noise
            case .fwhm:         return sample.fwhm
            case .hfr:          return sample.hfr
            case .eccentricity: return sample.eccentricity
            case .background:   return sample.background.map { $0 * 100 }
        }
    }

    /// Formats a value of this metric for a compact read-out: a whole number for
    /// star counts, a one-decimal percentage for the background, two decimals for
    /// the continuous shape and noise metrics.
    ///
    /// - Parameter value: The value to format.
    /// - Returns: The display string.
    public func formatted( _ value: Double ) -> String
    {
        switch self
        {
            case .stars:      return value.formatted( .number.precision( .fractionLength( 0 ) ) )
            case .background: return value.formatted( .number.precision( .fractionLength( 1 ) ) ) + "%"
            default:          return value.formatted( .number.precision( .fractionLength( 2 ) ) )
        }
    }
}
