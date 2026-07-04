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

import Foundation

/// A main-actor counting semaphore that bounds how many asynchronous units of
/// work run concurrently.
///
/// Callers `await acquire()` before their work and `release()` when done. Up to
/// `limit` callers proceed immediately; the rest suspend until a slot frees, in
/// FIFO order. All state is main-actor isolated, so no further locking is
/// needed. Cancellation is not specially handled: a caller cancelled while
/// waiting still resumes on the next `release()` and should bail then.
@MainActor
final class RenderThrottle
{
    /// The initial urgency of an acquisition. Promoted work is served before
    /// unpromoted work; a ``high`` acquire enters already promoted, as if
    /// ``prioritize(key:)`` had been called on it the instant it suspended.
    enum Priority
    {
        /// Background work with no particular urgency.
        case normal

        /// Work the user is waiting on directly, e.g. the selected file.
        case high
    }

    /// A suspended acquirer waiting for a slot.
    private struct Waiter
    {
        /// The caller's optional identifier, used to promote it later.
        let key: AnyHashable?

        /// The promotion order stamped when this waiter was last promoted, or `nil`
        /// if it was never promoted. A higher value means a more recent promotion,
        /// so the most recently selected file wins over earlier ones.
        var promotion: Int?

        /// A monotonically increasing sequence number, giving FIFO order among
        /// unpromoted waiters.
        let ticket: Int

        /// The continuation resumed when this waiter is granted a slot.
        let continuation: CheckedContinuation< Void, Never >
    }

    /// The number of slots still available.
    private var available: Int

    /// Callers suspended waiting for a slot, served most-recently-promoted first
    /// and, among unpromoted waiters, in FIFO order (by ``Waiter/ticket``).
    private var waiters: [ Waiter ] = []

    /// The next ticket to hand out, so unpromoted waiters keep their arrival order.
    private var nextTicket = 0

    /// The next promotion stamp to hand out, so a later promotion always outranks
    /// an earlier one and the newest selection is served first.
    private var nextPromotion = 0

    /// Creates a throttle allowing `limit` concurrent holders (at least one).
    ///
    /// - Parameter limit: The maximum number of concurrent holders.
    init( limit: Int )
    {
        self.available = max( 1, limit )
    }

    /// Acquires a slot, suspending until one is free.
    ///
    /// - Parameters:
    ///   - key:      An optional identifier the caller can later pass to
    ///               ``prioritize(key:)`` to promote this acquirer while it waits.
    ///   - priority: The initial urgency of this acquisition.
    func acquire( key: AnyHashable? = nil, priority: Priority = .normal ) async
    {
        if self.available > 0
        {
            self.available -= 1

            return
        }

        let ticket    = self.nextTicket
        let promotion = priority == .high ? self.makePromotion() : nil

        self.nextTicket += 1

        await withCheckedContinuation
        {
            continuation in

            self.waiters.append( Waiter( key: key, promotion: promotion, ticket: ticket, continuation: continuation ) )
        }
    }

    /// Promotes the still-waiting acquirer with the given key so it wins the next
    /// freed slot ahead of earlier waiters. Re-promoting stamps a fresh, higher
    /// order, so the most recently selected file is served first even when several
    /// were promoted while navigating. A no-op when no waiter currently carries the
    /// key — the acquirer already holds a slot, has finished, or has not suspended
    /// yet.
    ///
    /// - Parameter key: The key of the waiter to promote.
    func prioritize( key: AnyHashable )
    {
        guard let index = self.waiters.firstIndex( where: { $0.key == key } )
        else
        {
            return
        }

        self.waiters[ index ].promotion = self.makePromotion()
    }

    /// Releases a slot, handing it to the most deserving waiter if any — the most
    /// recently promoted one, or the earliest unpromoted one — otherwise returning
    /// it to the pool.
    func release()
    {
        guard let index = self.indexOfNextWaiter()
        else
        {
            self.available += 1

            return
        }

        self.waiters.remove( at: index ).continuation.resume()
    }

    /// The index of the waiter that should receive the next freed slot: the most
    /// recently promoted one, or — when none is promoted — the earliest arrival
    /// (lowest ticket). `nil` when no waiter is suspended.
    private func indexOfNextWaiter() -> Int?
    {
        self.waiters.indices.max
        {
            lhs, rhs in

            let left  = self.waiters[ lhs ]
            let right = self.waiters[ rhs ]

            switch ( left.promotion, right.promotion )
            {
                case ( let leftPromotion?, let rightPromotion? ): return leftPromotion < rightPromotion
                case ( nil, _? ):                             return true
                case ( _?, nil ):                             return false
                case ( nil, nil ):                            return left.ticket > right.ticket
            }
        }
    }

    /// Stamps and returns the next promotion order, higher than any handed out
    /// before, so later promotions outrank earlier ones.
    private func makePromotion() -> Int
    {
        self.nextPromotion += 1

        return self.nextPromotion
    }
}
