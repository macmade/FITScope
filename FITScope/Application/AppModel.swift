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
import UniformTypeIdentifiers

/// App-wide coordination that the per-window models register with, so global
/// actions (the Open panel, Finder/Dock file opens) can route files to the
/// frontmost window or request a new one.
@MainActor
public final class AppModel: ObservableObject
{
    /// The model of the window that is currently key, or `nil` when no window
    /// is key.
    public weak var activeModel: WindowModel?

    /// Set by `FITScopeApp` so non-SwiftUI call sites (the delegate) can open a
    /// new window carrying initial URLs.
    public var openWindowWithURLs: ( ( [ URL ] ) -> Void )?

    /// Creates an empty app model.
    public init()
    {}

    /// Routes URLs to the active window, or opens a new window when none exists.
    ///
    /// - Parameter urls: The file URLs to open.
    public func openIntoActiveWindowOrNew( urls: [ URL ] )
    {
        guard urls.isEmpty == false
        else
        {
            return
        }

        if let model = self.activeModel
        {
            model.open( urls: urls )
        }
        else
        {
            self.openWindowWithURLs?( urls )
        }
    }

    /// Forgets a window's model once its window has closed. The active model is a
    /// `weak` reference, but a closed window's model can briefly outlive its
    /// window (held by SwiftUI's scene storage); leaving it as the active model
    /// would route a subsequently opened file into a window that is gone, so no
    /// window appears. Clearing it here makes the next open create a new window.
    ///
    /// - Parameter model: The closing window's model.
    public func windowDidClose( _ model: WindowModel )
    {
        if self.activeModel === model
        {
            self.activeModel = nil
        }
    }

    /// Presents an Open panel for FITS files.
    ///
    /// - Returns: The chosen URLs, or an empty array if cancelled.
    public func runOpenPanel() -> [ URL ]
    {
        let panel = NSOpenPanel()

        panel.allowsMultipleSelection = true
        panel.canChooseDirectories    = false
        panel.canChooseFiles          = true
        panel.allowedContentTypes     = [ .fits ]

        return panel.runModal() == .OK ? panel.urls : []
    }
}
