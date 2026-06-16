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

import Foundation

/// The value a main window is opened with: the files to load, plus a unique
/// identity.
///
/// `WindowGroup(for:)` treats the presented value as the window's identity and
/// re-activates an existing window when asked to open an equal value. Keying on
/// `[URL]` alone would therefore collapse every empty (and every same-file)
/// request onto a single window. The `id` makes each request distinct so a new
/// window is always created.
public struct WindowContent: Hashable, Codable
{
    /// A unique identity, so each opened window is distinct.
    public let id: UUID

    /// The file URLs to load when the window appears.
    public let urls: [ URL ]

    /// Creates a window-content request.
    ///
    /// - Parameter urls: The file URLs to load; empty for a blank window.
    public init( urls: [ URL ] = [] )
    {
        self.id   = UUID()
        self.urls = urls
    }
}
