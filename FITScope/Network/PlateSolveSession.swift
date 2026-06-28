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

import Combine
import CoreGraphics
import Foundation

/// Drives one plate solve for a file and publishes its progress, so the results
/// window can show a live status and then the solved WCS.
///
/// The session orchestrates the ``AstrometryClient`` flow, maps each coarse
/// phase to an observable ``Phase``, and on success both exposes the
/// ``PlateSolveResult`` and writes it onto the originating ``OpenFile`` for the
/// overlays to read. The file is held weakly so a closed file is not pinned by a
/// lingering session.
@MainActor
public final class PlateSolveSession: ObservableObject
{
    /// The observable state of a solve, from authentication through to a result
    /// or a failure.
    public enum Phase: Equatable
    {
        /// Authenticating with the service.
        case loggingIn

        /// Uploading the image.
        case uploading

        /// Waiting for the service to solve the image.
        case solving

        /// The solve finished and ``PlateSolveSession/result`` is available.
        case succeeded

        /// The solve failed, carrying a message suitable for display.
        case failed( message: String )

        /// The solve was cancelled by the user before it finished.
        case cancelled

        /// Whether the solve is still running, driving the progress indicator.
        public var isInProgress: Bool
        {
            switch self
            {
                case .loggingIn,
                     .uploading,
                     .solving: return true
                case .succeeded,
                     .failed,
                     .cancelled: return false
            }
        }
    }

    /// The current phase of the solve.
    @Published public private( set ) var phase: Phase = .loggingIn

    /// The solved result, set once the solve succeeds.
    @Published public private( set ) var result: PlateSolveResult?

    /// The name of the file being solved, for the window title and header.
    public let fileName: String

    /// A snapshot of the rendered image being solved, for the results window's
    /// preview. Captured when the session is created; `nil` if the image had not
    /// rendered yet.
    public let previewImage: CGImage?

    /// The file the result is written back onto, held weakly.
    private weak var file: OpenFile?

    /// The source URL whose bytes are uploaded.
    private let url: URL

    /// The API key used to authenticate.
    private let apiKey: String

    /// The client running the solve.
    private let client: AstrometryClient

    /// The in-flight solve, so it can be cancelled. Exposed for tests to await.
    private( set ) var task: Task< Void, Never >?

    /// Creates a session for a file.
    ///
    /// - Parameters:
    ///   - file:   The file to solve and write the result back onto.
    ///   - apiKey: The Astrometry.net API key.
    ///   - client: The client to run the solve. Defaults to a live client; tests
    ///             inject one backed by a scripted transport.
    public init( file: OpenFile, apiKey: String, client: AstrometryClient = AstrometryClient() )
    {
        self.file         = file
        self.url          = file.url
        self.fileName     = file.displayName
        self.previewImage = file.image?.renderer.result?.image
        self.apiKey       = apiKey
        self.client       = client
    }

    /// Starts the solve in a session-owned task. Idempotent: a second call while
    /// one is in flight is a no-op.
    public func start()
    {
        guard self.task == nil
        else
        {
            return
        }

        self.task = Task
        {
            [ weak self ] in await self?.run()
        }
    }

    /// Cancels the in-flight solve, if any.
    public func cancel()
    {
        self.task?.cancel()
    }

    /// Re-runs the solve from scratch after a previous attempt finished.
    ///
    /// Only valid once the solve has settled (succeeded or failed) — the *Plate
    /// Solve Again* button is shown only then — so there is no in-flight task to
    /// race: the prior task is cleared and the result reset before a fresh solve
    /// starts. A no-op while a solve is still in progress.
    public func restart()
    {
        guard self.phase.isInProgress == false
        else
        {
            return
        }

        self.task   = nil
        self.result = nil
        self.phase  = .loggingIn

        self.start()
    }

    /// Runs the solve to completion, updating ``phase`` throughout and, on
    /// success, exposing the result and writing it onto the file.
    func run() async
    {
        self.file?.isPlateSolving = true

        defer
        {
            self.file?.isPlateSolving = false
        }

        do
        {
            let data   = try await Self.readData( at: self.url )
            let result = try await self.client.solve( imageData: data, fileName: self.fileName, apiKey: self.apiKey )
            {
                [ weak self ] progress in await self?.apply( progress )
            }

            self.result          = result
            self.file?.plateSolve = result
            self.phase            = .succeeded
        }
        catch
        {
            // A cancelled solve surfaces either as a `CancellationError` (when
            // interrupted between steps) or, when interrupted mid-request, as the
            // transport's `URLError(.cancelled)`. Keying on the task's own
            // cancellation catches both, so cancelling never reads as a failure.
            if Task.isCancelled || error is CancellationError
            {
                self.phase = .cancelled
            }
            else
            {
                self.phase = .failed( message: error.localizedDescription )
            }
        }
    }

    /// Maps a client progress phase onto the observable ``Phase``.
    private func apply( _ progress: AstrometryClient.Progress )
    {
        switch progress
        {
            case .loggingIn: self.phase = .loggingIn
            case .uploading: self.phase = .uploading
            case .solving:   self.phase = .solving
        }
    }

    /// Reads a file's bytes off the main actor, honouring the security-scoped
    /// access the file was opened under.
    ///
    /// - Parameter url: The file to read.
    /// - Returns: The file's bytes.
    private nonisolated static func readData( at url: URL ) async throws -> Data
    {
        try await withCheckedThrowingContinuation
        {
            continuation in DispatchQueue.global( qos: .userInitiated ).async
            {
                let didAccess = url.startAccessingSecurityScopedResource()

                defer
                {
                    if didAccess
                    {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                do
                {
                    continuation.resume( returning: try Data( contentsOf: url ) )
                }
                catch
                {
                    continuation.resume( throwing: error )
                }
            }
        }
    }
}
