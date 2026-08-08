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
import SwiftFITS
import Testing

/// A stub loader that vends a fixed list of already-built frames, so multi-frame
/// selection can be exercised without a real multi-image file format (which no
/// format produces yet). Overriding ``ImageLoading/frames`` is exactly what a
/// future multi-image loader does.
@MainActor
private final class StubMultiFrameLoader: ObservableObject, ImageLoading
{
    /// The fixed frames the loader vends.
    let frames: [ LoadedImage ]

    /// No load error — the frames are supplied ready.
    let error: ( any Swift.Error )? = nil

    /// Creates a loader over the given frames.
    ///
    /// - Parameter frames: The frames to vend.
    init( frames: [ LoadedImage ] )
    {
        self.frames = frames
    }

    /// The primary (first) frame.
    var image: LoadedImage?
    {
        self.frames.first
    }

    /// Emits the primary frame once.
    var imagePublisher: AnyPublisher< LoadedImage?, Never >
    {
        Just( self.frames.first ).eraseToAnyPublisher()
    }

    /// Nothing to parse — the frames are supplied ready.
    func load() async
    {}
}

/// A stub loader that provides only ``image`` (not ``frames``), to verify the
/// protocol's default single-frame derivation.
@MainActor
private final class StubSingleImageLoader: ObservableObject, ImageLoading
{
    /// The single loaded image, if any.
    let image: LoadedImage?

    /// No load error.
    let error: ( any Swift.Error )? = nil

    /// Creates a loader over an optional single image.
    ///
    /// - Parameter image: The image to vend, or `nil`.
    init( image: LoadedImage? )
    {
        self.image = image
    }

    /// Emits the image once.
    var imagePublisher: AnyPublisher< LoadedImage?, Never >
    {
        Just( self.image ).eraseToAnyPublisher()
    }

    /// Nothing to parse.
    func load() async
    {}
}

/// Tests for ``OpenFile``'s multi-frame model: the frame list, the selected
/// frame, and selection driving the displayed image and its render.
@Suite( "OpenFile frames" )
struct OpenFileFramesTests
{
    /// Builds a real, renderable ``LoadedImage`` from the mono fixture. Each call
    /// yields a distinct instance, so a list of them models distinct frames.
    @MainActor
    private static func makeImage() throws -> LoadedImage
    {
        let url      = TestFixtures.monoImage
        let file     = try FITSFile( data: Data( contentsOf: url ), options: .lenient )
        let info     = FITSImageInfo( url: url, file: file )
        let renderer = ImageRenderer( file: file )

        return LoadedImage( info: info, renderer: renderer )
    }

    /// A loader that provides only `image` derives a single-frame list from it.
    @Test
    @MainActor
    func singleImageLoaderDerivesOneFrame() throws
    {
        let image  = try Self.makeImage()
        let loader = StubSingleImageLoader( image: image )

        #expect( loader.frames.count == 1 )
        #expect( loader.frames.first === image )
    }

    /// A loader with no image derives an empty frame list.
    @Test
    @MainActor
    func imagelessLoaderDerivesNoFrames() throws
    {
        let loader = StubSingleImageLoader( image: nil )

        #expect( loader.frames.isEmpty )
    }

    /// A freshly opened multi-frame file shows its first frame.
    @Test
    @MainActor
    func defaultsToFirstFrame() throws
    {
        let frames = [ try Self.makeImage(), try Self.makeImage() ]
        let file   = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )

