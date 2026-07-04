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

/// The relative signal-to-noise figures a session's total integration time buys,
/// referenced to one hour.
///
/// Stacking `N` equal frames improves the integrated signal-to-noise as the square
/// root of the total exposure — so `relativeSNR = √(total / 1 h)` and the noise
/// falls as its reciprocal. This is the idealized `√t` model: it assumes every
/// frame contributes equally (same conditions, no clouds), so it is a *theoretical*
/// depth from integration time, independent of the measured per-frame quality the
/// charts trend.
public struct IntegrationSummary: Equatable, Sendable
{
    /// The session's total integration time, in seconds (always positive).
    public let totalSeconds: Double

    /// The number of frames that contributed a positive exposure (always ≥ 1).
    public let frameCount: Int

    /// The baseline the figures are compared against.
    public let reference: IntegrationReference

    /// Creates a summary from a total integration time and frame count.
    ///
    /// - Parameters:
    ///   - totalSeconds: The total integration, in seconds.
    ///   - frameCount:   The number of contributing frames.
    ///   - reference:    The baseline to compare against.
    /// - Returns: `nil` when the total or the frame count is not positive, which
    ///   has no meaningful signal-to-noise.
    public init?( totalSeconds: Double, frameCount: Int, reference: IntegrationReference )
    {
        guard totalSeconds > 0, frameCount > 0
        else
        {
            return nil
        }

        self.totalSeconds = totalSeconds
        self.frameCount   = frameCount
        self.reference    = reference
    }

    /// Creates a summary from per-frame exposures, summing those that are present
    /// and positive.
    ///
    /// - Parameters:
    ///   - exposures: The frames' exposure times (seconds); `nil` and non-positive
    ///     entries are ignored.
    ///   - reference: The baseline to compare against.
    /// - Returns: `nil` when no frame carries a positive exposure.
    public init?( exposures: [ Double? ], reference: IntegrationReference )
    {
        let positive = exposures.compactMap { $0 }.filter { $0 > 0 }

        self.init( totalSeconds: positive.reduce( 0, + ), frameCount: positive.count, reference: reference )
    }

    /// The reference integration the figures are relative to, in seconds: the mean
    /// sub-exposure for a single-frame reference (so a session reads as `√N`), or
    /// the target hours.
    public var referenceSeconds: Double
    {
        switch self.reference
        {
            case .singleFrame:    return self.totalSeconds / Double( self.frameCount )
            case .hours( let h ): return Double( h ) * 3600
        }
    }

    /// The total integration in hours.
    public var totalHours: Double
    {
        self.totalSeconds / 3600
    }

    /// The relative SNR versus the reference: `√(total / reference)`.
    public var relativeSNR: Double
    {
        ( self.totalSeconds / self.referenceSeconds ).squareRoot()
    }

    /// The SNR gain versus the reference, as a fraction (`relativeSNR − 1`); e.g.
    /// `1.0` means +100 %. Negative below the reference.
    public var gain: Double
    {
        self.relativeSNR - 1
    }

    /// The noise versus the reference, as a fraction of the reference noise
    /// (`1 / relativeSNR`); e.g. `0.5` means half the noise. Positive by
    /// construction, since the total is positive.
    public var relativeNoise: Double
    {
        1 / self.relativeSNR
    }
}
