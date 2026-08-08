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

/// Tests for `WindowModel`: open appends and auto-selects, close removes and
/// keeps a valid selection.
@Suite( "WindowModel" )
struct WindowModelTests
{
    private var fixtureURLs: [ URL ]
    {
        [
            TestFixtures.monoImage,
            TestFixtures.monoImage,
        ]
    }

    @Test
    @MainActor
    func openAppendsAndSelectsFirstWhenEmpty() throws
    {
        let model = WindowModel()

        model.open( urls: self.fixtureURLs )

        #expect( model.files.count == 2 )
        #expect( model.selectedFileID == model.files.first?.id, "opening into an empty window selects the first new file" )
    }

    @Test
    @MainActor
    func openKeepsExistingSelection() throws
    {
        let model = WindowModel()

        model.open( urls: [ self.fixtureURLs[ 0 ] ] )

        let firstID = try #require( model.selectedFileID )

        model.open( urls: [ self.fixtureURLs[ 1 ] ] )

        #expect( model.files.count == 2 )
        #expect( model.selectedFileID == firstID, "opening more files must not steal an existing selection" )
    }

    @Test
    @MainActor
    func closingSelectedSelectsAnotherFile()  throws
    {
        let model = WindowModel()

        model.open( urls: self.fixtureURLs )

        let selected = try #require( model.selectedFile )

        model.close( selected )

        #expect( model.files.count == 1 )
        #expect( model.selectedFileID == model.files.first?.id, "closing the selected file selects a remaining one" )
    }

    @Test
    @MainActor
    func closingAFileNotifiesWithItsID() throws
    {
        let model = WindowModel()

        model.open( urls: self.fixtureURLs )

        let closed        = try #require( model.selectedFile )
        var notifiedIDs: [ OpenFile.ID ] = []

        model.onFileClosed = { notifiedIDs.append( $0 ) }

        model.close( closed )

        // The host wires this to dismiss the file's plate-solve window and end its
        // solve, so closing an image never leaves that window behind.
        #expect( notifiedIDs == [ closed.id ] )
    }

    @Test
    @MainActor
    func closingLastFileClearsSelection() throws
    {
        let model = WindowModel()

        model.open( urls: [ self.fixtureURLs[ 0 ] ] )

        let only = try #require( model.selectedFile )

        model.close( only )

        #expect( model.files.isEmpty )
        #expect( model.selectedFileID == nil )
    }

    @Test
    @MainActor
    func openPreparesEachFile() async throws
    {
        let model = WindowModel()

        model.open( urls: self.fixtureURLs )

        for file in model.files
        {
            await file.preparation?.value
        }

        #expect( model.files.isEmpty == false )
        #expect( model.files.allSatisfy { $0.renderPhase == .ready }, "opening a file renders it without waiting to be displayed" )
    }

    @Test
    @MainActor
    func closingAFileCancelsItsPreparation() throws
    {
        let model = WindowModel()

        model.open( urls: [ self.fixtureURLs[ 0 ] ] )

        let file = try #require( model.files.first )

        model.close( file )

        #expect( file.preparation?.isCancelled == true, "closing a file cancels its in-flight preparation" )
    }

    @Test
    @MainActor
    func reportsWhetherAnyOpenFileHasAdjustments() async throws
    {
        let model = WindowModel()

        // An empty window has nothing to lose, so no confirmation is warranted.
        #expect( model.hasAdjustedFiles == false )

        model.open( urls: [ TestFixtures.monoImage ] )

        let file = try #require( model.files.first )

        await file.preparation?.value

        // A freshly loaded, untouched file is not "adjusted".
        #expect( model.hasAdjustedFiles == false )

        let renderer = try #require( file.image?.renderer )

        // Any deviation from the defaults counts — `hasAdjustments` reads the
        // settings snapshot immediately, without needing a re-render.
        renderer.adjustments.invert = true

        #expect( model.hasAdjustedFiles, "a window with an adjusted file reports it, so a close can warn" )
    }

    @Test
    @MainActor
    func trashingAFileTrashesItAndRemovesItFromTheModel() throws
    {
        let url = URL( fileURLWithPath: NSTemporaryDirectory() ).appendingPathComponent( "FITScopeTrashTest-\( UUID().uuidString ).fits" )

        try Data( "dummy".utf8 ).write( to: url )

        defer { try? FileManager.default.removeItem( at: url ) }

        let model = WindowModel()

        model.open( urls: [ url ] )

        let file = try #require( model.files.first )

        try model.trash( file )

        #expect( model.files.isEmpty, "trashing a file removes its entry from the window" )
        #expect( FileManager.default.fileExists( atPath: url.path ) == false, "trashing moves the original file out of its location" )
    }

