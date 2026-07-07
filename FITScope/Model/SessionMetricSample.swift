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

/// One open file's metrics, snapshotted for the session metric-trend charts.
///
/// A plain value type, decoupled from ``OpenFile`` and its `@MainActor` state, so
/// the charting logic (``SessionMetricSeries``) is pure and unit-testable. Each
/// metric is optional — a file only contributes to a series once its analysis has
/// produced that metric (a frame with no detected stars has no median shape
/// metrics, for instance).
public struct SessionMetricSample: Identifiable, Equatable, Sendable
{
    /// The originating file's identifier, carried through so a plotted point can
    /// be traced back to its file.
    public let id: UUID

    /// The file's display name, used to label its point.
    public let name: String

    /// The frame's acquisition time (`DATE-OBS`), or `nil` when the header carries
    /// no date. Used to order the session chronologically when every frame has one.
    public let observationDate: Date?

    /// The number of detected stars, or `nil` before detection has run.
    public let starCount: Int?

    /// The robust background noise (σ = 1.4826 × MAD, in ADU; lower is cleaner), or
    /// `nil` when no noise estimate is available.
    public let noise: Double?

    /// The median full-width-at-half-maximum in pixels, or `nil` without stars.
    public let fwhm: Double?

    /// The median half-flux radius in pixels, or `nil` without stars.
    public let hfr: Double?

    /// The median star eccentricity (0 round … ~1 elongated), or `nil` without
    /// stars.
    public let eccentricity: Double?

    /// The sky-background level as a fraction of the frame's value range (0…1), or
    /// `nil` when no background estimate exists (or the frame is flat). Surfaced as
    /// a relative measure so it is comparable across frames of differing bit depth.
    public let background: Double?

    /// The frame's exposure / integration time in seconds (`EXPTIME`), or `nil`
    /// when the header carries none. Feeds the session's integration-time SNR
    /// figures, not a plotted per-frame metric.
    public let exposure: Double?

    /// Creates a sample from already-measured values.
    ///
    /// - Parameters:
    ///   - id:              The originating file's identifier.
    ///   - name:            The file's display name.
    ///   - observationDate: The acquisition time, or `nil`.
    ///   - starCount:       The detected star count, or `nil`.
    ///   - noise:           The robust background noise σ (ADU), or `nil`.
    ///   - fwhm:            The median FWHM (px), or `nil`.
    ///   - hfr:             The median HFR (px), or `nil`.
    ///   - eccentricity:    The median eccentricity, or `nil`.
    ///   - background:      The relative sky-background level (0…1), or `nil`.
    ///   - exposure:        The exposure time in seconds, or `nil`.
    public init( id: UUID, name: String, observationDate: Date?, starCount: Int?, noise: Double?, fwhm: Double?, hfr: Double?, eccentricity: Double?, background: Double?, exposure: Double? )
    {
        self.id              = id
        self.name            = name
        self.observationDate = observationDate
        self.starCount       = starCount
        self.noise           = noise
        self.fwhm            = fwhm
        self.hfr             = hfr
        self.eccentricity    = eccentricity
        self.background      = background
        self.exposure        = exposure
    }
}

@MainActor
public extension SessionMetricSample
{
    /// Snapshots an open file's current metrics.
    ///
    /// Reads the same star-field medians and noise estimate the per-image weight
    /// uses, plus the star count and the acquisition date from the image metadata.
    /// Any metric the file's analysis has not (yet) produced is left `nil`.
    ///
    /// - Parameter file: The open file to snapshot.
    init( file: OpenFile )
    {
        let image     = file.image
        let starField = image?.starField

        self.init(
            id:              file.id,
            name:            file.displayName,
            observationDate: image?.observationDate,
            starCount:       starField.map { $0.count },
            noise:           image?.signalToNoise?.noise,
            fwhm:            starField?.medianFWHM,
            hfr:             starField?.medianHFR,
            eccentricity:    starField?.medianEccentricity,
            background:      image?.skyBackground?.relativeLevel,
            exposure:        image?.exposureTime
        )
    }
}
