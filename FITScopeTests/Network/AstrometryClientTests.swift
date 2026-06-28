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

/// Tests for ``AstrometryClient``: the Astrometry.net session / upload / status /
/// results flow. Every request is served by a scripted ``MockAstrometryTransport``
/// so the client's request encoding (the `request-json` form, the multipart
/// upload) and its response decoding and poll-loop are verified against the
/// documented wire format without ever touching the network.
@Suite( "AstrometryClient" )
struct AstrometryClientTests
{
    /// Records the progress phases a `solve` reports, in order.
    private actor ProgressRecorder
    {
        private( set ) var phases: [ AstrometryClient.Progress ] = []

        func record( _ phase: AstrometryClient.Progress )
        {
            self.phases.append( phase )
        }
    }

    /// `login` posts the API key as a percent-encoded `request-json` form field
    /// and returns the session key from the response.
    @Test
    func loginEncodesRequestJSONAndReturnsSession() async throws
    {
        let transport = MockAstrometryTransport { _, _ in ( 200, AstrometryFixtures.loginSuccess ) }
        let client    = AstrometryClient( transport: transport, pollInterval: .zero )
        let session   = try await client.login( apiKey: "my-key" )

        #expect( session == "sess-123" )

        let request = try #require( await transport.requests.first )

        #expect( request.url?.path == "/api/login" )
        #expect( request.httpMethod == "POST" )
        #expect( request.value( forHTTPHeaderField: "Content-Type" ) == "application/x-www-form-urlencoded" )

        let body       = try #require( request.httpBody )
        let bodyString = try #require( String( data: body, encoding: .utf8 ) )

        #expect( bodyString.hasPrefix( "request-json=" ) )

        let encoded = String( bodyString.dropFirst( "request-json=".count ) )
        let decoded = try #require( encoded.removingPercentEncoding )
        let payload = try JSONSerialization.jsonObject( with: Data( decoded.utf8 ) ) as? [ String: Any ]

        #expect( payload?[ "apikey" ] as? String == "my-key" )
    }

    /// A `login` whose response carries `status: error` throws rather than
    /// returning an empty session.
    @Test
    func loginThrowsOnErrorStatus() async
    {
        let transport = MockAstrometryTransport { _, _ in ( 200, AstrometryFixtures.loginError ) }
        let client    = AstrometryClient( transport: transport, pollInterval: .zero )

        await #expect( throws: AstrometryError.self )
        {
            _ = try await client.login( apiKey: "bad" )
        }
    }

    /// A non-2xx HTTP status throws, so a transport-level failure never decodes as
    /// a success.
    @Test
    func loginThrowsOnHTTPError() async
    {
        let transport = MockAstrometryTransport { _, _ in ( 500, Data() ) }
        let client    = AstrometryClient( transport: transport, pollInterval: .zero )

        await #expect( throws: AstrometryError.self )
        {
            _ = try await client.login( apiKey: "x" )
        }
    }

    /// `upload` sends the image as `multipart/form-data` with a `request-json`
    /// part carrying the session and a `file` part carrying the bytes, and returns
    /// the submission id.
    @Test
    func uploadSendsMultipartAndReturnsSubID() async throws
    {
        let transport = MockAstrometryTransport { _, _ in ( 200, AstrometryFixtures.uploadSuccess ) }
        let client    = AstrometryClient( transport: transport, pollInterval: .zero )
        let subID     = try await client.upload( imageData: Data( "FITSDATA".utf8 ), fileName: "image.fits", session: "sess-123" )

        #expect( subID == 16714 )

        let request = try #require( await transport.requests.first )

        #expect( request.url?.path == "/api/upload" )
        #expect( request.httpMethod == "POST" )

        let contentType = try #require( request.value( forHTTPHeaderField: "Content-Type" ) )

        #expect( contentType.hasPrefix( "multipart/form-data; boundary=" ) )

        let body       = try #require( request.httpBody )
        let bodyString = try #require( String( data: body, encoding: .utf8 ) )

        #expect( bodyString.contains( "name=\"request-json\"" ) )
        #expect( bodyString.contains( "name=\"file\"" ) )
        #expect( bodyString.contains( "sess-123" ) )
        #expect( bodyString.contains( "image.fits" ) )
        #expect( bodyString.contains( "FITSDATA" ) )
    }

