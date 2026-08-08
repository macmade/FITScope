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
@testable import FITScope
import Foundation
import Testing

/// Tests for `OpenFile`: identity, URL exposure and load delegation.
@Suite( "OpenFile" )
struct OpenFileTests
{
    @Test
    @MainActor
    func exposesURLAndDisplayName() throws
    {
        let url  = TestFixtures.monoImage
        let file = OpenFile( url: url )

        #expect( file.url == url )
        #expect( file.displayName == "MonoImage.fits" )
    }

    @Test
    @MainActor
    func loadPopulatesImage() async throws
    {
        let url  = TestFixtures.monoImage
        let file = OpenFile( url: url )

        await file.load()

        #expect( file.image != nil, "a successful load must expose the image" )
        #expect( file.error == nil )
    }

    @Test
    @MainActor
    func distinctInstancesHaveDistinctIdentity() throws
    {
        let url = TestFixtures.monoImage

        #expect( OpenFile( url: url ).id != OpenFile( url: url ).id, "each open file is a distinct entry even for the same URL" )
    }

    @Test
    @MainActor
    func loadAndRenderProducesThumbnail() async throws
    {
        let url  = TestFixtures.monoImage
        let file = OpenFile( url: url )

        await file.load()
        await file.image?.renderer.render()
        await file.makeThumbnail( maxDimension: 64 )

        let thumbnail = try #require( file.thumbnail )

        #expect( thumbnail.width <= 64 && thumbnail.height <= 64, "thumbnail is bounded by the requested max dimension" )
        #expect( thumbnail.width >= 1 && thumbnail.height >= 1 )
    }

    @Test
    func renderPhaseMapsPipelineState() throws
    {
        // Not yet parsed → loading.
        #expect( OpenFile.renderPhase( hasImage: false, hasResult: false, hasError: false, isRendering: false ) == .loading )

        // Parsed, no committed result yet → still rendering (the bug: this read
        // as "done" because it keyed off the parsed image, not the result).
        #expect( OpenFile.renderPhase( hasImage: true, hasResult: false, hasError: false, isRendering: false ) == .rendering )

        // Parsed and rendered → ready.
        #expect( OpenFile.renderPhase( hasImage: true, hasResult: true, hasError: false, isRendering: false ) == .ready )

        // A failure wins, whether it came from loading (no image) or rendering.
        #expect( OpenFile.renderPhase( hasImage: false, hasResult: false, hasError: true, isRendering: false ) == .failed )
        #expect( OpenFile.renderPhase( hasImage: true,  hasResult: false, hasError: true, isRendering: false ) == .failed )
    }

    @Test
    func renderPhaseReportsRenderingWhileAReRenderIsInFlight() throws
    {
        // A re-render keeps the last good result committed, so without the
        // in-flight signal this would read as `.ready` and the sidebar spinner /
        // processing affordances would never show during a re-render.
        #expect( OpenFile.renderPhase( hasImage: true, hasResult: true, hasError: false, isRendering: true ) == .rendering )

        // Re-rendering away from a prior failed parameter is work in progress,
        // not a failure — the retained error must not win over the live render.
        #expect( OpenFile.renderPhase( hasImage: true, hasResult: true, hasError: true, isRendering: true ) == .rendering )
    }

    @Test
    func renderPhaseInProgressCoversLoadingAndRendering() throws
    {
        #expect( OpenFile.RenderPhase.loading.isInProgress )
        #expect( OpenFile.RenderPhase.rendering.isInProgress )
        #expect( OpenFile.RenderPhase.ready.isInProgress  == false )
        #expect( OpenFile.RenderPhase.failed.isInProgress == false )
    }

    @Test
    @MainActor
    func renderPhaseTracksLoadThenRender() async throws
    {
        let url  = TestFixtures.monoImage
        let file = OpenFile( url: url )

        #expect( file.renderPhase == .loading, "a freshly opened file is loading" )

        await file.load()
        await file.image?.renderer.render()

        #expect( file.renderPhase == .ready, "after loading and rendering the file is ready" )
    }