        #expect( file.frames.count == 2 )
        #expect( file.selectedFrameIndex == 0 )
        #expect( file.image === frames[ 0 ] )
    }

    /// Selecting a frame changes both the index and the displayed image.
    @Test
    @MainActor
    func selectFrameChangesDisplayedImage() throws
    {
        let frames = [ try Self.makeImage(), try Self.makeImage() ]
        let file   = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )

        file.selectFrame( 1 )

        #expect( file.selectedFrameIndex == 1 )
        #expect( file.image === frames[ 1 ] )
    }

    /// Selecting an out-of-range index is ignored, leaving the selection intact.
    @Test
    @MainActor
    func selectFrameIgnoresOutOfRange() throws
    {
        let frames = [ try Self.makeImage(), try Self.makeImage() ]
        let file   = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )

        file.selectFrame( 9 )
        #expect( file.selectedFrameIndex == 0 )

        file.selectFrame( -1 )
        #expect( file.selectedFrameIndex == 0 )
    }

    /// Selecting a frame that has not rendered yet renders it, so the newly shown
    /// frame produces a displayable result.
    @Test
    @MainActor
    func selectFrameRendersTheSelectedFrame() async throws
    {
        let frames = [ try Self.makeImage(), try Self.makeImage() ]
        let file   = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )

        #expect( frames[ 1 ].renderer.result == nil )

        file.selectFrame( 1 )
        await file.awaitFrameSelection()

        #expect( frames[ 1 ].renderer.result != nil, "selecting a not-yet-rendered frame must render it" )
    }

    /// Preparing a multi-frame file renders every frame in the background, so the
    /// carousel can show a thumbnail preview for each frame — not only the primary or
    /// the frames the user has visited.
    @Test
    @MainActor
    func preparingRendersPreviewsForAllFrames() async throws
    {
        let frames   = [ try Self.makeImage(), try Self.makeImage(), try Self.makeImage() ]
        let file     = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )
        let throttle = WorkThrottle( limit: 2 )

        #expect( frames.allSatisfy { $0.renderer.result == nil } )

        file.prepare( preparationThrottle: throttle, analysisThrottle: WorkThrottle( limit: 1 ) )

        await file.preparation?.value
        await file.framePreviewsTask?.value

        #expect( frames.allSatisfy { $0.renderer.result != nil }, "every frame must render so the carousel can preview it" )
    }

    /// Selecting a frame renders it within the preparation slot but enqueues its star
    /// analysis on the analysis pool, so scrubbing the carousel no longer holds a
    /// high-priority preparation slot for the length of a detection.
    ///
    /// The analysis pool's only slot is held here, so the enqueued detection cannot
    /// start — which makes "the frame is rendered" and "its detection has not run"
    /// simultaneously observable.
    @Test( .timeLimit( .minutes( 1 ) ) )
    @MainActor
    func selectingAFrameEnqueuesItsAnalysisRatherThanRunningItInTheRenderSlot() async throws
    {
        let frames   = [ try Self.makeImage(), try Self.makeImage() ]
        let file     = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )
        let analysis = WorkThrottle( limit: 1 )

        await analysis.acquire()

        defer { analysis.release() }

        // Cancelled before the slot is handed back, so the queued analysis takes it,
        // finds itself cancelled and gives it straight back rather than detecting into
        // the tests that follow. Defers run last-in-first-out, so this runs first.
        defer { file.cancelPreparation() }

        file.prepare( preparationThrottle: WorkThrottle( limit: 2 ), analysisThrottle: analysis )

        await file.preparation?.value

        file.selectFrame( 1 )

        await file.awaitFrameSelection()

        // Whichever path rendered it — the selection's own task, or the background
        // previews it deferred to — the render is awaited before it is asserted.
        await file.framePreviewsTask?.value

        #expect( frames[ 1 ].renderer.result != nil, "the newly selected frame is still rendered" )

        #expect( frames[ 1 ].isDetectingStars,          "its analysis is enqueued and reports as in progress" )
        #expect( frames[ 1 ].hasDetectedStars == false, "the frame selection settled without waiting for the detection" )
    }

    /// Preparing a multi-frame file analyses its *first* frame and no other: the rest are
    /// rendered for their carousel previews but left unanalysed, so opening a cube does
    /// not run the full analysis on every plane. A frame is analysed when it is selected,
    /// and only that frame.
    @Test( .timeLimit( .minutes( 1 ) ) )
    @MainActor
    func onlyTheFirstFrameIsAnalysedUntilTheOthersAreSelected() async throws
    {
        let frames   = [ try Self.makeImage(), try Self.makeImage(), try Self.makeImage() ]
        let file     = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )
        let analysis = WorkThrottle( limit: 1 )

        // Hold the only analysis slot, so an enqueued analysis stays observable as queued
        // rather than running and settling.
        await analysis.acquire()

        defer { analysis.release() }

        defer { file.cancelPreparation() }

        file.prepare( preparationThrottle: WorkThrottle( limit: 2 ), analysisThrottle: analysis )

        await file.preparation?.value
        await file.framePreviewsTask?.value

        #expect( frames.allSatisfy { $0.renderer.result != nil }, "every frame is still rendered for its carousel preview" )

        #expect( frames[ 0 ].isDetectingStars,          "the preparation analyses the first frame" )
        #expect( frames[ 1 ].isDetectingStars == false, "and leaves the frames the user has not visited alone" )
        #expect( frames[ 2 ].isDetectingStars == false )

        file.selectFrame( 2 )

        await file.awaitFrameSelection()

        #expect( frames[ 2 ].isDetectingStars,          "selecting a frame analyses it" )
        #expect( frames[ 1 ].isDetectingStars == false, "and only it" )
    }

    /// A frame the user selects is analysed ahead of one queued before it: the carousel
    /// enqueues at `.high`, so scrubbing does not leave the frame on screen behind the
    /// analyses of the frames it was reached through.
    @Test( .timeLimit( .minutes( 1 ) ) )
    @MainActor
    func aSelectedFramesAnalysisIsServedBeforeOneQueuedEarlier() async throws
    {
        let frames   = [ try Self.makeImage(), try Self.makeImage() ]
        let file     = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )
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

        // Cancelled before the slot is handed back, so the queued analysis takes it,
        // finds itself cancelled and gives it straight back rather than detecting into
        // the tests that follow. Defers run last-in-first-out, so this runs first.
        defer { file.cancelPreparation() }

        // The primary frame's analysis queues first, at the preparation's background
        // priority, so under plain FIFO it would be served first.
        file.prepare( preparationThrottle: WorkThrottle( limit: 2 ), analysisThrottle: analysis, priority: .normal )

        await file.preparation?.value

        observers.append( frames[ 0 ].$starDetectionPhase.sink { if $0 == .running { order.append( "primary" ) } } )

        try await analysis.waitForWaiters( 1 )

        file.selectFrame( 1 )

        await file.awaitFrameSelection()

        observers.append( frames[ 1 ].$starDetectionPhase.sink { if $0 == .running { order.append( "selected" ) } } )

        // Pin the scenario: both are suspended in the queue, so the order below is
        // decided by the priority they were enqueued at.
        try await analysis.waitForWaiters( 2 )

        #expect( frames[ 0 ].isDetectingStars, "the primary frame's analysis is queued" )
        #expect( frames[ 1 ].isDetectingStars, "the selected frame's analysis is queued" )

        holdsTheAnalysisSlot = false

        analysis.release()

        await file.awaitStarDetection()

        #expect( order == [ "selected", "primary" ], "the frame the user selected is analysed ahead of the one queued before it" )
    }

    /// A file closed *while it was rendering* starts no background frame previews.
    /// Neither the render nor the thumbnail wait is cancellable, so the preparation runs
    /// on past the cancellation and reaches the point where it would spawn them — a
    /// fresh task that `cancelPreparation()` has already been past and so would never
    /// cancel, rendering every remaining frame of a file that is gone.
    @Test( .timeLimit( .minutes( 1 ) ) )
    @MainActor
    func aFileClosedWhileItRenderedStartsNoFramePreviews() async throws
    {
        let frames = [ try Self.makeImage(), try Self.makeImage(), try Self.makeImage() ]
        let file   = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )

        var cancelledDuringTheRender = false

        // The renderer commits its result on the main actor from inside `render()`, so
        // closing from that commit lands while the preparation is still suspended there.
        let observer = frames[ 0 ].renderer.$result
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

        file.prepare( preparationThrottle: WorkThrottle( limit: 2 ), analysisThrottle: WorkThrottle( limit: 1 ) )

        await file.preparation?.value

        #expect( cancelledDuringTheRender, "the file must have been closed while it rendered for this to prove anything" )

        #expect( file.framePreviewsTask == nil,      "a file closed while it rendered starts no previews" )
        #expect( frames[ 1 ].renderer.result == nil, "so the frames they would have filled in stay unrendered" )
        #expect( frames[ 2 ].renderer.result == nil )
    }

    /// Selecting a frame whose render is already in flight — the background previews
    /// reached it first — does not render it a second time. Neither path can see the
    /// other's render until it commits a result, so the in-flight check is what keeps
    /// them apart; the analysis is still enqueued, since it reads the render source
    /// rather than the rendered result.
    @Test( .timeLimit( .minutes( 1 ) ) )
    @MainActor
    func selectingAFrameAlreadyBeingRenderedDoesNotRenderItTwice() async throws
    {
        let frames = [ try Self.makeImage(), try Self.makeImage() ]
        let file   = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )

        var renders = 0

        // `isRendering` is set as each render claims its generation, so every start is
        // counted — including one whose result is later discarded as superseded.
        let observer = frames[ 1 ].renderer.$isRendering.sink { if $0 { renders += 1 } }

        defer { observer.cancel() }

        let rendering = Task { await frames[ 1 ].renderer.render() }

        var attempts = 0

        while frames[ 1 ].renderer.isRendering == false, attempts < 10_000
        {
            attempts += 1

            await Task.yield()
        }

        #expect( frames[ 1 ].renderer.isRendering, "the render must be in flight before selecting the frame proves anything" )

        file.selectFrame( 1 )

        await file.awaitFrameSelection()
        await rendering.value
        await file.awaitStarDetection()

        #expect( renders == 1, "a frame already being rendered is not rendered again" )

        #expect( frames[ 1 ].renderer.result != nil, "the render in flight still produces the frame" )
        #expect( frames[ 1 ].hasDetectedStars,       "and the selection still analyses it" )
    }

    /// Selecting another frame does not stop the frame the user has left: its render
    /// finishes and its analysis is enqueued, so every frame visited is prepared to
    /// completion and is ready on a return visit.
    @Test( .timeLimit( .minutes( 1 ) ) )
    @MainActor
    func selectingAnotherFrameDoesNotStopThePreviousFramesPreparation() async throws
    {
        let frames = [ try Self.makeImage(), try Self.makeImage(), try Self.makeImage() ]
        let file   = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )

        // Both selections are made before either is awaited, so the second lands while
        // the first has been started and not yet run.
        file.selectFrame( 1 )
        file.selectFrame( 2 )

        await file.awaitFrameSelection()
        await file.awaitStarDetection()

        #expect( frames[ 1 ].renderer.result != nil, "the frame left behind is still rendered" )
        #expect( frames[ 1 ].hasDetectedStars,       "and still analysed" )

        #expect( frames[ 2 ].renderer.result != nil, "as is the frame moved to" )
        #expect( frames[ 2 ].hasDetectedStars )
    }

    /// A frame selection cancelled *while its frame rendered* enqueues no analysis. The
    /// render is not cancellable, so the selection runs on past the cancellation and
    /// reaches the enqueue — which closing the file has already been past, and so could
    /// neither cancel nor abandon.
    ///
    /// The renderer commits its result on the main actor from inside `render()`, so
    /// cancelling from that commit lands in exactly the window the guard covers.
    @Test( .timeLimit( .minutes( 1 ) ) )
    @MainActor
    func aFrameSelectionCancelledWhileItRenderedEnqueuesNoAnalysis() async throws
    {
        let frames = [ try Self.makeImage(), try Self.makeImage() ]
        let file   = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )

        defer { file.cancelPreparation() }

        // The file is deliberately not prepared: with no background previews there is no
        // other render of this frame for the selection to defer to, so the selection is
        // the render that commits its result.
        #expect( frames[ 1 ].renderer.result == nil, "the frame must be unrendered for its selection to render it" )

        var cancelledDuringTheRender = false

        let observer = frames[ 1 ].renderer.$result
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

        file.selectFrame( 1 )

        await file.awaitFrameSelection()

        #expect( cancelledDuringTheRender, "the selection must have been cancelled while it rendered for this to prove anything" )

        #expect( frames[ 1 ].isDetectingStars == false, "a selection cancelled while it rendered enqueues no analysis" )
        #expect( frames[ 1 ].hasDetectedStars == false, "and none runs" )
    }

    /// Returning to a frame whose stars have already been detected does not enqueue a
    /// second analysis for it — which would drop the Analysis tab's populated star grid
    /// back to a spinner and set the toolbar's Stars button pulsing again, for a
    /// detection that can only produce what is already there.
    @Test
    @MainActor
    func revisitingAnAnalysedFrameDoesNotEnqueueASecondAnalysis() async throws
    {
        let frames = [ try Self.makeImage(), try Self.makeImage() ]
        let file   = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )

        // Cancelled before the slot is handed back, so the queued analysis takes it,
        // finds itself cancelled and gives it straight back rather than detecting into
        // the tests that follow. Defers run last-in-first-out, so this runs first.
        defer { file.cancelPreparation() }

        file.prepare( preparationThrottle: WorkThrottle( limit: 2 ), analysisThrottle: WorkThrottle( limit: 1 ) )

        await file.preparation?.value
        await file.awaitStarDetection()

        #expect( frames[ 0 ].hasDetectedStars, "the primary frame must have been analysed before a revisit means anything" )

        var runs = 0

        let observer = frames[ 0 ].$starDetectionPhase.sink { if $0 == .running { runs += 1 } }

        defer { observer.cancel() }

        file.selectFrame( 1 )

        await file.awaitFrameSelection()

        #expect( file.image === frames[ 1 ], "the selection must have moved away before returning means anything" )

        file.selectFrame( 0 )

        await file.awaitFrameSelection()
        await file.awaitStarDetection()

        #expect( file.image === frames[ 0 ], "and must have returned to the analysed frame" )

        #expect( runs == 0, "an already analysed frame is not analysed again when it is shown once more" )
    }

    /// The file republishes when the selected (non-primary) frame renders, so the
    /// views observing the file — the canvas — refresh once the lazily prepared
    /// frame commits its result. Guards the selected-frame change forwarding.
    @Test
    @MainActor
    func republishesWhenSelectedFrameRenders() async throws
    {
        let frames = [ try Self.makeImage(), try Self.makeImage() ]
        let file   = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )

        // Select the frame first (which itself publishes the index change), then
        // start observing, so only the subsequent render commit is measured.
        file.selectFrame( 1 )

        var republished = false
        let observer    = file.objectWillChange.sink { _ in republished = true }

        await file.awaitFrameSelection()

        observer.cancel()

        #expect( republished, "the file must republish when the selected frame commits its render" )
    }
}