    /// The full solve flow logs in, uploads, polls the submission until a job
    /// appears, polls the job until it succeeds, and returns the calibration, the
    /// objects in field, and the parsed WCS — reporting each phase along the way.
    @Test
    func solveFlowPollsUntilSuccessAndReturnsResult() async throws
    {
        let transport = MockAstrometryTransport
        {
            request, index in

            switch request.url?.path
            {
                case "/api/login":                       return ( 200, AstrometryFixtures.loginSuccess )
                case "/api/upload":                      return ( 200, AstrometryFixtures.uploadSuccess )
                case "/api/submissions/16714":           return ( 200, index == 0 ? AstrometryFixtures.submissionPending : AstrometryFixtures.submissionReady )
                case "/api/jobs/42":                     return ( 200, index == 0 ? AstrometryFixtures.jobSolving : AstrometryFixtures.jobSuccess )
                case "/api/jobs/42/calibration":         return ( 200, AstrometryFixtures.calibration )
                case "/api/jobs/42/objects_in_field":    return ( 200, AstrometryFixtures.objectsInField )
                case let path? where path.hasPrefix( "/wcs_file/" ): return ( 200, try AstrometryFixtures.wcsFITS )
                default:                                 throw URLError( .unsupportedURL )
            }
        }

        let client   = AstrometryClient( transport: transport, pollInterval: .zero )
        let recorder = ProgressRecorder()
        let result   = try await client.solve( imageData: Data( "FITSDATA".utf8 ), fileName: "image.fits", apiKey: "key" )
        {
            phase in await recorder.record( phase )
        }

        #expect( result.jobID == 42 )
        #expect( abs( result.calibration.ra - 169.966_337_913 ) < 0.001 )
        #expect( abs( result.calibration.dec - 13.221_011_585 ) < 0.001 )
        #expect( result.calibration.pixscale > 1.0 )
        #expect( result.objectsInField.contains( "M 66" ) )
        #expect( result.objectsInField.count == 3 )

        #expect( result.resultsURL?.path == "/status/16714" )

        let wcs = try #require( result.wcs )

        #expect( abs( ( wcs.rightAscension ?? 0 ) - 182.625_706 ) < 0.001 )

        let phases = await recorder.phases

        #expect( phases == [ .loggingIn, .uploading, .solving ] )
    }

    /// A job that reports `failure` makes the solve throw, so a failed solve is
    /// surfaced rather than returning an empty result.
    @Test
    func solveThrowsWhenJobFails() async
    {
        let transport = MockAstrometryTransport
        {
            request, _ in

            switch request.url?.path
            {
                case "/api/login":             return ( 200, AstrometryFixtures.loginSuccess )
                case "/api/upload":            return ( 200, AstrometryFixtures.uploadSuccess )
                case "/api/submissions/16714": return ( 200, AstrometryFixtures.submissionReady )
                case "/api/jobs/42":           return ( 200, AstrometryFixtures.jobFailure )
                default:                       throw URLError( .unsupportedURL )
            }
        }

        let client = AstrometryClient( transport: transport, pollInterval: .zero )

        await #expect( throws: AstrometryError.self )
        {
            _ = try await client.solve( imageData: Data( "FITSDATA".utf8 ), fileName: "image.fits", apiKey: "key" )
        }
    }

    /// Downloading and parsing a solved job's `wcs.fits` yields a populated
    /// ``FITSMetadata`` — the WCS the overlays read.
    @Test
    func wcsMetadataParsesWCSKeywords() async throws
    {
        let transport = MockAstrometryTransport { _, _ in ( 200, try AstrometryFixtures.wcsFITS ) }
        let client    = AstrometryClient( transport: transport, pollInterval: .zero )
        let wcs       = try #require( await client.wcsMetadata( jobID: 42 ) )

        #expect( abs( ( wcs.rightAscension ?? 0 ) - 182.625_706 ) < 0.001 )
        #expect( abs( ( wcs.declination ?? 0 ) - 39.412_337 ) < 0.001 )
        #expect( ( wcs.pixelScale ?? 0 ) > 0 )
    }
}