    @Test
    @MainActor
    func prepareLoadsRendersAndThumbnails() async throws
    {
        let file     = OpenFile( url: TestFixtures.monoImage )
        let throttle = WorkThrottle( limit: 2 )

        file.prepare( preparationThrottle: throttle, analysisThrottle: WorkThrottle( limit: 1 ) )

        await file.preparation?.value

        #expect( file.renderPhase == .ready, "prepare loads and renders the file without it being displayed" )
        #expect( file.thumbnail != nil, "prepare also produces the sidebar thumbnail" )
    }

    @Test
    @MainActor
    func thumbnailIsRegeneratedWhenTheRenderResultChanges() async throws
    {
        let file     = OpenFile( url: TestFixtures.monoImage )
        let throttle = WorkThrottle( limit: 2 )

        file.prepare( preparationThrottle: throttle, analysisThrottle: WorkThrottle( limit: 1 ) )

        await file.preparation?.value
        await file.thumbnailTask?.value

        let initial = try #require( file.thumbnail, "prepare must produce an initial thumbnail" )

        // Change an adjustment that alters the rendered pixels, then re-render:
        // the thumbnail must be regenerated to reflect the new processing rather
        // than staying at the originally rendered version.
        let renderer = try #require( file.image?.renderer )

        renderer.adjustments.invert = true

        await renderer.render()
        await file.thumbnailTask?.value

        let updated = try #require( file.thumbnail )

        #expect( updated !== initial, "a new render result must regenerate the sidebar thumbnail" )
    }

    @Test
    @MainActor
    func prepareIsIdempotent() async throws
    {
        let file     = OpenFile( url: TestFixtures.monoImage )
        let throttle = WorkThrottle( limit: 2 )

        file.prepare( preparationThrottle: throttle, analysisThrottle: WorkThrottle( limit: 1 ) )

        let started = try #require( file.preparation )

        // A second prepare while one is in flight must not start another.
        file.prepare( preparationThrottle: throttle, analysisThrottle: WorkThrottle( limit: 1 ) )

        await started.value
        await file.preparation?.value

        #expect( file.renderPhase == .ready )
    }


    // MARK: - Star analysis off the preparation slot

    /// The preparation covers load → render → thumbnail and no more: it settles while
    /// the star analysis is still waiting for an analysis slot, rather than holding
    /// its preparation slot until the detection has run.
    ///
    /// The analysis pool's only slot is held here, so the enqueued detection cannot
    /// start — which makes "the preparation finished" and "the detection has not run"
    /// simultaneously observable.
    @Test( .timeLimit( .minutes( 1 ) ) )
    @MainActor
    func preparationSettlesWithoutWaitingForTheStarAnalysis() async throws
    {
        let file     = OpenFile( url: TestFixtures.monoImage )
        let analysis = WorkThrottle( limit: 1 )

        await analysis.acquire()

        defer { analysis.release() }

        // Cancelled before the slot is handed back, so the queued analysis takes it,
        // finds itself cancelled and gives it straight back rather than detecting into
        // the tests that follow. Defers run last-in-first-out, so this runs first.
        defer { file.cancelPreparation() }

        file.prepare( preparationThrottle: WorkThrottle( limit: 2 ), analysisThrottle: analysis )

        await file.preparation?.value

        let image = try #require( file.image )

        #expect( file.renderPhase == .ready, "the preparation still loads and renders the file" )
        #expect( file.thumbnail  != nil,     "and still produces the sidebar thumbnail" )

        #expect( image.isDetectingStars,          "the analysis is enqueued and reports as in progress" )
        #expect( image.hasDetectedStars == false, "the preparation settled without waiting for the detection" )
    }

