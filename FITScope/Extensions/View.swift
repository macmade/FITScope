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

import SwiftUI

public extension View
{
    /// Applies ``SwiftUI/View/navigationDocument(_:)`` only when a URL is
    /// available, leaving the view unchanged otherwise.
    ///
    /// macOS turns a window's navigation document into a title-bar proxy icon:
    /// command-clicking (or click-and-holding) the title reveals the file's
    /// folder hierarchy, and selecting an ancestor reveals it in Finder. There
    /// is no document to represent when no file is selected, so the modifier is
    /// applied conditionally.
    ///
    /// - Parameter url: The represented file URL, or `nil` when none.
    /// - Returns: The view, with the navigation document set when `url` is
    ///   non-`nil`.
    @ViewBuilder
    func navigationDocument( ifPresent url: URL? ) -> some View
    {
        if let url
        {
            self.navigationDocument( url )
        }
        else
        {
            self
        }
    }
}
