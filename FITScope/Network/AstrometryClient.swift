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
import SwiftFITS

/// A client for the nova.astrometry.net web API: log in with the stored key,
/// upload an image, poll the submission and its job to completion, then read back
/// the calibration, the objects in field, and the solved WCS.
///
/// All network access goes through an injected ``AstrometryTransport``, so the
/// whole flow is exercised in tests against scripted responses without a live
/// connection. HTTPS is used so the sandboxed app's requests satisfy App
/// Transport Security.
public actor AstrometryClient
{
    /// A coarse phase of a plate solve, reported as ``solve(imageData:fileName:apiKey:hints:onProgress:)``
    /// progresses, so the UI can show what the long-running operation is doing.
    public enum Progress: Sendable, Equatable
    {
        /// Authenticating with the service.
        case loggingIn

        /// Uploading the image.
        case uploading

        /// Waiting for the service to solve the image.
        case solving
    }

    /// The transport requests are sent through.
    private let transport: AstrometryTransport

    /// The service root, e.g. `https://nova.astrometry.net`. API endpoints hang
    /// off `/api`; the WCS download hangs off `/wcs_file`.
    private let baseURL: URL

    /// How long to wait between polls of the submission and job status.
    private let pollInterval: Duration

    /// The default service root.
    public static let defaultBaseURL = URL( string: "https://nova.astrometry.net" ) ?? URL( fileURLWithPath: "/" )

    /// Creates a client.
    ///
    /// - Parameters:
    ///   - transport:    The HTTP transport. Defaults to a `URLSession`-backed
    ///                   transport; tests inject a scripted one.
    ///   - baseURL:      The service root. Defaults to ``defaultBaseURL``.
    ///   - pollInterval: The delay between status polls. Defaults to three
    ///                   seconds; tests pass `.zero` so polling does not wait.
    public init( transport: AstrometryTransport = URLSessionTransport(), baseURL: URL = AstrometryClient.defaultBaseURL, pollInterval: Duration = .seconds( 3 ) )
    {
        self.transport    = transport
        self.baseURL      = baseURL
        self.pollInterval = pollInterval
    }

    // MARK: - High-level flow

    /// Runs the full solve: log in, upload, poll until the job solves, then read
    /// back the calibration, objects, and WCS.
    ///
    /// The objects and WCS are best-effort — a failure to read either does not
    /// fail the solve, since the calibration alone is a useful result.
    ///
    /// - Parameters:
    ///   - imageData:  The image bytes to upload.
    ///   - fileName:   The file name to label the upload with.
    ///   - apiKey:     The Astrometry.net API key.
    ///   - hints:      The optional position and scale hints to steer the solve;
    ///                 empty by default, which runs a blind solve.
    ///   - onProgress: Called as each coarse phase begins.
    /// - Returns: The solved result.
    /// - Throws: ``AstrometryError`` on authentication, upload, or solve failure,
    ///   or `CancellationError` if the task is cancelled.
    public func solve( imageData: Data, fileName: String, apiKey: String, hints: PlateSolveHints = PlateSolveHints(), onProgress: ( @Sendable ( Progress ) async -> Void )? = nil ) async throws -> PlateSolveResult
    {
        guard apiKey.trimmingCharacters( in: .whitespacesAndNewlines ).isEmpty == false
        else
        {
            throw AstrometryError.missingAPIKey
        }

        await onProgress?( .loggingIn )

        let session = try await self.login( apiKey: apiKey )

        try Task.checkCancellation()
        await onProgress?( .uploading )

        let submissionID = try await self.upload( imageData: imageData, fileName: fileName, session: session, hints: hints )

        try Task.checkCancellation()
        await onProgress?( .solving )

        let jobID = try await self.awaitJobID( submissionID: submissionID )

        try await self.awaitSolved( jobID: jobID )

        let calibration = try await self.calibration( jobID: jobID )
        let objects     = ( try? await self.objectsInField( jobID: jobID ) ) ?? []
        let annotations = ( try? await self.annotations( jobID: jobID ) ) ?? []
        let wcs         = try? await self.wcsMetadata( jobID: jobID )

        return PlateSolveResult( jobID: jobID, calibration: calibration, objectsInField: objects, annotations: annotations, wcs: wcs, resultsURL: self.resultsURL( submissionID: submissionID ) )
    }

    // MARK: - Individual operations

    /// Authenticates with the API key and returns the session key.
    public func login( apiKey: String ) async throws -> String
    {
        let request                          = try self.formRequest( path: "login", payload: [ "apikey": apiKey ] )
        let response: AstrometryResponse.Login = try await self.decoded( request )

        guard response.status == "success", let session = response.session
        else
        {
            throw AstrometryError.authenticationFailed( response.errorMessage )
        }

        return session
    }

    /// Uploads the image as multipart form data and returns the submission id.
    ///
    /// - Parameters:
    ///   - imageData: The image bytes to upload.
    ///   - fileName:  The file name to label the upload with.
    ///   - session:   The authenticated session key.
    ///   - hints:     The optional position and scale hints, merged into the
    ///                `request-json`; empty by default.
    /// - Returns: The submission id.
    /// - Throws: ``AstrometryError`` if the endpoint is invalid or the upload fails.
    public func upload( imageData: Data, fileName: String, session: String, hints: PlateSolveHints = PlateSolveHints() ) async throws -> Int
    {
        guard let url = self.apiEndpoint( "upload" )
        else
        {
            throw AstrometryError.invalidResponse
        }

        let boundary    = "Boundary-\( UUID().uuidString )"
        let requestJSON = try Self.jsonString( from: Self.requestObject( session: session, hints: hints ) )

        var request = URLRequest( url: url )

        request.httpMethod = "POST"
        request.httpBody   = Self.multipartBody( boundary: boundary, requestJSON: requestJSON, fileName: fileName, fileData: imageData )

        request.setValue( "multipart/form-data; boundary=\( boundary )", forHTTPHeaderField: "Content-Type" )

        let response: AstrometryResponse.Upload = try await self.decoded( request )

        guard response.status == "success", let subid = response.subid
        else
        {
            throw AstrometryError.serviceError( response.errorMessage ?? "The upload was rejected." )
        }

        return subid
    }

    /// Polls the submission until its first job has been created, returning that
    /// job's id.
    public func awaitJobID( submissionID: Int ) async throws -> Int
    {
        while true
        {
            try Task.checkCancellation()

            guard let url = self.apiEndpoint( "submissions/\( submissionID )" )
            else
            {
                throw AstrometryError.invalidResponse
            }

            let status: AstrometryResponse.Submission = try await self.decoded( URLRequest( url: url ) )

            if let jobID = status.jobID
            {
                return jobID
            }

            try await Task.sleep( for: self.pollInterval )
        }
    }

    /// Polls the job until it reports success, throwing ``AstrometryError/solveFailed``
    /// if it reports failure.
    public func awaitSolved( jobID: Int ) async throws
    {
        while true
        {
            try Task.checkCancellation()

            guard let url = self.apiEndpoint( "jobs/\( jobID )" )
            else
            {
                throw AstrometryError.invalidResponse
            }

            let status: AstrometryResponse.Job = try await self.decoded( URLRequest( url: url ) )

            switch status.status
            {
                case "success": return
                case "failure": throw AstrometryError.solveFailed
                default:        try await Task.sleep( for: self.pollInterval )
            }
        }
    }

    /// Reads the calibration of a solved job.
    public func calibration( jobID: Int ) async throws -> PlateSolveResult.Calibration
    {
        guard let url = self.apiEndpoint( "jobs/\( jobID )/calibration" )
        else
        {
            throw AstrometryError.invalidResponse
        }

        return try await self.decoded( URLRequest( url: url ) )
    }

    /// Reads the catalogue objects identified in a solved field.
    public func objectsInField( jobID: Int ) async throws -> [ String ]
    {
        guard let url = self.apiEndpoint( "jobs/\( jobID )/objects_in_field" )
        else
        {
            throw AstrometryError.invalidResponse
        }

        let response: AstrometryResponse.ObjectsInField = try await self.decoded( URLRequest( url: url ) )

        return response.objects
    }

    /// Reads the annotated objects of a solved field — each with its pixel
    /// position — and maps them to ``PlateSolveResult/Annotation`` values for the
    /// objects overlay.
    public func annotations( jobID: Int ) async throws -> [ PlateSolveResult.Annotation ]
    {
        guard let url = self.apiEndpoint( "jobs/\( jobID )/annotations" )
        else
        {
            throw AstrometryError.invalidResponse
        }

        let response: AstrometryResponse.Annotations = try await self.decoded( URLRequest( url: url ) )

        return response.annotations.map
        {
            PlateSolveResult.Annotation( names: $0.names, pixelX: $0.pixelx, pixelY: $0.pixely, radius: $0.radius, type: $0.type )
        }
    }

    /// Downloads a solved job's `wcs.fits` and parses it into a neutral
    /// ``WorldCoordinateSystem``, or `nil` when it cannot be downloaded or parsed.
    /// The `wcs.fits` payload is itself a FITS file, so parsing it through
    /// ``FITSMetadata`` internally is expected; only the neutral WCS crosses the
    /// API boundary.
    public func wcsMetadata( jobID: Int ) async throws -> WorldCoordinateSystem?
    {
        guard let url = self.wcsEndpoint( jobID: jobID )
        else
        {
            return nil
        }

        let data = try await self.dataForSuccess( URLRequest( url: url ) )

        return Self.metadata( fromFITS: data )?.worldCoordinateSystem
    }

    // MARK: - Request building

    /// Builds a form-encoded POST whose `request-json` field carries `payload`,
    /// the convention every Astrometry.net API call uses.
    private func formRequest( path: String, payload: [ String: String ] ) throws -> URLRequest
    {
        guard let url = self.apiEndpoint( path )
        else
        {
            throw AstrometryError.invalidResponse
        }

        let json    = try Self.jsonString( from: payload )
        let encoded = json.addingPercentEncoding( withAllowedCharacters: .alphanumerics ) ?? json

        var request = URLRequest( url: url )

        request.httpMethod = "POST"
        request.httpBody   = Data( "request-json=\( encoded )".utf8 )

        request.setValue( "application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type" )

        return request
    }

    /// The URL of an `/api` endpoint, e.g. `login` or `jobs/42/calibration`.
    private func apiEndpoint( _ path: String ) -> URL?
    {
        URL( string: "\( self.baseURL.absoluteString )/api/\( path )" )
    }

    /// The URL of a solved job's `wcs.fits` download (served off the site root,
    /// not under `/api`).
    private func wcsEndpoint( jobID: Int ) -> URL?
    {
        URL( string: "\( self.baseURL.absoluteString )/wcs_file/\( jobID )" )
    }

    /// The public, browser-viewable status page for a submission.
    private func resultsURL( submissionID: Int ) -> URL?
    {
        URL( string: "\( self.baseURL.absoluteString )/status/\( submissionID )" )
    }

    // MARK: - Sending & decoding

    /// Sends a request and decodes its JSON body into the inferred type.
    private func decoded< T: Decodable >( _ request: URLRequest ) async throws -> T
    {
        let data = try await self.dataForSuccess( request )

        do
        {
            return try JSONDecoder().decode( T.self, from: data )
        }
        catch
        {
            throw AstrometryError.invalidResponse
        }
    }

    /// Sends a request and returns its body, throwing on a non-2xx status.
    private func dataForSuccess( _ request: URLRequest ) async throws -> Data
    {
        let ( data, response ) = try await self.transport.data( for: request )

        guard ( 200 ..< 300 ).contains( response.statusCode )
        else
        {
            throw AstrometryError.requestFailed( status: response.statusCode )
        }

        return data
    }

    // MARK: - Helpers

    /// The tolerance, in percent, put on an estimated plate scale (the `scale_err`
    /// of a `scale_type` `"ev"` hint) — generous enough to absorb rounding in the
    /// header-derived scale while still bounding the solve.
    private static let scaleErrorPercent = 20.0

    /// Builds the `request-json` object for an upload: the session key plus any
    /// available position and scale hints, mapped to the service's parameter names.
    ///
    /// The scale hint (`scale_est` in `arcsecperpix`, as an estimate with a
    /// percentage error) is added whenever a plate scale is known; the position
    /// hint (`center_ra`/`center_dec`/`radius`) is added only when all three are
    /// present. With no hints the object carries just the session, so the solve
    /// runs blind exactly as before.
    ///
    /// - Parameters:
    ///   - session: The authenticated session key.
    ///   - hints:   The hints to include.
    /// - Returns: The `request-json` object.
    static func requestObject( session: String, hints: PlateSolveHints ) -> [ String: Any ]
    {
        var object: [ String: Any ] = [ "session": session ]

        if let scale = hints.scaleEstimate
        {
            object[ "scale_units" ] = "arcsecperpix"
            object[ "scale_type" ]  = "ev"
            object[ "scale_est" ]   = scale
            object[ "scale_err" ]   = Self.scaleErrorPercent
        }

        if let ra = hints.centerRA, let dec = hints.centerDec, let radius = hints.radius
        {
            object[ "center_ra" ]  = ra
            object[ "center_dec" ] = dec
            object[ "radius" ]     = radius
        }

        return object
    }

    /// Serializes a string dictionary to a compact JSON string.
    private static func jsonString( from object: [ String: String ] ) throws -> String
    {
        let data = try JSONSerialization.data( withJSONObject: object )

        return String( decoding: data, as: UTF8.self )
    }

    /// Serializes a heterogeneous JSON object (string and numeric values) to a
    /// compact JSON string, for the upload's mixed-type `request-json`.
    private static func jsonString( from object: [ String: Any ] ) throws -> String
    {
        let data = try JSONSerialization.data( withJSONObject: object )

        return String( decoding: data, as: UTF8.self )
    }

    /// Assembles a `multipart/form-data` body with a `request-json` text part and
    /// a `file` part carrying the image bytes.
    private static func multipartBody( boundary: String, requestJSON: String, fileName: String, fileData: Data ) -> Data
    {
        var body = Data()

        let header =
            """
            --\( boundary )\r
            Content-Type: text/plain\r
            Content-Disposition: form-data; name="request-json"\r
            \r
            \( requestJSON )\r
            --\( boundary )\r
            Content-Type: application/octet-stream\r
            Content-Disposition: form-data; name="file"; filename="\( fileName )"\r
            \r

            """

        body.append( Data( header.utf8 ) )
        body.append( fileData )
        body.append( Data( "\r\n--\( boundary )--\r\n".utf8 ) )

        return body
    }

    /// Parses FITS bytes into a ``FITSMetadata``, or `nil` when the bytes are not
    /// a readable FITS file. Runs synchronously on the actor; the non-`Sendable`
    /// `FITSFile` never escapes this call, only the `Sendable` metadata is
    /// returned.
    private static func metadata( fromFITS data: Data ) -> FITSMetadata?
    {
        guard let file = try? FITSFile( data: data, options: .lenient )
        else
        {
            return nil
        }

        let properties = file.sections.flatMap
        {
            section in section.properties.map { FITSPropertySnapshot( name: $0.name, value: $0.value ) }
        }

        return FITSMetadata( properties: properties )
    }
}