    /// One file's star detection no longer gates when the next file may be prepared:
    /// with a single preparation slot and no analysis slot at all, the second file
    /// still loads and renders while the first file's detection sits queued.
    @Test( .timeLimit( .minutes( 1 ) ) )
    @MainActor
    func aFilesDetectionNoLongerGatesTheNextFilesPreparation() async throws
    {
        let first    = OpenFile( url: TestFixtures.monoImage )
        let second   = OpenFile( url: TestFixtures.monoImage )
        let analysis = WorkThrottle( limit: 1 )

        // One preparation slot, so the second file can only be prepared once the
        // first has released it — and no analysis slot, so the first file's detection
        // cannot run at all.
        let preparation = WorkThrottle( limit: 1 )

        await analysis.acquire()

        defer { analysis.release() }

        // Cancelled before the slot is handed back, so the queued analysis takes it,
        // finds itself cancelled and gives it straight back rather than detecting into
        // the tests that follow. Defers run last-in-first-out, so this runs first.
        defer
        {
            first.cancelPreparation()
            second.cancelPreparation()
        }

        first.prepare( preparationThrottle: preparation, analysisThrottle: analysis )
        second.prepare( preparationThrottle: preparation, analysisThrottle: analysis )

        await second.preparation?.value

        let firstImage = try #require( first.image )

        #expect( firstImage.isDetectingStars,          "the first file's detection is still waiting for a slot" )
        #expect( firstImage.hasDetectedStars == false, "so it has not run" )
        #expect( second.renderPhase == .ready,         "yet the second file has loaded and rendered" )
    }

    /// The enqueued analysis inherits the preparation's priority, so the selected
    /// file's stars are not left behind every background file's detection.
    ///
    /// The background file is prepared first, so plain FIFO order would serve it
    /// first; the selected file's `.high` enqueue must overtake it.
    @Test( .timeLimit( .minutes( 1 ) ) )
    @MainActor
    func theSelectedFilesAnalysisIsServedBeforeABackgroundFilesAnalysis() async throws
    {
        let background = OpenFile( url: TestFixtures.monoImage )
        let selected   = OpenFile( url: TestFixtures.monoImage )
        let analysis   = WorkThrottle( limit: 1 )

        // Hold the only analysis slot, so both files enqueue and wait. The slot is
        // handed over explicitly below; the flag keeps the defer from releasing it a
        // second time, while still returning it if an expectation exits early.
        var holdsTheAnalysisSlot = true

        await analysis.acquire()

        defer
        {
            if holdsTheAnalysisSlot
            {
                analysis.release()
            }
        }

        var order:     [ String ]         = []
        var observers: [ AnyCancellable ] = []

        defer { observers.forEach { $0.cancel() } }

        background.prepare( preparationThrottle: WorkThrottle( limit: 2 ), analysisThrottle: analysis, priority: .normal )

        await background.preparation?.value

        let backgroundImage = try #require( background.image )

        observers.append( backgroundImage.$starDetectionPhase.sink { if $0 == .running { order.append( "background" ) } } )

        try await analysis.waitForWaiters( 1 )

        selected.prepare( preparationThrottle: WorkThrottle( limit: 2 ), analysisThrottle: analysis, priority: .high )

        await selected.preparation?.value

        let selectedImage = try #require( selected.image )

        observers.append( selectedImage.$starDetectionPhase.sink { if $0 == .running { order.append( "selected" ) } } )

        // Pin the scenario: both are suspended in the queue and neither has run, so the
        // order below is decided by the pool rather than by which file was prepared first.
        try await analysis.waitForWaiters( 2 )

        #expect( backgroundImage.isDetectingStars,          "the background file's analysis is queued" )
        #expect( selectedImage.isDetectingStars,            "the selected file's analysis is queued" )
        #expect( backgroundImage.hasDetectedStars == false, "and neither has run yet" )
        #expect( selectedImage.hasDetectedStars   == false )

        holdsTheAnalysisSlot = false

        analysis.release()

        await selected.awaitStarDetection()
        await background.awaitStarDetection()

        #expect( order == [ "selected", "background" ], "the selected file's analysis is served ahead of the background file's" )
    }

