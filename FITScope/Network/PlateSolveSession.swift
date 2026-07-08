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
import UniformTypeIdentifiers

/// Drives one plate solve for a file and publishes its progress, so the results
/// window can show a live status and then the solved WCS.
///
/// The session orchestrates the ``AstrometryClient`` flow, maps each coarse
/// phase to an observable ``Phase``, and on success both exposes the
/// ``PlateSolveResult`` and writes it onto the originating image (frame) for the
/// overlays to read. Plate solving is per-frame, so the session targets a single
/// ``LoadedImage``, held weakly so a closed file's frames are not pinned by a
/// lingering session. The image uploaded is a PNG of the frame rendered at its
/// native orientation — the universal format Astrometry.net accepts for any source
/// format (including those it cannot ingest directly, e.g. XISF).
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

    /// The owning file's URL, uploaded as-is when it is a single-image FITS file (see
    /// ``shouldUploadOriginalFile(url:frameCount:)``).
    private let fileURL: URL

    /// The number of frames the owning file decoded into, used to decide the upload
    /// strategy — the original file is only uploaded for a single-image file.
    private let frameCount: Int

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
    ///   - fileURL:    The owning file's URL, uploaded as-is for a single-image FITS file.
    ///   - frameCount: The number of frames the owning file decoded into.
    ///   - apiKey:     The Astrometry.net API key.
    ///   - client:     The client to run the solve. Defaults to a live client; tests
    ///                 inject one backed by a scripted transport.
    public init( frame: LoadedImage, fileName: String, fileURL: URL, frameCount: Int, apiKey: String, client: AstrometryClient = AstrometryClient() )
    {
        self.frame        = frame
        self.source       = try? frame.renderer.renderSourceSnapshot()
        self.fileName     = fileName
        self.fileURL      = fileURL
        self.frameCount   = frameCount
        self.previewImage = frame.renderer.result?.image
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
        self.frame?.isPlateSolving = true

        defer
        {
            self.frame?.isPlateSolving = false
        }

        do
        {
            let data   = try await Self.uploadData( from: self.source, originalFileURL: self.uploadFileURL )
            let result = try await self.client.solve( imageData: data, fileName: self.fileName, apiKey: self.apiKey )
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

    /// The file URL to upload as-is, or `nil` to upload a rendered PNG — the original
    /// file only for a single-image FITS file (see ``shouldUploadOriginalFile(url:frameCount:)``).
    private var uploadFileURL: URL?
    {
        Self.shouldUploadOriginalFile( url: self.fileURL, frameCount: self.frameCount ) ? self.fileURL : nil
    }

    /// Whether the owning file should upload its original bytes for the solve, rather
    /// than a rendered PNG.
    ///
    /// True only for a single-image FITS file: Astrometry.net reads FITS directly and
    /// uses its header hints (approximate coordinates, pixel scale) to seed and speed
    /// up the solve. A multi-image cube (which cannot be uploaded whole to pick a
    /// single frame) and any non-FITS format (some of which Astrometry.net cannot
    /// ingest at all) upload a rendered PNG instead.
    ///
    /// - Parameters:
    ///   - url:        The file's URL.
    ///   - frameCount: The number of frames the file decoded into.
    /// - Returns: `true` to upload the original file, `false` to upload a PNG.
    public nonisolated static func shouldUploadOriginalFile( url: URL, frameCount: Int ) -> Bool
    {
        frameCount == 1 && UTType( filenameExtension: url.pathExtension )?.conforms( to: .fits ) == true
    }

    /// The bytes to upload for the solve: the original file's bytes when
    /// `originalFileURL` is set (a single-image FITS file, whose header hints speed up
    /// the solve), otherwise a rendered PNG of the frame.
    ///
    /// - Parameters:
    ///   - source:          The frame's render source (for the PNG path), or `nil`.
    ///   - originalFileURL: The file to upload as-is, or `nil` to render a PNG.
    /// - Returns: The bytes to upload.
    /// - Throws: ``RuntimeError`` or an I/O error when the bytes cannot be produced.
    private nonisolated static func uploadData( from source: ( any ImageRenderSource )?, originalFileURL: URL? ) async throws -> Data
    {
        if let originalFileURL
        {
            return try await Self.readData( at: originalFileURL )
        }

        return try await Self.renderedPNG( from: source )
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

    /// Reads a file's bytes off the main actor, honouring the security-scoped access
    /// the file was opened under. Used to upload a single-image FITS file as-is.
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
