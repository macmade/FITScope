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

/// The keys, App Group and defaults for the per-format auto-stretch preferences,
/// in one dependency-free place both the app and its sandboxed QuickLook /
/// thumbnail extensions can compile.
///
/// Auto-stretch is toggled independently for two contexts per linear format:
/// **on open** (in the app) and **in previews** (QuickLook / Finder thumbnails).
/// The on-open preferences are app-only and live on `UserDefaults.standard`; the
/// preview preferences must be readable by the sandboxed extensions, so they live
/// in the shared App Group suite (``appGroupID``). Every preference defaults to
/// on, so astro images open and preview stretched out of the box.
public enum AutoStretchPreference
{
    /// The App Group suite the app and its extensions share for the preview
    /// preferences.
    public static let appGroupID = "group.com.xs-labs.FITScope"

    /// A linear image format whose auto-stretch is user-configurable.
    public enum Format: String, CaseIterable, Sendable
    {
        /// A FITS image.
        case fits

        /// An XISF image.
        case xisf

        /// A camera RAW image.
        case raw
    }

    /// The `UserDefaults` key for a format's "auto-stretch on open" preference
    /// (app-only, stored on `.standard`).
    ///
    /// - Parameter format: The format.
    /// - Returns: The persisted key.
    public static func onOpenKey( _ format: Format ) -> String
    {
        "autoStretchOnOpen.\( format.rawValue )"
    }

    /// The `UserDefaults` key for a format's "auto-stretch previews" preference
    /// (stored in the shared App Group suite).
    ///
    /// - Parameter format: The format.
    /// - Returns: The persisted key.
    public static func previewsKey( _ format: Format ) -> String
    {
        "autoStretchPreviews.\( format.rawValue )"
    }

    /// Whether a format's previews should be auto-stretched, read from a shared
    /// suite — the entry point the sandboxed extensions use.
    ///
    /// Defaults to `true` when nothing has been stored, matching the app's
    /// default. `object(forKey:)` distinguishes "never set" from a stored `false`.
    ///
    /// - Parameters:
    ///   - format:   The format.
    ///   - defaults: The shared App Group suite to read from.
    /// - Returns: Whether previews of that format should be auto-stretched.
    public static func autoStretchPreviews( _ format: Format, in defaults: UserDefaults ) -> Bool
    {
        ( defaults.object( forKey: self.previewsKey( format ) ) as? Bool ) ?? true
    }

    /// The shared App Group suite, or `nil` when it cannot be opened (e.g. the
    /// App Group entitlement is missing).
    ///
    /// The app's ``Preferences`` falls back to its app-only store when this is
    /// `nil`; the sandboxed extensions, which have no other store, render linear
    /// when they cannot open the suite.
    public static var sharedDefaults: UserDefaults?
    {
        UserDefaults( suiteName: self.appGroupID )
    }
}