    /// A waiting analysis is enqueued under its *file's* identifier, which is what
    /// lets the window promote it when that file becomes the selection. Both files
    /// enqueue at the same priority here, so nothing but the promotion by key can
    /// change the order they are served in.
    @Test( .timeLimit( .minutes( 1 ) ) )
    @MainActor
    func aWaitingAnalysisIsPromotedByItsFilesIdentifier() async throws
    {
        let earlier  = OpenFile( url: TestFixtures.monoImage )
        let promoted = OpenFile( url: TestFixtures.monoImage )
        let analysis = WorkThrottle( limit: 1 )

        var holdsTheAnalysisSlot = true

        await analysis.acquire()

        defer
        {
            if holdsTheAnalysisSlot
            {
                analysis.release()
            }
        }

        var order:     [ String ]         = []
        var observers: [ AnyCancellable ] = []

        defer { observers.forEach { $0.cancel() } }

        earlier.prepare( preparationThrottle: WorkThrottle( limit: 2 ), analysisThrottle: analysis, priority: .normal )

        await earlier.preparation?.value

        let earlierImage = try #require( earlier.image )

        observers.append( earlierImage.$starDetectionPhase.sink { if $0 == .running { order.append( "earlier" ) } } )

        try await analysis.waitForWaiters( 1 )

        promoted.prepare( preparationThrottle: WorkThrottle( limit: 2 ), analysisThrottle: analysis, priority: .normal )

        await promoted.preparation?.value

        let promotedImage = try #require( promoted.image )

        observers.append( promotedImage.$starDetectionPhase.sink { if $0 == .running { order.append( "promoted" ) } } )

        // Pin the scenario: both are suspended in the queue at the same priority, so
        // plain FIFO would serve the earlier one first.
        try await analysis.waitForWaiters( 2 )

        #expect( earlierImage.isDetectingStars,  "the earlier file's analysis is queued" )
        #expect( promotedImage.isDetectingStars, "the later file's analysis is queued" )

        analysis.prioritize( key: promoted.id )

        holdsTheAnalysisSlot = false

        analysis.release()

        await promoted.awaitStarDetection()
        await earlier.awaitStarDetection()

        #expect( order == [ "promoted", "earlier" ], "promoting by the file's identifier reaches its waiting analysis" )
    }

    /// The analysis is enqueued as soon as the render returns, ahead of the thumbnail
    /// the preparation then waits for — `makeThumbnail` resizes on the global utility
    /// queue, which a folder of opening files saturates, so an analysis sequenced
    /// behind it would inherit that delay.
    @Test( .timeLimit( .minutes( 1 ) ) )
    @MainActor
    func theAnalysisIsEnqueuedAheadOfTheThumbnailRatherThanBehindIt() async throws
    {
        let file     = OpenFile( url: TestFixtures.monoImage )
        let analysis = WorkThrottle( limit: 1 )

        await analysis.acquire()

        defer { analysis.release() }

        var wasQueuedWhenTheThumbnailLanded: Bool?

        // `@Published` publishes on `willSet`, so this fires as the thumbnail is being
        // assigned — the moment the preparation's wait for it is ending.
        let observer = file.$thumbnail.sink
        {
            thumbnail in

            if thumbnail != nil, wasQueuedWhenTheThumbnailLanded == nil
            {
                wasQueuedWhenTheThumbnailLanded = file.image?.isDetectingStars
            }
        }

        defer { observer.cancel() }

        // Cancelled before the slot is handed back, so the queued analysis takes it,
        // finds itself cancelled and gives it straight back rather than detecting into
        // the tests that follow. Defers run last-in-first-out, so this runs first.
        defer { file.cancelPreparation() }

        file.prepare( preparationThrottle: WorkThrottle( limit: 2 ), analysisThrottle: analysis )

        await file.preparation?.value

        #expect( file.thumbnail != nil, "the thumbnail must have landed before its ordering means anything" )
        #expect( wasQueuedWhenTheThumbnailLanded == true, "the analysis was already queued when the thumbnail landed" )
    }

