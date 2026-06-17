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

/// Decides whether a dropped URL should be opened. Any regular file is
/// accepted regardless of extension, so that an invalid file is still added to
/// the window and surfaces a per-file error rather than being silently
/// discarded; directories are rejected.
public enum DropAcceptance
{
    /// Whether the URL is a regular file that should be opened.
    ///
    /// - Parameter url: The dropped URL.
    /// - Returns: `true` for a regular file; `false` for a directory or a URL
    ///   that cannot be inspected.
    public static func acceptable( _ url: URL ) -> Bool
    {
        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists( atPath: url.path, isDirectory: &isDirectory )
        else
        {
            return false
        }

        return isDirectory.boolValue == false
    }
}
