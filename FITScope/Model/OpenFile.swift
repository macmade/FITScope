/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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
    /// A stable, per-instance identity, independent of the URL.
    public let id = UUID()

    /// The source URL of the file.
    public let url: URL

    /// The loader that parses the file into a ``FITSImage``.
    @Published public private( set ) var loader: FITSImageLoader

    /// Forwards the loader's change notifications to this object's observers.
    private var loaderObserver: AnyCancellable?

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

    /// The error from the most recent failed load, or `nil` on success.
    public var error: Error?
    {
        self.loader.error
    }

    /// Loads (parses) the file, if not already loaded.
    public func load() async
    {
        await self.loader.load()
    }
}
