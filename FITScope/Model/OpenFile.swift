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
import SwiftUI

/// A single file open in a window: its identity, source URL, and the loader
/// that parses it into a ``FITSImage``.
///
/// Each instance is a distinct entry — opening the same URL twice yields two
/// independent ``OpenFile`` objects, each with its own renderer and adjustment
/// state. Change notifications from the underlying loader are re-published so a
/// view observing the open file refreshes as it loads and renders.
@MainActor
public final class OpenFile: ObservableObject, Identifiable
{
    /// The stage of an open file in the load → render pipeline, used to drive
    /// per-file UI such as the sidebar row's progress indicator.
    public enum RenderPhase: Equatable
    {
        /// The file is being parsed; no image yet.
        case loading

        /// The image is parsed but its displayable result is still being
        /// rendered — distinct from ``loading`` so the UI keeps indicating work
        /// in progress until the render commits, not merely until parsing ends.
        case rendering

        /// A rendered result is available.
        case ready

        /// Loading or rendering failed.
        case failed

        /// Whether the file is still working toward a result (loading or
        /// rendering), i.e. a progress indicator should be shown.
        public var isInProgress: Bool
        {
            self == .loading || self == .rendering
        }
    }

    /// A stable, per-instance identity, independent of the URL.
    public let id = UUID()

    /// The source URL of the file.
    public let url: URL

    /// The loader that parses the file into a ``FITSImage``.
    @Published public private( set ) var loader: FITSImageLoader

    /// A small, downscaled preview of the rendered image for the sidebar, or
    /// `nil` before one has been generated.
    @Published public private( set ) var thumbnail: CGImage?

    /// The image's weight relative to the other files open in the same window, or
    /// `nil` when it cannot be ranked — the image lacks the metrics the formula
    /// needs, or it is a lone image under a set-wide formula. Computed and
    /// assigned by the owning ``WindowModel`` as files and metrics change.
    @Published public internal( set ) var weight: Double?

    /// The plate-solve result for this file, set once a solve succeeds. It carries
    /// the field calibration and the WCS the astrometric overlays read. `nil`
    /// until the file has been successfully plate-solved.
    @Published public internal( set ) var plateSolve: PlateSolveResult?

    /// Whether a plate solve is currently running for this file. Published so the
    /// toolbar's plate-solve button can show a live, in-progress state without
    /// observing the session directly.
    @Published public internal( set ) var isPlateSolving = false

    /// Forwards the loader's change notifications to this object's observers.
    private var loaderObserver: AnyCancellable?

    /// Regenerates the thumbnail whenever the current renderer commits a new
    /// result, so the sidebar thumbnail tracks the file's processing. Follows the
    /// loaded image across a reload via `switchToLatest`.
    private var thumbnailObserver: AnyCancellable?

    /// The in-flight (or finished) load → render → thumbnail work, owned by the
    /// model rather than any view. `nil` until ``prepare(throttle:)`` is called.
    private( set ) var preparation: Task< Void, Never >?

    /// The in-flight thumbnail (re)generation, cancelled when a newer render
    /// result supersedes it so the latest result always wins. Internal so the
    /// preparation and tests can await the current thumbnail settling.
    private( set ) var thumbnailTask: Task< Void, Never >?

    /// The longest-side pixel size of the generated sidebar thumbnail.
    private static let thumbnailDimension = 64

    /// Creates an open file for the given URL.
    ///
    /// - Parameter url: The source URL of the file.
    public init( url: URL )
    {
        self.url            = url
        self.loader         = FITSImageLoader( url: url )
        self.loaderObserver = self.loader.objectWillChange.sink
        {
            [ weak self ] _ in self?.objectWillChange.send()
        }

        // Regenerate the thumbnail on every committed render result, switching to
        // the loaded image's renderer as it appears (and again after a reload).
        // `$result` only fires on a successful commit, so a failed render keeps
        // the last good thumbnail.
        self.thumbnailObserver = self.loader.$image
            .map
            {
                image -> AnyPublisher< FITSImageRenderer.Result?, Never > in

                guard let renderer = image?.renderer
                else
                {
                    return Empty( completeImmediately: false ).eraseToAnyPublisher()
                }

                return renderer.$result.eraseToAnyPublisher()
            }
            .switchToLatest()
            .compactMap { $0 }
            .sink
            {
                [ weak self ] _ in self?.regenerateThumbnail()
            }
    }

