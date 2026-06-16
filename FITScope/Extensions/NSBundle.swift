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

/// Convenience accessors for the values displayed in the About window.
public extension Bundle
{
    /// The bundle's display name (`CFBundleName`), or `"--"` when unset.
    var title: String
    {
        Bundle.main.object( forInfoDictionaryKey: "CFBundleName" ) as? String ?? "--"
    }

    /// The human-readable copyright string (`NSHumanReadableCopyright`), or
    /// `"--"` when unset.
    var copyright: String
    {
        Bundle.main.object( forInfoDictionaryKey: "NSHumanReadableCopyright" ) as? String ?? "--"
    }

    /// The marketing version, with the build number appended in parentheses when
    /// available (e.g. `"1.2 (45)"`), or `"--"` when no version is set.
    var version: String
    {
        guard let version = Bundle.main.object( forInfoDictionaryKey: "CFBundleShortVersionString" ) as? String
        else
        {
            return "--"
        }

        if let bundleVersion = Bundle.main.object( forInfoDictionaryKey: "CFBundleVersion" ) as? String
        {
            return "\( version ) (\( bundleVersion ))"
        }

        return version
    }
}
