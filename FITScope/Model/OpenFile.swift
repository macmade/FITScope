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
/// that parses it into a ``LoadedImage``.
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

    /// The loader that parses the file into a ``LoadedImage``, selected by the
    /// file's type through ``ImageLoader``.
    @Published public private( set ) var loader: any ImageLoading

    /// The index of the frame currently shown, into ``frames``. `0` for a
    /// single-frame file; changed through ``selectFrame(_:)`` when the user picks
    /// another frame in the carousel.
    @Published public private( set ) var selectedFrameIndex = 0

    /// A small, downscaled preview of the rendered image for the sidebar, or
    /// `nil` before one has been generated.
    @Published public private( set ) var thumbnail: CGImage?

    /// The image's weight relative to the other files open in the same window, or
    /// `nil` when it cannot be ranked — the image lacks the metrics the formula
    /// needs, or it is a lone image under a set-wide formula. Computed and
    /// assigned by the owning ``WindowModel`` as files and metrics change.
    @Published public internal( set ) var weight: Double?

    /// Forwards the loader's change notifications to this object's observers.
    private var loaderObserver: AnyCancellable?

    /// Regenerates the thumbnail whenever the current renderer commits a new
    /// result, so the sidebar thumbnail tracks the file's processing. Follows the
    /// loaded image across a reload via `switchToLatest`.
    private var thumbnailObserver: AnyCancellable?

    /// Re-establishes ``selectedFrameObserver`` whenever the loader's loaded image
    /// changes — it first appears after loading, or is replaced on a reload — so the
    /// initial frame is observed as soon as it loads.
    private var loadedImageObserver: AnyCancellable?

    /// Forwards the currently selected frame's own change notifications to this
    /// object's observers, rebuilt on every selection change and image
    /// (re)appearance.
    ///
    /// A loader forwards only its *primary* frame's changes, so a lazily prepared,
    /// non-primary frame's render or star detection would otherwise not refresh the
    /// views observing this file (the canvas, the sidebar weight). Observing the
    /// selected frame directly closes that gap; the forwarding is harmlessly
    /// redundant for the primary frame, which the loader already forwards.
    private var selectedFrameObserver: AnyCancellable?

    /// The preparation pool the window prepares files through, retained from
    /// ``prepare(preparationThrottle:analysisThrottle:priority:)`` so on-demand
    /// carousel frame selection routes its render work through the same throttle.
    /// `nil` until the file is first prepared (e.g. in tests that drive selection
    /// directly).
    private var preparationThrottle: WorkThrottle?

    /// The analysis pool star detection is enqueued on, retained from
    /// ``prepare(preparationThrottle:analysisThrottle:priority:)`` so on-demand
    /// carousel frame selection enqueues onto the same pool. `nil` until the file is
    /// first prepared, in which case a detection runs unbounded (e.g. in tests that
    /// drive selection directly).
    private var analysisThrottle: WorkThrottle?

    /// The in-flight (or finished) load → render → thumbnail work, owned by the
    /// model rather than any view. `nil` until
    /// ``prepare(preparationThrottle:analysisThrottle:priority:)`` is called.
    private( set ) var preparation: Task< Void, Never >?

    /// The star analyses enqueued on the analysis pool, keyed by the frame each one
    /// detects, so closing the file can cancel them all.
    ///
    /// One entry per frame, so the dictionary is bounded by the file's frame count:
    /// ``LoadedImage/markStarDetectionQueued()`` refuses a frame that is already
    /// queued, running or finished, so a frame can only be enqueued again once its
    /// previous analysis has released the queued stage.
    private var analysisTasks: [ ObjectIdentifier: Task< Void, Never > ] = [ : ]

    /// The in-flight thumbnail (re)generation, cancelled when a newer render
    /// result supersedes it so the latest result always wins. Internal so the
    /// preparation and tests can await the current thumbnail settling.
    private( set ) var thumbnailTask: Task< Void, Never >?

    /// The in-flight on-demand preparations of selected frames — rendering each and
    /// enqueuing its analysis — keyed by the frame each one prepares.
    ///
    /// One entry per frame, kept rather than replaced, so selecting another frame
    /// starts its preparation instead of stopping this one and a visited frame is
    /// always prepared to completion. Bounded by the file's frame count.
    private var frameSelectionTasks: [ ObjectIdentifier: Task< Void, Never > ] = [ : ]

    /// The in-flight background render of the non-primary frames, so the carousel
    /// shows a thumbnail preview for every frame rather than only the visited ones.
    /// Render-only (no star detection); `nil` for a single-frame file. Internal so
    /// tests can await the previews settling.
    private( set ) var framePreviewsTask: Task< Void, Never >?

    /// The longest-side pixel size of the generated sidebar thumbnail.
    private static let thumbnailDimension = 64

    /// Creates an open file for the given URL, selecting the loader for its type.
    ///
    /// - Parameters:
    ///   - url:         The source URL of the file.
    ///   - preferences: The shared preferences, read for the per-format auto-stretch
    ///                  setting the loader applies; `nil` (the default) opens linear.
    public convenience init( url: URL, preferences: Preferences? = nil )
    {
        self.init( url: url, loader: ImageLoader.loader( for: url, preferences: preferences ) )
    }

    /// Creates an open file backed by a specific loader.
    ///
    /// The public ``init(url:)`` selects the loader by file type; this designated
    /// initializer takes one directly so tests can inject a stub — e.g. a
    /// multi-frame loader that no real format produces yet.
    ///
    /// - Parameters:
    ///   - url:    The source URL of the file.
    ///   - loader: The loader that parses the file.
    init( url: URL, loader: any ImageLoading )
    {
        self.url            = url
        self.loader         = loader
        self.loaderObserver = self.loader.objectWillChange.sink
        {
            [ weak self ] _ in self?.objectWillChange.send()
        }

        // Regenerate the thumbnail on every committed render result, switching to
        // the loaded image's renderer as it appears (and again after a reload).
        // `$result` only fires on a successful commit, so a failed render keeps
        // the last good thumbnail.
        self.thumbnailObserver = self.loader.imagePublisher
            .map
            {
                image -> AnyPublisher< ImageRenderer.Result?, Never > in

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

        // Observe the selected frame directly (see ``selectedFrameObserver``),
        // re-establishing the observation as the loaded image appears or is replaced.
        self.loadedImageObserver = self.loader.imagePublisher.sink
        {
            [ weak self ] _ in self?.observeSelectedFrame()
        }
    }

    /// The file name shown in the sidebar and window title.
    public var displayName: String
    {
        self.url.lastPathComponent
    }

    /// The file's frames, in display order — one per image it holds. A single
    /// image (a 2D FITS, a photograph) has one frame; a multi-image file (a FITS
    /// cube, XISF, HEIC) has several, surfaced in the carousel.
    public var frames: [ LoadedImage ]
    {
        self.loader.frames
    }

    /// The loaded image currently shown — the frame at ``selectedFrameIndex`` — or
    /// `nil` before loading or after a failure. Falls back to the loader's primary
    /// image when the selection is out of range (e.g. before the frames appear).
    public var image: LoadedImage?
    {
        let frames = self.frames

        guard frames.indices.contains( self.selectedFrameIndex )
        else
        {
            return self.loader.image
        }

        return frames[ self.selectedFrameIndex ]
    }

    /// Shows the frame at the given index, if it is in range and not already
    /// selected, and prepares it (renders and, if needed, detects it) on demand so
    /// the newly shown frame produces a displayable result.
    ///
    /// - Parameter index: The index of the frame to show, into ``frames``.
    public func selectFrame( _ index: Int )
    {
        guard self.frames.indices.contains( index ), index != self.selectedFrameIndex
        else
        {
            return
        }

        self.selectedFrameIndex = index

        self.observeSelectedFrame()
        self.prepareSelectedFrame()
    }

    /// Subscribes to the currently selected frame's change notifications and
    /// forwards them to this object's observers, replacing any prior subscription.
    /// Clears the subscription when no frame is available yet.
    private func observeSelectedFrame()
    {
        self.selectedFrameObserver = self.image?.objectWillChange.sink
        {
            [ weak self ] _ in self?.objectWillChange.send()
        }
    }

    /// Renders the selected frame if it has not rendered yet, then enqueues its star
    /// analysis if detection has not run — so a frame is prepared lazily, the first
    /// time it is shown, rather than every frame being processed up front.
    ///
    /// A frame already rendered (the initial frame, or one revisited) is left
    /// untouched, so switching back to it is instant and keeps its adjustments.
    ///
    /// Selecting another frame starts that frame's preparation without stopping this
    /// one: a frame the user has visited is prepared to completion, as an opened file
    /// is, and its result is there when they come back to it. One preparation per
    /// frame — a frame already being prepared is not prepared again — so scrubbing the
    /// carousel spawns at most one per distinct frame rather than one per selection.
    ///
    /// A frame that already has a result needs no render, so it takes no preparation
    /// slot at all and its analysis is enqueued straight away. Only a frame still
    /// waiting on its pixels acquires the preparation throttle, at ``high`` priority
    /// (ahead of background file preparations) but still through the throttle, so the
    /// carousel can never spawn unbounded concurrent renders. That slot covers the
    /// render alone: the analysis goes onto the analysis pool, at the same ``high``
    /// priority, and the slot is released without waiting for it.
    ///
    /// `self` is captured weakly and only retained once a slot is granted. Cancellation
    /// is honoured before the render and again before the analysis is enqueued, so
    /// closing the file stops the work promptly — closing is the only thing that
    /// cancels it.
    ///
    /// Each enqueue outranks the one before it, so the frame settled on is served
    /// first. That ordering is decided as each analysis suspends in the pool, and only
    /// until something reorders it: the pool is keyed by the *file*, so a later
    /// ``WorkThrottle/prioritize(key:)`` from the window promotes whichever of the
    /// file's analyses has waited longest, which need not be the frame on screen.
    private func prepareSelectedFrame()
    {
        guard let image = self.image
        else
        {
            return
        }

        // Nothing to render, so nothing to wait for a preparation slot for. A render
        // already in flight — the background previews', or an earlier selection's —
        // counts as nothing to render: it commits sooner than a duplicate started now.
        guard image.renderer.result == nil, image.renderer.error == nil, image.renderer.isRendering == false
        else
        {
            self.enqueueStarDetection( for: image, priority: .high )

            return
        }

        let frame = ObjectIdentifier( image )

        guard self.frameSelectionTasks[ frame ] == nil
        else
        {
            return
        }

        let throttle = self.preparationThrottle
        let id       = self.id

        self.frameSelectionTasks[ frame ] = Task
        {
            [ weak self ] in

            await throttle?.acquire( key: id, priority: .high )

            defer { throttle?.release() }

            guard let self, Task.isCancelled == false
            else
            {
                return
            }

            // Re-tested after the wait for a slot: the previews may have started
            // rendering this frame in the meantime.
            if image.renderer.result == nil, image.renderer.error == nil, image.renderer.isRendering == false
            {
                await image.renderer.render()
            }

            guard Task.isCancelled == false
            else
            {
                return
            }

            self.enqueueStarDetection( for: image, priority: .high )
        }
    }

    /// Enqueues the image's star analysis on the analysis pool, so detection waits for
    /// an analysis slot rather than holding the preparation slot that rendered it.
    ///
    /// A no-op unless the image enters the queued stage — ``LoadedImage`` refuses a
    /// frame whose detection is already queued, running or finished, which is what
    /// keeps the preparation and an on-demand frame selection from detecting the same
    /// frame twice. The enqueued work bails on cancellation and releases the queued
    /// stage on its way out, so a cancelled analysis never leaves the frame reporting
    /// a detection that will not run.
    ///
    /// The file's ``id`` is the pool key, as it is for the preparation, so the owning
    /// model can ``WorkThrottle/prioritize(key:)`` a waiting analysis when its file
    /// becomes the selection.
    ///
    /// - Parameters:
    ///   - image:    The frame to detect stars in.
    ///   - priority: The urgency to enqueue at — `.high` for the frame the user is
    ///               looking at, so its stars are not left behind every background
    ///               file's analysis.
    private func enqueueStarDetection( for image: LoadedImage, priority: WorkThrottle.Priority )
    {
        guard image.markStarDetectionQueued()
        else
        {
            return
        }

        let throttle = self.analysisThrottle
        let id       = self.id

        self.analysisTasks[ ObjectIdentifier( image ) ] = Task
        {
            await throttle?.acquire( key: id, priority: priority )

            defer
            {
                throttle?.release()

                // Keeps the acquire and the queued stage paired within this task, so
                // no exit from it can leave the frame reporting a detection that will
                // not run. It releases the queued stage alone, and every exit reachable
                // today has already left that stage — a detection that ran is finished,
                // and the only caller that cancels one abandons the frame itself — so
                // it is an invariant rather than an effect.
                image.markStarDetectionAbandoned()
            }

            guard Task.isCancelled == false
            else
            {
                return
            }

            await image.detectStars()
        }
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
        // A graph is decoded at load and has no render pipeline, so it is ready as
        // soon as its image exists — never "rendering", so the sidebar spinner stops.
        if self.image?.graph != nil
        {
            return .ready
        }

        return Self.renderPhase(
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
    /// `preparationThrottle` bounds how many files prepare at once.
    ///
    /// A preparation slot covers load → render → thumbnail. The image's star analysis
    /// is enqueued on `analysisThrottle` as soon as the render returns, at the same
    /// priority, and the preparation neither waits for it nor holds its slot across
    /// it — so one file's detection cannot decide when the next file may start
    /// loading. Wait for it with ``awaitStarDetection()`` when the results matter.
    ///
    /// The file's ``id`` is used as the key in both pools, so the owning model can
    /// later ``WorkThrottle/prioritize(key:)`` this preparation, or its analysis,
    /// while either waits — e.g. when the file becomes the selection.
    ///
    /// - Parameters:
    ///   - preparationThrottle: Gates concurrent preparations across the window.
    ///   - analysisThrottle:    Gates concurrent star analyses across the window.
    ///   - priority:            The initial render priority — `.high` for the file the
    ///                          user is looking at, so it is processed ahead of the rest.
    func prepare( preparationThrottle: WorkThrottle, analysisThrottle: WorkThrottle, priority: WorkThrottle.Priority = .normal )
    {
        guard self.preparation == nil
        else
        {
            return
        }

        // Retained so on-demand carousel frame selection can route through the very
        // same pools rather than saturating the CPU alongside file preparations.
        self.preparationThrottle = preparationThrottle
        self.analysisThrottle    = analysisThrottle

        let id = self.id

        self.preparation = Task
        {
            [ weak self ] in

            await preparationThrottle.acquire( key: id, priority: priority )

            defer { preparationThrottle.release() }

            guard let self, Task.isCancelled == false
            else
            {
                return
            }

            await self.load()

            // Resolved once, so the rest of the preparation stays with the frame it
            // began on. ``image`` is computed from ``selectedFrameIndex``, so reading
            // it again after each await would follow a carousel selection made while
            // this runs — leaving the frame the sidebar thumbnail is taken from
            // half-prepared, and duplicating the work ``prepareSelectedFrame()`` is
            // already doing on the newly selected frame.
            let image = self.image

            // A graph (a NAXIS=1 file) has no render pipeline, no pixels to detect
            // stars in, and no raster thumbnail — it is fully prepared once decoded.
            guard image?.graph == nil
            else
            {
                return
            }

            await image?.renderer.render()

            // Enqueued before the thumbnail rather than after it: ``makeThumbnail``
            // resizes on the global utility queue, which a folder of opening files
            // saturates, so an analysis sequenced behind it would inherit that delay.
            // The render is not cancellable, so the cancellation check is made here
            // rather than only above: a file closed while it rendered must not then
            // enqueue an analysis ``cancelPreparation()`` has already been past.
            if let image, Task.isCancelled == false
            {
                self.enqueueStarDetection( for: image, priority: priority )
            }

            // The render commit above drives the thumbnail through
            // ``thumbnailObserver``; wait for that regeneration so the prepared
            // file has its sidebar thumbnail ready, without a second render.
            await self.thumbnailTask?.value

            // Fill in the carousel previews for the remaining frames in the
            // background, once the primary frame the user is looking at is ready —
            // and only if the file is still open. Neither the render above nor the
            // thumbnail wait is cancellable, so a file closed during either arrives
            // here having already been past ``cancelPreparation()``, which would
            // leave this spawning a fresh task nothing then cancels.
            guard Task.isCancelled == false
            else
            {
                return
            }

            self.prepareFramePreviews()
        }
    }

    /// Renders every not-yet-rendered frame in the background, so the carousel shows
    /// a thumbnail preview for each frame rather than only the ones the user has
    /// selected. A no-op for a single-frame file.
    ///
    /// Render only: star detection stays lazy (see ``prepareSelectedFrame()``), so
    /// opening a multi-image cube does not run the full analysis on every plane up
    /// front. Each frame's render goes through the same ``WorkThrottle`` at normal
    /// priority, behind the selected frame's high-priority work, so filling the strip
    /// can never saturate the CPU or outrank what the user is waiting on. Frames that
    /// have already rendered (or failed) are skipped, and the pass bails promptly on
    /// cancellation (e.g. the file being closed).
    private func prepareFramePreviews()
    {
        let frames = self.frames

        guard frames.count > 1, let throttle = self.preparationThrottle
        else
        {
            return
        }

        let id = self.id

        self.framePreviewsTask = Task
        {
            for frame in frames
            {
                guard Task.isCancelled == false
                else
                {
                    return
                }

                // Skip a frame that already has a result (the primary frame, or one
                // the user has visited), that has already failed, or that a selection
                // is already rendering — neither path can see the other's render until
                // it commits a result, so the in-flight check is what keeps the two
                // from rendering the same frame twice.
                if frame.renderer.result != nil || frame.renderer.error != nil || frame.renderer.isRendering
                {
                    continue
                }

                await throttle.acquire( key: id, priority: .normal )

                defer { throttle.release() }

                guard Task.isCancelled == false, frame.renderer.result == nil, frame.renderer.error == nil, frame.renderer.isRendering == false
                else
                {
                    continue
                }

                await frame.renderer.render()
            }
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

    /// Cancels any in-flight preparation — the initial load/render/thumbnail work, any
    /// on-demand carousel frame-selection render, the background frame previews and
    /// every enqueued star analysis — e.g. when the file is closed. The tasks capture
    /// `self` weakly, so an un-cancelled task simply bails once the file is released —
    /// this just stops the work sooner.
    ///
    /// An analysis still waiting for a slot only learns it was cancelled once the pool
    /// hands it one, which may be long after the file is gone, so the frames are
    /// abandoned here rather than left reporting a detection that will never run.
    /// Abandoning releases the queued stage alone, so a detection already running or
    /// already finished is untouched.
    func cancelPreparation()
    {
        self.preparation?.cancel()
        self.framePreviewsTask?.cancel()

        self.frameSelectionTasks.values.forEach { $0.cancel() }

        self.analysisTasks.values.forEach { $0.cancel() }
        self.frames.forEach { $0.markStarDetectionAbandoned() }
    }

    /// Awaits every on-demand frame preparation this file had started when this was
    /// called — each selected frame's render, up to the point its analysis is enqueued.
    ///
    /// Internal: a selection no longer replaces the one before it, so there is no single
    /// task to await; the application observes each frame's result as it is published
    /// and only the tests need a point to wait at.
    func awaitFrameSelection() async
    {
        for task in self.frameSelectionTasks.values
        {
            await task.value
        }
    }

    /// Awaits every star analysis this file had enqueued when this was called.
    ///
    /// The analyses run on their own pool, outside the preparation, so a caller that
    /// needs what detection produces — the star field, and the metrics the weighting
    /// derives from it — awaits this rather than ``preparation``. Internal, since the
    /// application observes those results as they are published and only the tests
    /// need a point to wait at.
    func awaitStarDetection() async
    {
        for task in self.analysisTasks.values
        {
            await task.value
        }
    }

    /// Copies the original, unmodified file to a destination, byte for byte.
    ///
    /// This is the "Save As…" action: it duplicates the source file exactly,
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

    /// Generates a thumbnail from the primary frame's rendered image, downscaled so
    /// its longest side is at most `maxDimension` pixels. A no-op when nothing has
    /// rendered yet.
    ///
    /// The sidebar row represents the file, so its thumbnail tracks the primary
    /// (first) frame rather than the carousel selection — matching the render the
    /// ``thumbnailObserver`` watches. For a single-frame file the primary frame is
    /// the only frame, so this is the displayed image.
    ///
    /// - Parameter maxDimension: The maximum width or height of the thumbnail.
    public func makeThumbnail( maxDimension: Int ) async
    {
        guard let source = self.loader.image?.renderer.result?.image
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