    // MARK: - Render priority

    /// Changing the selection promotes the selected file's still-waiting render in
    /// the shared throttle, so it jumps ahead of files queued earlier — the
    /// responsiveness win when navigating to a not-yet-rendered file.
    @Test( .timeLimit( .minutes( 1 ) ) )
    @MainActor
    func selectingAFilePromotesItsWaitingRenderInTheThrottle() async throws
    {
        let throttle = WorkThrottle( limit: 1 )
        let model    = WindowModel( preparationThrottle: throttle, analysisThrottle: WorkThrottle( limit: 1 ) )

        // Hold the only slot so the two simulated renders below must wait.
        await throttle.acquire( key: "held" )

        let earlier  = UUID()
        let selected = UUID()

        var order: [ UUID ] = []

        // Each waiter hands its slot on when it is done, so the single release below
        // is enough to drain both and the pool ends as balanced as it started.
        //
        // The "earlier" render enqueues first, so under plain FIFO it would win.
        let earlierWaiter = Task
        { @MainActor in
            await throttle.acquire( key: earlier )
            order.append( earlier )
            throttle.release()
        }

        try await throttle.waitForWaiters( 1 )

        let selectedWaiter = Task
        { @MainActor in
            await throttle.acquire( key: selected )
            order.append( selected )
            throttle.release()
        }

        // Pin the scenario: both are suspended in the queue, so promoting one is what
        // decides the order rather than which task happened to get there first.
        try await throttle.waitForWaiters( 2 )

        // Selecting the later file must bump its render ahead of the earlier one.
        model.selectedFileID = selected

        throttle.release()

        await selectedWaiter.value
        await earlierWaiter.value

        #expect( order == [ selected, earlier ], "selecting a file promotes its waiting render ahead of earlier ones" )
    }

    /// Changing the selection promotes the selected file's still-waiting *analysis*
    /// too, not only its render. Both pools key on the file's identifier, so a file
    /// selected after its analysis has queued would otherwise sit behind every
    /// background file's detection.
    @Test( .timeLimit( .minutes( 1 ) ) )
    @MainActor
    func selectingAFilePromotesItsWaitingAnalysisInTheThrottle() async throws
    {
        let throttle = WorkThrottle( limit: 1 )
        let model    = WindowModel( preparationThrottle: WorkThrottle( limit: 1 ), analysisThrottle: throttle )

        // Hold the only slot so the two simulated analyses below must wait.
        await throttle.acquire( key: "held" )

        let earlier  = UUID()
        let selected = UUID()

        var order: [ UUID ] = []

        // Each waiter hands its slot on when it is done, so the single release below
        // is enough to drain both and the pool ends as balanced as it started.
        //
        // The "earlier" analysis enqueues first, so under plain FIFO it would win.
        let earlierWaiter = Task
        { @MainActor in
            await throttle.acquire( key: earlier )
            order.append( earlier )
            throttle.release()
        }

        try await throttle.waitForWaiters( 1 )

        let selectedWaiter = Task
        { @MainActor in
            await throttle.acquire( key: selected )
            order.append( selected )
            throttle.release()
        }

        // Pin the scenario: both are suspended in the queue, so promoting one is what
        // decides the order rather than which task happened to get there first.
        try await throttle.waitForWaiters( 2 )

        // Selecting the later file must bump its analysis ahead of the earlier one.
        model.selectedFileID = selected

        throttle.release()

        await selectedWaiter.value
        await earlierWaiter.value

        #expect( order == [ selected, earlier ], "selecting a file promotes its waiting analysis ahead of earlier ones" )
    }

