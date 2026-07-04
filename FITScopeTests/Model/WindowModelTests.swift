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
    @Test
    @MainActor
    func selectingAFilePromotesItsWaitingRenderInTheThrottle() async throws
    {
        let throttle = RenderThrottle( limit: 1 )
        let model    = WindowModel( renderThrottle: throttle )

        // Hold the only slot so the two simulated renders below must wait.
        await throttle.acquire( key: "held" )

        let earlier  = UUID()
        let selected = UUID()

        var order: [ UUID ] = []

        // The "earlier" render enqueues first, so under plain FIFO it would win.
        let earlierWaiter = Task
        { @MainActor in
            await throttle.acquire( key: earlier )
            order.append( earlier )
        }

        await Task.yield()
        await Task.yield()

        let selectedWaiter = Task
        { @MainActor in
            await throttle.acquire( key: selected )
            order.append( selected )
        }

        await Task.yield()
        await Task.yield()

        // Selecting the later file must bump its render ahead of the earlier one.
        model.selectedFileID = selected

        throttle.release()
        await selectedWaiter.value

        throttle.release()
        await earlierWaiter.value

        #expect( order == [ selected, earlier ], "selecting a file promotes its waiting render ahead of earlier ones" )
    }
}

/// Tests for `RenderThrottle`: it bounds how many preparations run at once.
@Suite( "RenderThrottle" )
@MainActor
struct RenderThrottleTests
{
    @Test
    func acquireBeyondTheLimitWaitsForARelease() async throws
    {
        let throttle = RenderThrottle( limit: 1 )

        await throttle.acquire()

        var secondAcquired = false

        let waiter = Task
        { @MainActor in
            await throttle.acquire()
            secondAcquired = true
        }

        // Let the waiter run; with the single slot taken it must block.
        await Task.yield()
        await Task.yield()

        #expect( secondAcquired == false, "a second acquire beyond the limit must wait" )

        throttle.release()
        await waiter.value

        #expect( secondAcquired, "releasing a slot lets a waiter proceed" )
    }

    @Test
    func acquiresUpToTheLimitWithoutWaiting() async throws
    {
        let throttle = RenderThrottle( limit: 2 )

        await throttle.acquire()
        await throttle.acquire()

        // Both acquired without suspending; release so the throttle is balanced.
        throttle.release()
        throttle.release()
    }

    // MARK: - Priority

    /// A waiter promoted to high priority jumps ahead of an earlier normal waiter:
    /// releasing the single slot hands it to the promoted waiter first.
    @Test
    func aPrioritizedWaiterAcquiresBeforeAnEarlierNormalWaiter() async throws
    {
        let throttle = RenderThrottle( limit: 1 )

        await throttle.acquire( key: "held" )

        var order: [ String ] = []

        let first = Task
        { @MainActor in
            await throttle.acquire( key: "first" )
            order.append( "first" )
        }

        // Let "first" reach the acquire suspension so it enqueues before "second".
        await Task.yield()
        await Task.yield()

        let second = Task
        { @MainActor in
            await throttle.acquire( key: "second" )
            order.append( "second" )
        }

        await Task.yield()
        await Task.yield()

        // Promote the later waiter; it must now win the next freed slot.
        throttle.prioritize( key: "second" )

        throttle.release()
        await second.value

        throttle.release()
        await first.value

        #expect( order == [ "second", "first" ], "a prioritized waiter jumps ahead of an earlier normal waiter" )
    }

    /// Acquiring with high priority jumps ahead of a normal waiter that suspended
    /// earlier, so the next freed slot goes to the high-priority acquirer.
    @Test
    func highPriorityAcquireJumpsAheadOfAWaitingNormalAcquirer() async throws
    {
        let throttle = RenderThrottle( limit: 1 )

        await throttle.acquire( key: "held" )

        var order: [ String ] = []

        let normal = Task
        { @MainActor in
            await throttle.acquire( key: "normal" )
            order.append( "normal" )
        }

        await Task.yield()
        await Task.yield()

        let high = Task
        { @MainActor in
            await throttle.acquire( key: "high", priority: .high )
            order.append( "high" )
        }

        await Task.yield()
        await Task.yield()

        throttle.release()
        await high.value

        throttle.release()
        await normal.value

        #expect( order == [ "high", "normal" ], "a high-priority acquire wins over an earlier normal waiter" )
    }

    /// Prioritizing a key that is not currently waiting does nothing: the waiters
    /// keep their FIFO order.
    @Test
    func prioritizingAKeyThatIsNotWaitingKeepsFIFOOrder() async throws
    {
        let throttle = RenderThrottle( limit: 1 )

        await throttle.acquire( key: "held" )

        var order: [ String ] = []

        let first = Task
        { @MainActor in
            await throttle.acquire( key: "first" )
            order.append( "first" )
        }

        await Task.yield()
        await Task.yield()

        let second = Task
        { @MainActor in
            await throttle.acquire( key: "second" )
            order.append( "second" )
        }

        await Task.yield()
        await Task.yield()

        // No waiter carries this key, so the promotion is a no-op.
        throttle.prioritize( key: "absent" )

        throttle.release()
        await first.value

        throttle.release()
        await second.value

        #expect( order == [ "first", "second" ], "an unmatched prioritize leaves FIFO order intact" )
    }

    /// Re-prioritizing serves the most recently promoted waiter first, so rapid
    /// navigation renders the file currently on screen ahead of the ones passed
    /// through on the way there.
    @Test
    func repromotingServesTheMostRecentlyPromotedWaiterFirst() async throws
    {
        let throttle = RenderThrottle( limit: 1 )

        await throttle.acquire( key: "held" )

        var order: [ String ] = []

        let a = Task
        { @MainActor in
            await throttle.acquire( key: "a" )
            order.append( "a" )
        }

        await Task.yield()
        await Task.yield()

        let b = Task
        { @MainActor in
            await throttle.acquire( key: "b" )
            order.append( "b" )
        }

        await Task.yield()
        await Task.yield()

        let c = Task
        { @MainActor in
            await throttle.acquire( key: "c" )
            order.append( "c" )
        }

        await Task.yield()
        await Task.yield()

        // Navigation passes through "b" then lands on "c": the latest selection
        // must win, then the earlier promotion, then the never-promoted waiter.
        throttle.prioritize( key: "b" )
        throttle.prioritize( key: "c" )

        throttle.release()
        await c.value

        throttle.release()
        await b.value

        throttle.release()
        await a.value

        #expect( order == [ "c", "b", "a" ], "the most recently promoted waiter is served first" )
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

        model.recomputeWeights()

        #expect( file.weight == nil )
    }
}
