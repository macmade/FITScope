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
import SwiftFITS
import Testing

/// Tests for ``PlateSolveSession``: the observable state machine that drives a
/// plate solve and persists its WCS onto the file. A scripted
/// ``MockAstrometryTransport`` stands in for the network, so the session's phase
/// transitions and its write-back of the result are verified end to end without
/// a live solve.
@Suite( "PlateSolveSession" )
@MainActor
struct PlateSolveSessionTests
{
    /// Loads a real, renderable frame from the mono fixture — the image a session
    /// solves and writes its result back onto.
    private func makeFrame() async throws -> LoadedImage
    {
        let loader = FITSImageLoader( url: TestFixtures.monoImage, data: try Data( contentsOf: TestFixtures.monoImage ) )

        await loader.load()

        return try #require( loader.image )
    }

    /// A transport that runs the whole flow straight through to a solved job.
    private func successTransport() -> MockAstrometryTransport
    {
        MockAstrometryTransport
        {
            request, _ in

            switch request.url?.path
            {
                case "/api/login":                    return ( 200, AstrometryFixtures.loginSuccess )
                case "/api/upload":                   return ( 200, AstrometryFixtures.uploadSuccess )
                case "/api/submissions/16714":        return ( 200, AstrometryFixtures.submissionReady )
                case "/api/jobs/42":                  return ( 200, AstrometryFixtures.jobSuccess )
                case "/api/jobs/42/calibration":      return ( 200, AstrometryFixtures.calibration )
                case "/api/jobs/42/objects_in_field": return ( 200, AstrometryFixtures.objectsInField )
                case let path? where path.hasPrefix( "/wcs_file/" ): return ( 200, try AstrometryFixtures.wcsFITS )
                default:                              throw URLError( .unsupportedURL )
            }
        }
    }

    /// A successful solve ends in the `succeeded` phase, exposes the result, and
    /// writes the result — including the parsed WCS — onto the file.
    @Test
    func succeedsAndPersistsResultOntoFile() async throws
    {
        let frame   = try await self.makeFrame()
        let client  = AstrometryClient( transport: self.successTransport(), pollInterval: .zero )
        let session = PlateSolveSession( frame: frame, fileName: "mono", apiKey: "key", client: client )

        await session.run()

        #expect( session.phase == .succeeded )

        let result = try #require( session.result )

        #expect( result.jobID == 42 )
        #expect( result.wcs != nil )
        #expect( frame.plateSolve != nil )
        #expect( frame.plateSolve?.jobID == 42 )
    }

    /// A failed solve ends in the `failed` phase and leaves the file's stored
    /// result untouched.
    @Test
    func reportsFailureAndLeavesFileUntouched() async throws
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

        let frame   = try await self.makeFrame()
        let client  = AstrometryClient( transport: transport, pollInterval: .zero )
        let session = PlateSolveSession( frame: frame, fileName: "mono", apiKey: "key", client: client )

        await session.run()

        guard case .failed = session.phase
        else
        {
            Issue.record( "Expected the session to end in the failed phase." )

            return
        }

        #expect( frame.plateSolve == nil )
    }

    /// A solve writes its result onto its own target frame only, leaving the file's
    /// other frames untouched — so each frame of a multi-image file is solved
    /// independently.
    @Test
    func solvesOnlyItsTargetFrame() async throws
    {
        let target  = try await self.makeFrame()
        let other   = try await self.makeFrame()
        let client  = AstrometryClient( transport: self.successTransport(), pollInterval: .zero )
        let session = PlateSolveSession( frame: target, fileName: "mono", apiKey: "key", client: client )

        await session.run()

        #expect( target.plateSolve != nil, "the solved frame receives the result" )
        #expect( other.plateSolve == nil, "another frame is not affected by a different frame's solve" )
    }

    /// The uploaded image is always a rendered PNG, so its upload file name carries
    /// a `.png` extension built from the source's base name (a generic base when the
    /// source has none) rather than the source format's extension.
    @Test
    func uploadFileNameUsesAPNGExtension() throws
    {
        #expect( PlateSolveSession.uploadFileName( for: "M42.xisf" ) == "M42.png" )
        #expect( PlateSolveSession.uploadFileName( for: "M42.fits" ) == "M42.png" )
        #expect( PlateSolveSession.uploadFileName( for: "M42" )      == "M42.png" )
        #expect( PlateSolveSession.uploadFileName( for: "" )         == "image.png" )
    }

    /// After a solve has finished, `restart` re-runs it from scratch — resetting
    /// the state and producing a fresh result on the file.
    @Test
    func restartReSolvesAfterCompletion() async throws
    {
        let frame   = try await self.makeFrame()
        let client  = AstrometryClient( transport: self.successTransport(), pollInterval: .zero )
        let session = PlateSolveSession( frame: frame, fileName: "mono", apiKey: "key", client: client )

        await session.run()

        #expect( session.phase == .succeeded )

        frame.plateSolve = nil

        session.restart()

        await session.task?.value

        #expect( session.phase == .succeeded )
        #expect( frame.plateSolve != nil )
    }
}
