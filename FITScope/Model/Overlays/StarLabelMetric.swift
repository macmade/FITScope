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

/// The per-star measurement the stars overlay can label next to each detected
/// star.
///
/// The user chooses one in the Overlays preferences (defaulting to ``hfr``); the
/// overlay draws the chosen metric's value beside every star, or nothing for
/// ``none``. Backed by a stable `String` raw value so the choice round-trips
/// through `UserDefaults`.
public enum StarLabelMetric: String, CaseIterable, Identifiable, Sendable
{
    /// Draw no measurement label.
    case none

    /// Label each star with its half-flux radius (HFR), in pixels.
    case hfr

    /// Label each star with its full width at half maximum (FWHM), in pixels.
    case fwhm

    /// The stable identity, for `Identifiable` and SwiftUI pickers.
    public var id: String
    {
        self.rawValue
    }

    /// The human-readable name shown in the preferences picker.
    public var title: String
    {
        switch self
        {
            case .none: return "None"
            case .hfr:  return "HFR"
            case .fwhm: return "FWHM"
        }
    }

    /// The metric's value for a star, or `nil` for ``none`` (nothing to draw).
    ///
    /// - Parameter star: The detected star.
    /// - Returns: The half-flux radius or FWHM in pixels, or `nil`.
    public func value( for star: Star ) -> Double?
    {
        switch self
        {
            case .none: return nil
            case .hfr:  return star.hfr
            case .fwhm: return star.fwhm
        }
    }

    /// The label text for a star — the metric's value to a single decimal place —
    /// or `nil` when there is nothing to draw (``none``).
    ///
    /// - Parameter star: The detected star.
    /// - Returns: The formatted value (e.g. `"2.3"`), or `nil`.
    public func label( for star: Star ) -> String?
    {
        self.value( for: star ).map { Self.format( $0 ) }
    }

    /// Formats a metric value to a single decimal place, in the current locale.
    ///
    /// - Parameter value: The value, in pixels.
    /// - Returns: The value to one decimal place, e.g. `"2.3"`.
    public static func format( _ value: Double ) -> String
    {
        value.formatted( .number.precision( .fractionLength( 1 ) ) )
    }
}