    /// Closing a file abandons a star analysis that is still queued, so the frame
    /// stops reporting a detection that will never run — without recording a run it
    /// never made.
    @Test( .timeLimit( .minutes( 1 ) ) )
    @MainActor
    func cancellingThePreparationAbandonsAQueuedAnalysis() async throws
    {
        let file     = OpenFile( url: TestFixtures.monoImage )
        let analysis = WorkThrottle( limit: 1 )

        await analysis.acquire()

        defer { analysis.release() }

        file.prepare( preparationThrottle: WorkThrottle( limit: 2 ), analysisThrottle: analysis )

        await file.preparation?.value

        let image = try #require( file.image )

        #expect( image.isDetectingStars, "the analysis must be queued before cancelling it means anything" )

        file.cancelPreparation()

        #expect( image.isDetectingStars == false, "a cancelled file stops reporting a detection that will never run" )
        #expect( image.hasDetectedStars == false, "and abandoned work records no run" )
    }

    /// Closing a file also stops a queued analysis from ever running, rather than only
    /// clearing what it reports. An enqueued analysis is an independent task — an
    /// unstructured task does not inherit its creator's cancellation — so without the
    /// explicit cancel it would take its slot and detect a frame nobody is looking at.
    @Test( .timeLimit( .minutes( 1 ) ) )
    @MainActor
    func cancellingThePreparationStopsAQueuedAnalysisFromRunning() async throws
    {
        let file     = OpenFile( url: TestFixtures.monoImage )
        let analysis = WorkThrottle( limit: 1 )

        var holdsTheAnalysisSlot = true

        await analysis.acquire()

        defer
        {
            if holdsTheAnalysisSlot
            {
                analysis.release()
            }
        }

        file.prepare( preparationThrottle: WorkThrottle( limit: 2 ), analysisThrottle: analysis )

        await file.preparation?.value

        let image = try #require( file.image )

        #expect( image.isDetectingStars, "the analysis must be queued before cancelling it means anything" )

        file.cancelPreparation()

        // Hand the slot over: a cancelled analysis must take it, find itself cancelled
        // and give it straight back rather than running the detection.
        holdsTheAnalysisSlot = false

        analysis.release()

        await file.awaitStarDetection()

        #expect( image.hasDetectedStars == false, "a cancelled analysis must not run the detection after all" )
        #expect( image.starField        == nil,   "so it publishes no results" )
    }

    /// A file closed *while it was rendering* enqueues no analysis at all. The render is
    /// not cancellable, so the preparation runs on past the cancellation and reaches the
    /// enqueue — which `cancelPreparation()` has already been past, and so could neither
    /// cancel nor abandon.
    ///
    /// The renderer commits its result on the main actor from inside `render()`, so
    /// cancelling from that commit lands in exactly the window the guard covers.
    @Test( .timeLimit( .minutes( 1 ) ) )
    @MainActor
    func aFileClosedWhileItRenderedEnqueuesNoAnalysis() async throws
    {
        let file     = OpenFile( url: TestFixtures.monoImage )
        let analysis = WorkThrottle( limit: 1 )

        await analysis.acquire()

        defer { analysis.release() }

        var cancelledDuringTheRender = false

        let observer = file.loader.imagePublisher
            .compactMap { $0 }
            .map { $0.renderer.$result }
            .switchToLatest()
            .compactMap { $0 }
            .sink
            {
                _ in

                guard cancelledDuringTheRender == false
                else
                {
                    return
                }

                cancelledDuringTheRender = true

                file.cancelPreparation()
            }

        defer { observer.cancel() }

        file.prepare( preparationThrottle: WorkThrottle( limit: 2 ), analysisThrottle: analysis )

        await file.preparation?.value

        let image = try #require( file.image )

        #expect( cancelledDuringTheRender, "the file must have been closed while it rendered for this to prove anything" )

        #expect( image.isDetectingStars == false, "a file closed while it rendered enqueues no analysis" )
        #expect( image.hasDetectedStars == false, "and none runs" )
    }

