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
import Foundation

/// Re-publishes whenever any of a set of open files changes.
///
/// The session charts read every open file, but a ``WindowModel`` only re-publishes
/// when its file *set* changes — a file's metrics arriving asynchronously mutate the
/// file, not the model. Observing the model alone would leave the charts stale until
/// the next add/remove. This forwards each file's `objectWillChange` as its own, so a
/// view holding it refreshes as metrics land, mirroring how ``WindowModel`` watches
/// its files to recompute weights.
@MainActor
public final class SessionMetricsFilesObserver: ObservableObject
{
    /// Per-file change subscriptions, rebuilt each time ``observe(_:)`` is called.
    private var observers: [ AnyCancellable ] = []

    /// Creates an observer watching nothing yet.
    public init()
    {}

    /// Subscribes to the given files, replacing any previous subscriptions, so a
    /// change to any of them re-publishes this observer.
    ///
    /// - Parameter files: The files to watch.
    func observe( _ files: [ OpenFile ] )
    {
        self.observers = files.map
        {
            file in

            file.objectWillChange.sink
            {
                [ weak self ] _ in self?.objectWillChange.send()
            }
        }
    }
}
