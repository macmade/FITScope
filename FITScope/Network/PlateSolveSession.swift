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
import SwiftUtilities

/// Drives one plate solve for a file and publishes its progress, so the results
/// window can show a live status and then the solved WCS.
///
/// The session orchestrates the ``AstrometryClient`` flow, maps each coarse
/// phase to an observable ``Phase``, and on success both exposes the
/// ``PlateSolveResult`` and writes it onto the originating image (frame) for the
/// overlays to read. Plate solving is per-frame, so the session targets a single
/// ``LoadedImage``, held weakly so a closed file's frames are not pinned by a
/// lingering session. The image uploaded is always a PNG of the frame rendered at
/// its native orientation — the universal format Astrometry.net accepts for any
/// source format (including those it cannot ingest directly, e.g. XISF). The
/// frame's metadata-derived ``PlateSolveHints`` (approximate coordinates and plate
/// scale) are sent with it so the service can steer the solve rather than solve
/// blindly — Astrometry.net takes hints only as request parameters, not from a
/// file header, so the image format is irrelevant to hinting.
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

    /// The image (frame) the result is written back onto, held weakly.
    private weak var frame: LoadedImage?

    /// The frame's render source, from which the upload image is rendered. `nil`
    /// when the frame exposed no renderable source.
    private let source: ( any ImageRenderSource )?

    /// The position and scale hints sent with the upload to steer the solve,
    /// derived from the frame's metadata when the session is created.
    private let hints: PlateSolveHints

    /// The API key used to authenticate.
    private let apiKey: String

    /// The client running the solve.
    private let client: AstrometryClient

    /// The in-flight solve, so it can be cancelled. Exposed for tests to await.
    private( set ) var task: Task< Void, Never >?

    /// Creates a session for one image (frame).
    ///
    /// - Parameters:
    ///   - frame:      The image to solve and write the result back onto.
    ///   - fileName:   The owning file's display name, for the window title and header.
    ///   - apiKey:     The Astrometry.net API key.
    ///   - client:     The client to run the solve. Defaults to a live client; tests
    ///                 inject one backed by a scripted transport.
    public init( frame: LoadedImage, fileName: String, apiKey: String, client: AstrometryClient = AstrometryClient() )
    {
        let source = try? frame.renderer.renderSourceSnapshot()

        self.frame        = frame
        self.source       = source
        self.fileName     = fileName
        self.previewImage = frame.renderer.result?.image
        self.apiKey       = apiKey
        self.client       = client
        self.hints        = PlateSolveHints( coordinate: frame.target, pixelScale: frame.pixelScale, dimensions: source?.dimensions ?? nil )
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
        self.frame?.isPlateSolving = true

        defer
        {
            self.frame?.isPlateSolving = false
        }

        do
        {
            let data   = try await Self.renderedPNG( from: self.source )
            let result = try await self.client.solve( imageData: data, fileName: Self.uploadFileName( for: self.fileName ), apiKey: self.apiKey, hints: self.hints )
            {
                [ weak self ] progress in await self?.apply( progress )
            }

            self.result           = result
            self.frame?.plateSolve = result
            self.phase             = .succeeded
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

    /// The file name to label the uploaded PNG with: the source's base name with a
    /// `.png` extension, so the upload is named for the PNG it actually is rather
    /// than carrying the source format's extension (which the service could
    /// misread). A generic base is used when the source name has none.
    ///
    /// - Parameter displayName: The source file's display name.
    /// - Returns: The upload file name, ending in `.png`.
    nonisolated static func uploadFileName( for displayName: String ) -> String
    {
        let base = ( displayName as NSString ).deletingPathExtension

        return "\( base.isEmpty ? "image" : base ).png"
    }

    /// Renders the frame's as-captured image at its native orientation and encodes it
    /// as PNG, off the main actor, for upload.
    ///
    /// A rendered PNG is uploaded (rather than the original file's bytes) so that any
    /// source format works — including formats Astrometry.net cannot ingest directly.
    /// It is rendered from the Sendable render source at the default, as-captured
    /// settings and **identity orientation**, so the solved WCS is in the image's
    /// native pixel space — matching the header WCS the overlays map through — rather
    /// than any display rotation the user has applied.
    ///
    /// - Parameter source: The frame's render source, or `nil` when unavailable.
    /// - Returns: The PNG bytes to upload.
    /// - Throws: ``RuntimeError`` when there is no source, or it cannot be rendered or
    ///   encoded.
    private nonisolated static func renderedPNG( from source: ( any ImageRenderSource )? ) async throws -> Data
    {
        guard let source
        else
        {
            throw RuntimeError( message: "The image has no renderable content to plate-solve." )
        }

        return try await withCheckedThrowingContinuation
        {
            continuation in DispatchQueue.global( qos: .userInitiated ).async
            {
                do
                {
                    // Default settings render as captured at identity orientation.
                    let result = try source.makeResult( settings: ImageProcessor.Settings() )
                    let data   = try ImageExporter.data( for: result.image, format: .png )

                    continuation.resume( returning: data )
                }
                catch
                {
                    continuation.resume( throwing: error )
                }
            }
        }
    }
}
