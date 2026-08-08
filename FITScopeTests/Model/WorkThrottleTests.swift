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
import Testing

/// Waiting for a pool's queue to form, so a test can reorder one it knows is there.
@MainActor
extension WorkThrottle
{
    /// Waits until `count` acquirers are suspended in this pool.
    ///
    /// An acquirer has to be scheduled before it can reach its `acquire` and suspend
    /// there, and yielding a fixed number of times does not guarantee that has
    /// happened — leaving a test to reorder a queue that has not formed, where
    /// ``prioritize(key:)`` is a documented no-op and the resulting order is decided
    /// by scheduling luck. The wait is bounded and throws, so a queue that never forms
    /// stops the test here, with the count it reached, rather than surfacing as a
    /// mysterious ordering further down.
    ///
    /// - Parameter count: The number of suspended acquirers to wait for.
    /// - Throws: When the pool never reaches `count` suspended acquirers.
    func waitForWaiters( _ count: Int ) async throws
    {
        var attempts = 0

        while self.waiterCount < count, attempts < 10_000
        {
            attempts += 1

            await Task.yield()
        }

        try #require( self.waiterCount == count, "\( count ) acquirers must be suspended in the pool before its queue is reordered" )
    }
}

/// Tests for `WorkThrottle`: it bounds how many units of work run at once.
@Suite( "WorkThrottle" )
@MainActor
struct WorkThrottleTests
{
    /// A key can carry several waiters — a file's frames each enqueue their own work
    /// under the file's identifier — and promoting it serves the one that suspended
    /// last, which is the one the user reached most recently. Promoting the earliest
    /// instead would serve the frame they left longest ago.
    @Test( .timeLimit( .minutes( 1 ) ) )
    func promotingAKeyServesItsMostRecentAcquirerFirst() async throws
    {
        let throttle = WorkThrottle( limit: 1 )

        // Hold the only slot so both acquirers below must wait, and let each hand its
        // slot on so the single release drains both.
        await throttle.acquire()

        var order: [ String ] = []

        let older = Task
        { @MainActor in
            await throttle.acquire( key: "file" )
            order.append( "older" )
            throttle.release()
        }

        try await throttle.waitForWaiters( 1 )

        let newer = Task
        { @MainActor in
            await throttle.acquire( key: "file" )
            order.append( "newer" )
            throttle.release()
        }

        // Pin the scenario: both carry the same key and are suspended, so promoting it
        // has to choose between them rather than finding only one.
        try await throttle.waitForWaiters( 2 )

        throttle.prioritize( key: "file" )

        throttle.release()

        await newer.value
        await older.value

        #expect( order == [ "newer", "older" ], "promoting a key serves its most recently suspended acquirer first" )
    }

    @Test
    func acquireBeyondTheLimitWaitsForARelease() async throws
    {
        let throttle = WorkThrottle( limit: 1 )

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
        let throttle = WorkThrottle( limit: 2 )

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
        let throttle = WorkThrottle( limit: 1 )

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
        let throttle = WorkThrottle( limit: 1 )

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
        let throttle = WorkThrottle( limit: 1 )

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
        let throttle = WorkThrottle( limit: 1 )

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

    // MARK: - Abandonment

    /// An acquirer cancelled while it waits is resumed on the next release rather
    /// than dropped, and bails without running its work, handing the slot straight
    /// on to the waiter behind it. This is the contract an analysis pool can rely on
    /// to abandon queued work: because the throttle keeps a cancelled waiter, a
    /// caller guards after acquiring, and abandoned work neither runs nor starves
    /// the work queued behind it.
    @Test
    func workCancelledWhileQueuedNeverRunsAndPassesItsSlotOn() async throws
    {
        let throttle = WorkThrottle( limit: 1 )

        await throttle.acquire( key: "held" )

        var abandonedStarted = false
        var abandonedResumed = false
        var abandonedRan     = false
        var liveStarted      = false
        var liveRan          = false

        let abandoned = Task
        { @MainActor in

            abandonedStarted = true

            await throttle.acquire( key: "abandoned" )

            abandonedResumed = true

            defer { throttle.release() }

            guard Task.isCancelled == false
            else
            {
                return
            }

            abandonedRan = true
        }

        // Let the abandoned acquirer suspend, so it queues ahead of the live one
        // and is the waiter the released slot is handed to first.
        await Task.yield()
        await Task.yield()

        let live = Task
        { @MainActor in

            liveStarted = true

            await throttle.acquire( key: "live" )

            defer { throttle.release() }

            liveRan = true
        }

        await Task.yield()
        await Task.yield()

        // Pin the scenario before acting on it. Each body sets its "started" flag
        // with no suspension point before its `acquire`, so a task that has started
        // without running its work can only be suspended inside the throttle — which
        // is the state this test is named for. Without this the yields above could
        // prove nothing: two tasks that had not begun at all would still satisfy
        // every assertion below.
        #expect( abandonedStarted,      "the abandoned acquirer must have reached its acquire" )
        #expect( liveStarted,           "the live acquirer must have reached its acquire" )
        #expect( abandonedRan == false, "neither acquirer can proceed while the only slot is held" )
        #expect( liveRan      == false, "neither acquirer can proceed while the only slot is held" )

        abandoned.cancel()

        throttle.release()

        await abandoned.value
        await live.value

        #expect( abandonedResumed,      "the throttle resumes a cancelled waiter rather than dropping it" )
        #expect( abandonedRan == false, "work cancelled while queued must not run" )
        #expect( liveRan,               "an abandoned waiter hands its slot to the waiter behind it" )
    }
}