    /// Files opened through the window are prepared against the *window's* analysis
    /// pool, so the pool sized for the machine is the one that actually bounds how many
    /// detections run at once — rather than each file analysing unbounded on its own.
    @Test( .timeLimit( .minutes( 1 ) ) )
    @MainActor
    func opensFilesAgainstTheWindowsAnalysisPool() async throws
    {
        let analysis = WorkThrottle( limit: 1 )
        let model    = WindowModel( preparationThrottle: WorkThrottle( limit: 2 ), analysisThrottle: analysis )

        // Hold the window pool's only slot: a file prepared against it can enqueue its
        // analysis but never start it.
        await analysis.acquire()

        defer { analysis.release() }

        defer { model.files.forEach { $0.cancelPreparation() } }

        model.open( urls: self.fixtureURLs )

        for file in model.files
        {
            await file.preparation?.value
        }

        #expect( model.files.count == 2 )

        // Both analyses suspend in *this* pool, which is what a file prepared against
        // any other pool could not do.
        try await analysis.waitForWaiters( 2 )

        #expect(
            model.files.allSatisfy { $0.image?.isDetectingStars == true },
            "every opened file's analysis is waiting rather than run"
        )
    }

    // MARK: - Work pools

    /// The window's worker budget is divided between the two pools rather than
    /// each claiming it whole, with preparation keeping the larger share.
    @Test( arguments: [
        (  6,  3, 1 ),
        (  8,  4, 2 ),
        ( 10,  6, 2 ),
        ( 12,  7, 3 ),
        ( 16, 10, 4 ),
    ] )
    func dividesTheWorkerBudgetBetweenPreparationAndAnalysis( processorCount: Int, preparation: Int, analysis: Int ) throws
    {
        let limits = WindowModel.throttleLimits( processorCount: processorCount )

        #expect( limits.preparation == preparation, "preparation keeps the larger share of the worker budget" )
        #expect( limits.analysis    == analysis,    "analysis takes a third of the worker budget" )
    }

    /// From five cores up the division is exact: within a window the two pools
    /// claim the whole worker budget between them and no more, so running analyses
    /// beside preparations does not raise that window's ceiling.
    @Test
    func theTwoPoolsDivideTheWindowWorkerBudgetExactly() throws
    {
        ( 5 ... 32 ).forEach
        {
            processorCount in

            let limits = WindowModel.throttleLimits( processorCount: processorCount )

            #expect(
                limits.preparation + limits.analysis == max( 2, processorCount - 2 ),
                "\( processorCount ) cores: the two pools divide the window's worker budget exactly"
            )
        }
    }

    /// A machine too small to divide keeps both pools usable rather than
    /// arithmetically exact: the floors win, and their sum exceeds the budget.
    @Test
    func aSmallMachineKeepsBothPoolsUsable() throws
    {
        ( 1 ... 4 ).forEach
        {
            processorCount in

            let limits = WindowModel.throttleLimits( processorCount: processorCount )

            #expect( limits.preparation == 2, "\( processorCount ) cores: preparation never drops below two files at once" )
            #expect( limits.analysis    == 1, "\( processorCount ) cores: analysis never drops below one detection at once" )
        }
    }

    /// Analysis always takes the minority share of the budget, at every core count,
    /// so preparation keeps the majority of a window's slots.
    @Test
    func analysisAlwaysTakesTheMinorityShare() throws
    {
        ( 1 ... 32 ).forEach
        {
            processorCount in

            let limits = WindowModel.throttleLimits( processorCount: processorCount )

            #expect( limits.analysis < limits.preparation, "\( processorCount ) cores: analysis never claims as many slots as preparation" )
        }
    }

    /// The window sizes both pools from its worker budget, in the right order, and
    /// keeps them separate — so neither can consume the other's slots.
    @Test
    @MainActor
    func sizesItsTwoPoolsFromTheWindowWorkerBudget() throws
    {
        let model  = WindowModel()
        let limits = WindowModel.throttleLimits( processorCount: ProcessInfo.processInfo.activeProcessorCount )

        #expect( model.preparationThrottle.limit == limits.preparation, "the preparation pool is sized from the worker budget" )
        #expect( model.analysisThrottle.limit    == limits.analysis,    "the analysis pool is sized from the worker budget" )
        #expect( model.preparationThrottle !== model.analysisThrottle,  "the two pools are separate" )
    }

    // MARK: - Weighting

    /// After a file finishes analysis, the window computes its weight from the
    /// gathered metrics and the formula — here a purely per-image formula, so a
    /// single image is still ranked.
    @Test
    @MainActor
    func computesPerImageWeightFromMetricsAfterAnalysis() async throws
    {
        let model = WindowModel()

        model.weightFormulaSource = "Stars + 1"
        model.open( urls: [ TestFixtures.monoImage ] )

        let file = try #require( model.files.first )

        await file.preparation?.value

        // The metrics come from the star analysis, which settles on its own pool
        // outside the preparation, so it needs its own await point.
        await file.awaitStarDetection()

        model.recomputeWeights()

        let stars = try #require( file.metrics[ .stars ], "analysis should have produced a star count" )

        #expect( file.weight == stars + 1 )
    }

    /// The default formula ranks images against the set, so a lone image cannot be
    /// weighted and its weight stays absent.
    @Test
    @MainActor
    func singleImageHasNoWeightUnderTheDefaultSetWideFormula() async throws
    {
        let model = WindowModel()

        model.open( urls: [ TestFixtures.monoImage ] )

        let file = try #require( model.files.first )

        await file.preparation?.value
        await file.awaitStarDetection()

        model.recomputeWeights()

        #expect( file.weight == nil )
    }
}
