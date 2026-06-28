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

/// The outcome of a successful plate solve: the job it came from, the
/// calibration, the catalogue objects in the field, and the full WCS parsed from
/// the solved `wcs.fits` (the basis for the object and grid overlays).
public struct PlateSolveResult: Sendable
{
    /// The astrometric calibration of a solved field, as returned by
    /// `jobs/JOBID/calibration`. Field names match the service's wire format.
    public struct Calibration: Decodable, Sendable, Equatable
    {
        /// The right ascension of the field centre, in decimal degrees.
        public let ra: Double

        /// The declination of the field centre, in decimal degrees.
        public let dec: Double

        /// The plate scale, in arc-seconds per pixel.
        public let pixscale: Double

        /// The orientation (position angle) of the field, in degrees east of north.
        public let orientation: Double

        /// The radius of the field, in degrees.
        public let radius: Double

        /// The image parity (+1 or −1), or `nil` when the service omits it.
        public let parity: Double?
    }

    /// The Astrometry.net job id that produced this solve.
    public let jobID: Int

    /// The field calibration (centre, scale, orientation, radius, parity).
    public let calibration: Calibration

    /// The catalogue objects identified in the field, possibly empty.
    public let objectsInField: [ String ]

    /// The full world-coordinate system parsed from the solved `wcs.fits`, or
    /// `nil` when it could not be downloaded or parsed.
    public let wcs: FITSMetadata?

    /// The public results page for this solve on the service, suitable for
    /// opening in a browser, or `nil` when it cannot be formed.
    public let resultsURL: URL?

    /// Creates a result.
    ///
    /// - Parameters:
    ///   - jobID:          The originating job id.
    ///   - calibration:    The field calibration.
    ///   - objectsInField: The identified catalogue objects.
    ///   - wcs:            The parsed WCS, if available.
    ///   - resultsURL:     The public results page, if available.
    public init( jobID: Int, calibration: Calibration, objectsInField: [ String ], wcs: FITSMetadata?, resultsURL: URL? )
    {
        self.jobID          = jobID
        self.calibration    = calibration
        self.objectsInField = objectsInField
        self.wcs            = wcs
        self.resultsURL     = resultsURL
    }
}