    @Test
    @MainActor
    func warningFlagsAFileThatCannotBeDisplayed() async throws
    {
        let file = OpenFile( url: TestFixtures.invalidImage )

        await file.load()
        await file.image?.renderer.render()

        #expect( file.warning != nil, "a file that fails to load must surface a warning for the attention icon" )
    }

    @Test
    @MainActor
    func noWarningForAHealthyFile() async throws
    {
        let file = OpenFile( url: TestFixtures.monoImage )

        await file.load()
        await file.image?.renderer.render()

        #expect( file.warning == nil, "a file that loads and renders has nothing to flag" )
    }

    @Test
    @MainActor
    func noWarningWhileStillLoading() throws
    {
        let file = OpenFile( url: TestFixtures.monoImage )

        #expect( file.warning == nil, "a file still loading has no failure to flag yet" )
    }

    @Test
    @MainActor
    func noWarningWhenABadAdjustmentRetainsTheLastGoodResult() async throws
    {
        let file = OpenFile( url: TestFixtures.monoImage )

        await file.load()
        await file.image?.renderer.render()

        let renderer = try #require( file.image?.renderer )

        #expect( file.warning == nil )

        // A mathematically invalid parameter fails the re-render, but the last
        // good result is retained and still displayed — so the row, which still
        // shows a usable image, must not be flagged.
        renderer.adjustments.stretch = .uniform( .init( shadows: 1, highlights: 0 ) )

        await renderer.render()

        #expect( renderer.error != nil, "the bad adjustment must have failed the render" )
        #expect( file.warning == nil, "a retained good result must not raise a warning" )
    }

    @Test
    @MainActor
    func copyingOriginalFileProducesAByteIdenticalCopy() throws
    {
        let bytes       = Data( ( 0 ..< 4096 ).map { UInt8( $0 % 256 ) } )
        let source      = Self.temporaryURL()
        let destination = Self.temporaryURL()

        try bytes.write( to: source )

        defer
        {
            try? FileManager.default.removeItem( at: source )
            try? FileManager.default.removeItem( at: destination )
        }

        let file = OpenFile( url: source )

        try file.copyOriginalFile( to: destination )

        #expect( try Data( contentsOf: destination ) == bytes, "the saved copy must be byte-identical to the original" )
    }

    @Test
    @MainActor
    func copyingOriginalFileOverwritesAnExistingDestination() throws
    {
        let original    = Data( ( 0 ..< 2048 ).map { UInt8( $0 % 256 ) } )
        let source      = Self.temporaryURL()
        let destination = Self.temporaryURL()

        try original.write( to: source )
        try Data( "stale contents".utf8 ).write( to: destination )

        defer
        {
            try? FileManager.default.removeItem( at: source )
            try? FileManager.default.removeItem( at: destination )
        }

        let file = OpenFile( url: source )

        try file.copyOriginalFile( to: destination )

        #expect( try Data( contentsOf: destination ) == original, "saving over an existing file replaces it with a byte-identical copy of the original" )
    }

    @Test
    @MainActor
    func copyingOriginalFileToItsOwnURLLeavesItIntact() throws
    {
        let original = Data( ( 0 ..< 1024 ).map { UInt8( $0 % 256 ) } )
        let source   = Self.temporaryURL()

        try original.write( to: source )

        defer { try? FileManager.default.removeItem( at: source ) }

        let file = OpenFile( url: source )

        // Saving a file onto itself must not delete-then-fail and lose the data.
        try file.copyOriginalFile( to: source )

        #expect( try Data( contentsOf: source ) == original, "saving a file onto itself must leave it intact" )
    }

    /// A unique temporary `.fits` URL for the file-copy tests.
    private static func temporaryURL() -> URL
    {
        URL( fileURLWithPath: NSTemporaryDirectory() ).appendingPathComponent( "FITScopeSaveAsTest-\( UUID().uuidString ).fits" )
    }
}
