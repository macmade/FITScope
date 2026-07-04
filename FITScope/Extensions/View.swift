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
import SwiftUI
import SwiftUtilities

public extension View
{
    /// Persists the hosting window's frame — its size *and* position — across
    /// launches, under `autosaveName`, using AppKit's frame-autosave mechanism.
    ///
    /// SwiftUI's built-in frame persistence rides on state restoration, which is
    /// disabled app-wide so the app launches clean, and a window's on-screen
    /// position can't be read through SwiftUI at all. So this bridges to the
    /// hosting `NSWindow` (via ``WindowAccessor``) and enables AppKit's own frame
    /// autosave, which writes the frame to `UserDefaults` on every move/resize and,
    /// unlike restoration, does not reopen the window at launch.
    ///
    /// ``WindowAccessor`` reports the window on its first `becomeKey` — after the
    /// system has already placed it — so besides naming the autosave, the saved
    /// frame is restored explicitly with `setFrameUsingName(_:)`. That returns
    /// `false` when nothing is stored yet (first run); in that case, if
    /// `centeredWhenUnsaved` is set, the window is centered rather than left at the
    /// system's default position. The work runs once per freshly created window; a
    /// reused window keeps its in-session frame.
    ///
    /// - Parameters:
    ///   - autosaveName:        The unique key under which the frame is stored. Each
    ///     window must use a distinct name.
    ///   - centeredWhenUnsaved: When `true`, center the window on first run — i.e.
    ///     when no frame has been saved yet. Defaults to `false`, leaving the
    ///     system's default placement.
    /// - Returns: The view, with frame persistence attached to its window.
    func persistsWindowFrame( autosaveName: String, centeredWhenUnsaved: Bool = false ) -> some View
    {
        self.background(
            WindowAccessor
            {
                window in

                let name = NSWindow.FrameAutosaveName( autosaveName )

                guard window.frameAutosaveName != name, window.setFrameAutosaveName( name )
                else
                {
                    return
                }

                // Restore the saved frame; when none is stored yet (first run),
                // `setFrameUsingName` returns false — center the window then, if asked.
                if window.setFrameUsingName( name ) == false, centeredWhenUnsaved
                {
                    window.center()
                }
            }
        )
    }

    /// Reports the hosting window's frame *size* — title bar and toolbar included —
    /// whenever it changes, so a caller can persist it across launches.
    ///
    /// This deliberately reports the full window frame rather than the SwiftUI
    /// content size a geometry reader would give: `WindowPlacement(size:)` (used to
    /// restore the size) sizes the whole window frame, so saving the content size
    /// and restoring it as a frame loses the title bar's height on every launch,
    /// shrinking the window each time. Reporting the frame size makes the value
    /// round-trip. State restoration stays disabled, so this only saves — it never
    /// reopens a window.
    ///
    /// - Parameter action: Called with the window's frame size on every resize.
    /// - Returns: The view, reporting its window's frame size on change.
    func onWindowSizeChange( _ action: @escaping ( CGSize ) -> Void ) -> some View
    {
        self.modifier( WindowSizeChangeModifier( action: action ) )
    }

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

/// Backs ``SwiftUI/View/onWindowSizeChange(_:)``: resolves the hosting window and
/// keeps a resize observation alive for the view's lifetime.
private struct WindowSizeChangeModifier: ViewModifier
{
    /// Called with the window's frame size on every resize.
    let action: ( CGSize ) -> Void

    /// Retains the notification observation for as long as the view exists.
    @State private var observer = WindowResizeObserver()

    /// The modified content, with the window-resize observation attached.
    ///
    /// - Parameter content: The wrapped content.
    /// - Returns: The content, observing its window's frame-size changes.
    func body( content: Content ) -> some View
    {
        // Grab stable references for the accessor's escaping callback, rather than
        // reading the property wrappers inside it.
        let observer = self.observer
        let action   = self.action

        return content.background(
            WindowAccessor { observer.observe( $0, action: action ) }
        )
    }
}
