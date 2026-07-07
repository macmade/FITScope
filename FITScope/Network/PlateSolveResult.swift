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

    /// A catalogue object identified in the solved field, with its position in the
    /// image, as returned by `jobs/JOBID/annotations`. The position is what the
    /// objects overlay draws each label at.
    public struct Annotation: Sendable, Equatable
    {
        /// The object's names (a single object can carry several), e.g.
        /// `["NGC 3628"]`. Usually one entry; the first is shown as the label.
        public let names: [ String ]

        /// The object's column position, in the solved image's pixel space
        /// (the Astrometry.net convention: 1-based, origin at the bottom-left).
        public let pixelX: Double

        /// The object's row position, in the solved image's pixel space
        /// (1-based, origin at the bottom-left, increasing upward).
        public let pixelY: Double

        /// The object's annotated radius, in pixels; `0` when the service does not
        /// provide one (e.g. a point source such as a catalogue star).
        public let radius: Double

        /// The object's catalogue type (e.g. `"ngc"`, `"ic"`, `"hd"`), or `nil`
        /// when the service omits it.
        public let type: String?

        /// The label to show for the object: its first name, or `nil` when it is
        /// unnamed.
        public var label: String?
        {
            self.names.first
        }

        /// Creates an annotation.
        ///
        /// - Parameters:
        ///   - names:  The object's names; the first is used as the label.
        ///   - pixelX: The column position, in solved-image pixel space.
        ///   - pixelY: The row position, in solved-image pixel space.
        ///   - radius: The annotated radius, in pixels (`0` when unspecified).
        ///   - type:   The catalogue type, if any.
        public init( names: [ String ], pixelX: Double, pixelY: Double, radius: Double, type: String? )
        {
            self.names  = names
            self.pixelX = pixelX
            self.pixelY = pixelY
            self.radius = radius
            self.type   = type
        }
    }

    /// The Astrometry.net job id that produced this solve.
    public let jobID: Int

    /// The field calibration (centre, scale, orientation, radius, parity).
    public let calibration: Calibration

    /// The catalogue objects identified in the field, possibly empty.
    public let objectsInField: [ String ]

    /// The identified objects with their positions in the image, possibly empty —
    /// the basis for the objects overlay.
    public let annotations: [ Annotation ]

    /// The full world-coordinate system parsed from the solved `wcs.fits`, or
    /// `nil` when it could not be downloaded or parsed.
    public let wcs: WorldCoordinateSystem?

    /// The public results page for this solve on the service, suitable for
    /// opening in a browser, or `nil` when it cannot be formed.
    public let resultsURL: URL?

    /// Creates a result.
    ///
    /// - Parameters:
    ///   - jobID:          The originating job id.
    ///   - calibration:    The field calibration.
    ///   - objectsInField: The identified catalogue objects.
    ///   - annotations:    The identified objects with their image positions.
    ///   - wcs:            The parsed WCS, if available.
    ///   - resultsURL:     The public results page, if available.
    public init( jobID: Int, calibration: Calibration, objectsInField: [ String ], annotations: [ Annotation ] = [], wcs: WorldCoordinateSystem?, resultsURL: URL? )
    {
        self.jobID          = jobID
        self.calibration    = calibration
        self.objectsInField = objectsInField
        self.annotations    = annotations
        self.wcs            = wcs
        self.resultsURL     = resultsURL
    }
}
