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
    /// The number of slots still available.
    private var available: Int

    /// Callers suspended waiting for a slot, resumed in FIFO order on release.
    private var waiters: [ CheckedContinuation< Void, Never > ] = []

    /// Creates a throttle allowing `limit` concurrent holders (at least one).
    ///
    /// - Parameter limit: The maximum number of concurrent holders.
    init( limit: Int )
    {
        self.available = max( 1, limit )
    }

    /// Acquires a slot, suspending until one is free.
    func acquire() async
    {
        if self.available > 0
        {
            self.available -= 1

            return
        }

        await withCheckedContinuation { self.waiters.append( $0 ) }
    }

    /// Releases a slot, handing it to the next waiter if any.
    func release()
    {
        if self.waiters.isEmpty
        {
            self.available += 1
        }
        else
        {
            self.waiters.removeFirst().resume()
        }
    }
}