    /// The file name shown in the sidebar and window title.
    public var displayName: String
    {
        self.url.lastPathComponent
    }

    /// The loaded image, or `nil` before loading or after a failure.
    public var image: FITSImage?
    {
        self.loader.image
    }

    /// The image's weighting metrics, derived from star detection and the noise
    /// estimate. Empty until the image has loaded and been analysed; the input to
    /// the window's per-image weight computation.
    public var metrics: ImageWeighting.Metrics
    {
        ImageWeighting.metrics( starField: self.image?.starField, signalToNoise: self.image?.signalToNoise )
    }

    /// The image's ``weight`` formatted for display (one decimal), or `nil` when
    /// no weight is available. The single source of truth for how a weight reads
    /// in both the sidebar row pill and the Image Information panel.
    public var formattedWeight: String?
    {
        self.weight.map { String( format: "%.1f", $0 ) }
    }

    /// The error from the most recent failed load, or `nil` on success.
    public var error: Error?
    {
        self.loader.error
    }

    /// A human-readable description of why the file cannot be displayed — a load
    /// failure, or a render failure with no previously good result — or `nil`
    /// when there is nothing to flag. Drives the attention icon and its tooltip
    /// in the sidebar row.
    ///
    /// A render failure that still has a retained good result (e.g. a transient
    /// bad adjustment the user can back out of) is deliberately *not* flagged:
    /// the image is still shown, so the row should not raise an alarm.
    public var warning: String?
    {
        guard let image = self.image
        else
        {
            return self.error?.localizedDescription
        }

        if image.renderer.result == nil
        {
            return image.renderer.error?.localizedDescription
        }

        return nil
    }

    /// Whether the loaded image has adjustments that differ from its as-captured
    /// defaults — the single "edited" signal, shared by the sidebar marker, the
    /// window's ``WindowModel/hasAdjustedFiles`` and the close/trash confirmations.
    ///
    /// A file whose image has not loaded yet is not adjusted.
    public var hasAdjustments: Bool
    {
        self.image?.renderer.adjustments.hasAdjustments ?? false
    }

    /// The file's current stage in the load → render pipeline.
    ///
    /// `rendering` covers the window after parsing finishes but before the first
    /// render commits, so the sidebar row keys its spinner on the committed
    /// result rather than the parsed image.
    public var renderPhase: RenderPhase
    {
        Self.renderPhase(
            hasImage:    self.image != nil,
            hasResult:   self.image?.renderer.result != nil,
            hasError:    self.error != nil || self.image?.renderer.error != nil,
            isRendering: self.image?.renderer.isRendering ?? false
        )
    }

    /// Maps the pipeline's observable state to a ``RenderPhase``.
    ///
    /// An unparsed file is loading (or failed, if its load failed). Once parsed,
    /// an in-flight render reports `rendering` — including a re-render that keeps
    /// the previous result committed, so the processing affordances show for
    /// every render. With no render in flight, a retained error reports `failed`,
    /// a committed result is `ready`, and the brief window before the first
    /// render starts is still `rendering`.
    ///
    /// - Parameters:
    ///   - hasImage:    Whether the file has parsed into an image.
    ///   - hasResult:   Whether the renderer has committed a result.
    ///   - hasError:    Whether loading or rendering failed.
    ///   - isRendering: Whether a render is currently in flight.
    /// - Returns: The corresponding phase.
    nonisolated static func renderPhase( hasImage: Bool, hasResult: Bool, hasError: Bool, isRendering: Bool ) -> RenderPhase
    {
        if hasImage == false
        {
            return hasError ? .failed : .loading
        }

        if isRendering
        {
            return .rendering
        }

        if hasError
        {
            return .failed
        }

        return hasResult ? .ready : .rendering
    }

    /// Loads (parses) the file, if not already loaded.
    public func load() async
    {
        await self.loader.load()
    }

