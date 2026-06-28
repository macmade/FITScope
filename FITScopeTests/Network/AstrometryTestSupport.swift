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

/// A scripted ``AstrometryTransport`` for exercising ``AstrometryClient`` and
/// ``PlateSolveSession`` without any live network.
///
/// Every request is recorded for later assertions, and the response is produced
/// by an injected handler that receives the request and a per-path call index —
/// so a test can return different bodies on successive polls of the same
/// endpoint (e.g. `solving` then `success`). It is an `actor` so the recorded
/// requests and call counts stay race-free across the client's concurrent use.
actor MockAstrometryTransport: AstrometryTransport
{
    /// Produces a response for a request. The second argument is the zero-based
    /// number of times this request's path has already been seen, so a handler
    /// can advance a polled endpoint through a sequence of states.
    ///
    /// - Returns: The HTTP status code and the raw response body.
    typealias Handler = @Sendable ( URLRequest, Int ) throws -> ( status: Int, body: Data )

    /// The injected response producer.
    private let handler: Handler

    /// The number of requests seen per URL path, driving the handler's index.
    private var callCounts: [ String: Int ] = [ : ]

    /// Every request the client has made, in order, for assertions.
    private( set ) var requests: [ URLRequest ] = []

    /// Creates a transport driven by the given handler.
    ///
    /// - Parameter handler: Produces a status and body per request and per-path
    ///   call index.
    init( handler: @escaping Handler )
    {
        self.handler = handler
    }

    func data( for request: URLRequest ) async throws -> ( Data, HTTPURLResponse )
    {
        let path  = request.url?.path ?? ""
        let index = self.callCounts[ path, default: 0 ]

        self.callCounts[ path ] = index + 1

        self.requests.append( request )

        let ( status, body ) = try self.handler( request, index )

        guard let url = request.url,
              let response = HTTPURLResponse( url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil )
        else
        {
            throw URLError( .badServerResponse )
        }

        return ( body, response )
    }
}

/// Recorded JSON response bodies from the Astrometry.net API, used as fixtures.
///
/// The shapes mirror the documented responses at
/// `https://astrometry.net/doc/net/api.html`, captured here so the client's
/// decoding is verified against the real wire format without a live call.
enum AstrometryFixtures
{
    /// A successful `login`, carrying the session key.
    static let loginSuccess = Self.data( #"{"status": "success", "message": "authenticated user: ", "session": "sess-123"}"# )

    /// A failed `login`, carrying an error message instead of a session.
    static let loginError = Self.data( #"{"status": "error", "errormessage": "bad apikey"}"# )

    /// A successful `upload` / `url_upload`, carrying the submission id.
    static let uploadSuccess = Self.data( #"{"status": "success", "subid": 16714, "hash": "deadbeef"}"# )

    /// A submission whose job has not yet been created (a `null` placeholder).
    static let submissionPending = Self.data( #"{"jobs": [null], "job_calibrations": [], "user": 1, "user_images": [1051223]}"# )

    /// A submission whose job exists and is calibrated.
    static let submissionReady = Self.data( #"{"jobs": [42], "job_calibrations": [[42, 99]], "user": 1, "user_images": [1051223]}"# )

    /// A job still being solved.
    static let jobSolving = Self.data( #"{"status": "solving"}"# )

    /// A job that solved successfully.
    static let jobSuccess = Self.data( #"{"status": "success"}"# )

    /// A job that failed to solve.
    static let jobFailure = Self.data( #"{"status": "failure"}"# )

    /// The calibration of a solved job.
    static let calibration = Self.data( #"{"parity": 1.0, "orientation": 105.74942079091929, "pixscale": 1.0906710701159739, "radius": 0.8106715896625917, "ra": 169.96633791366915, "dec": 13.221011585315143}"# )

    /// The catalogue objects identified in a solved field.
    static let objectsInField = Self.data( #"{"objects_in_field": ["NGC 3628", "M 66", "NGC 3627"]}"# )

    /// The raw bytes of a real WCS-bearing FITS file, standing in for the
    /// `wcs_file` download. `MonoImage.fits` carries `CRVAL1`/`CRVAL2` and a `CD`
    /// matrix, so parsing it yields a populated ``FITSMetadata``.
    static var wcsFITS: Data
    {
        get throws
        {
            try Data( contentsOf: TestFixtures.monoImage )
        }
    }

    /// Encodes a JSON string literal as UTF-8 data.
    private static func data( _ json: String ) -> Data
    {
        Data( json.utf8 )
    }
}
