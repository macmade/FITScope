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

import AppKit
import Foundation
import UniformTypeIdentifiers

/// A candidate external application the user can open a file with — an entry in
/// the *Open With* menu.
///
/// Each value pairs the application bundle's URL (used to launch it) with a
/// display name derived from the bundle. The list-building helpers turn the raw,
/// unordered `NSWorkspace` output into a de-duplicated, name-sorted menu.
public struct ExternalApplication: Identifiable, Equatable
{
    /// The application bundle's URL, used to launch the app.
    public let url: URL

    /// The application's display name, shown in the menu.
    public let name: String

    /// The URL is the stable identity: the same app never appears twice.
    public var id: URL
    {
        self.url
    }

    /// The application's Finder icon, sized for a menu row. Fetched from the
    /// system on demand, so it stays out of the pure ``applications(from:)`` logic.
    public var icon: NSImage
    {
        let icon = NSWorkspace.shared.icon( forFile: self.url.path )

        icon.size = NSSize( width: 16, height: 16 )

        return icon
    }

    /// Creates an application entry from an explicit URL and name.
    ///
    /// - Parameters:
    ///   - url:  The application bundle's URL.
    ///   - name: The display name.
    public init( url: URL, name: String )
    {
        self.url  = url
        self.name = name
    }

    /// Creates an application entry from an application bundle URL, deriving the
    /// display name from the bundle's file name (e.g. `Preview.app` → `Preview`).
    ///
    /// - Parameter applicationURL: The application bundle's URL.
    public init( applicationURL: URL )
    {
        self.init( url: applicationURL, name: applicationURL.deletingPathExtension().lastPathComponent )
    }

    /// Builds a menu-ready list from the raw application URLs `NSWorkspace`
    /// returns: the excluded application (if any) and duplicates are removed, and
    /// the rest are sorted by name, case-insensitively, with the URL breaking ties
    /// so the order is stable.
    ///
    /// - Parameters:
    ///   - urls:     The candidate application bundle URLs.
    ///   - excluded: An application to drop from the list — the running app, so
    ///               FITScope never offers to open a file with itself. `nil`
    ///               keeps every candidate.
    /// - Returns: The filtered, de-duplicated, name-sorted applications.
    public static func applications( from urls: [ URL ], excluding excluded: URL? = nil ) -> [ ExternalApplication ]
    {
        let excludedURL = excluded?.standardizedFileURL

        var seen: Set< URL > = []

        let unique = urls.filter
        {
            let url = $0.standardizedFileURL

            return url != excludedURL && seen.insert( url ).inserted
        }

        return unique.map { ExternalApplication( applicationURL: $0 ) }.sorted
        {
            let order = $0.name.localizedCaseInsensitiveCompare( $1.name )

            return order == .orderedSame ? $0.url.path < $1.url.path : order == .orderedAscending
        }
    }

    /// The applications that can open the file at the given URL, ready for the
    /// *Open With* menu. Wraps `NSWorkspace/urlsForApplications(toOpen:)` and
    /// drops the running app, so FITScope never lists itself.
    ///
    /// - Parameter url: The file to open.
    /// - Returns: The candidate applications, de-duplicated and name-sorted.
    public static func applications( toOpen url: URL ) -> [ ExternalApplication ]
    {
        self.applications( from: NSWorkspace.shared.urlsForApplications( toOpen: url ), excluding: Bundle.main.bundleURL )
    }

    /// The applications that can open a file of the given content type, ready for
    /// the *Open With* menu. Wraps `NSWorkspace/urlsForApplications(toOpen:)` and
    /// drops the running app, so FITScope never lists itself.
    ///
    /// - Parameter contentType: The content type to open.
    /// - Returns: The candidate applications, de-duplicated and name-sorted.
    public static func applications( toOpen contentType: UTType ) -> [ ExternalApplication ]
    {
        self.applications( from: NSWorkspace.shared.urlsForApplications( toOpen: contentType ), excluding: Bundle.main.bundleURL )
    }
}