    /// Starts loading, rendering and thumbnailing the file in a model-owned task,
    /// independent of whether it is displayed. Idempotent: a second call while a
    /// preparation exists is a no-op.
    ///
    /// The work runs here — not in a view's `.task` — so the resulting
    /// `@Published` changes are published outside SwiftUI's view-update pass. The
    /// `throttle` bounds how many files prepare at once.
    ///
    /// - Parameter throttle: Gates concurrent preparations across the window.
    func prepare( throttle: RenderThrottle )
    {
        guard self.preparation == nil
        else
        {
            return
        }

        self.preparation = Task
        {
            [ weak self ] in

            await throttle.acquire()

            defer { throttle.release() }

            guard let self, Task.isCancelled == false
            else
            {
                return
            }

            await self.load()
            await self.image?.renderer.render()
            await self.image?.detectStars()

            // The render commit above drives the thumbnail through
            // ``thumbnailObserver``; wait for that regeneration so the prepared
            // file has its sidebar thumbnail ready, without a second render.
            await self.thumbnailTask?.value
        }
    }

    /// Regenerates the sidebar thumbnail from the current render result,
    /// cancelling any regeneration still in flight so the newest result wins.
    ///
    /// Driven by ``thumbnailObserver`` on every committed render, so the thumbnail
    /// reflects the file's latest processing rather than only its first render.
    private func regenerateThumbnail()
    {
        self.thumbnailTask?.cancel()

        self.thumbnailTask = Task
        {
            [ weak self ] in

            await self?.makeThumbnail( maxDimension: Self.thumbnailDimension )
        }
    }

    /// Cancels any in-flight preparation, e.g. when the file is closed. The
    /// preparation task captures `self` weakly, so an un-cancelled task simply
    /// bails once the file is released — this just stops the work sooner.
    func cancelPreparation()
    {
        self.preparation?.cancel()
    }

    /// Copies the original, unmodified file to a destination, byte for byte.
    ///
    /// This is the "Save As…" action: it duplicates the source FITS file exactly,
    /// with no re-encoding or processing, so the copy is identical to what was
    /// opened. An existing file at the destination is replaced (the save panel
    /// has already confirmed the overwrite with the user). Copying a file onto
    /// its own URL is a no-op, so the source can never be destroyed.
    ///
    /// - Parameter destination: The URL to write the copy to.
    /// - Throws: Any error thrown by `FileManager` while removing an existing
    ///   destination or copying the file.
    public func copyOriginalFile( to destination: URL ) throws
    {
        guard self.url.standardizedFileURL != destination.standardizedFileURL
        else
        {
            return
        }

        if FileManager.default.fileExists( atPath: destination.path )
        {
            try FileManager.default.removeItem( at: destination )
        }

        try FileManager.default.copyItem( at: self.url, to: destination )
    }

    /// Generates a thumbnail from the current rendered image, downscaled so its
    /// longest side is at most `maxDimension` pixels. A no-op when nothing has
    /// rendered yet.
    ///
    /// - Parameter maxDimension: The maximum width or height of the thumbnail.
    public func makeThumbnail( maxDimension: Int ) async
    {
        guard let source = self.image?.renderer.result?.image
        else
        {
            return
        }

        let longest = max( source.width, source.height )
        let scale   = longest > maxDimension ? Double( maxDimension ) / Double( longest ) : 1.0
        let width   = max( 1, Int( Double( source.width  ) * scale ) )
        let height  = max( 1, Int( Double( source.height ) * scale ) )

        let thumbnail = await withCheckedContinuation
        {
            ( continuation: CheckedContinuation< CGImage?, Never > ) in

            DispatchQueue.global( qos: .utility ).async
            {
                continuation.resume( returning: Self.resize( source, width: width, height: height ) )
            }
        }

        // A newer render result may have superseded this regeneration while it
        // was resizing; if so, drop the stale result rather than overwrite the
        // newer thumbnail.
        guard Task.isCancelled == false
        else
        {
            return
        }

        self.thumbnail = thumbnail
    }

    /// Redraws a `CGImage` at the given pixel size, preserving its color space.
    private nonisolated static func resize( _ image: CGImage, width: Int, height: Int ) -> CGImage?
    {
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data:             nil,
            width:            width,
            height:           height,
            bitsPerComponent: 8,
            bytesPerRow:      0,
            space:            colorSpace,
            bitmapInfo:       CGImageAlphaInfo.premultipliedLast.rawValue
        )
        else
        {
            return nil
        }

        context.interpolationQuality = .low
        context.draw( image, in: CGRect( x: 0, y: 0, width: width, height: height ) )

        return context.makeImage()
    }
}

/// An open file is sortable in the sidebar: its display name, weight and metrics
/// already satisfy ``FileSortable``.
extension OpenFile: FileSortable
{}
