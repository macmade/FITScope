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

/// The app's contributions to the standard *View* menu.
struct ViewCommands: View
{
    /// The menu items, appended at the end of the menu.
    var body: some View
    {
        Button
        {
            self.toggleInvertedAppearance()
        }
        label:
        {
            Label( "Invert Appearance", systemImage: "circle.righthalf.filled" )
        }
        .keyboardShortcut( "i", modifiers: [ .command, .shift ] )
    }

    /// Toggles a forced appearance override, a development aid for checking the
    /// UI in both light and dark modes.
    ///
    /// When no override is active, forces `NSApp.appearance` to the exact
    /// opposite of the current appearance; when one is active, clears it so the
    /// app follows the system again. `NSApp.appearance` is itself the source of
    /// truth, so no separate state is kept.
    private func toggleInvertedAppearance()
    {
        guard NSApp.appearance == nil
        else
        {
            NSApp.appearance = nil

            return
        }

        let opposites: [ NSAppearance.Name: NSAppearance.Name ] =
            [
                .aqua:                              .darkAqua,
                .darkAqua:                          .aqua,
                .accessibilityHighContrastAqua:     .accessibilityHighContrastDarkAqua,
                .accessibilityHighContrastDarkAqua: .accessibilityHighContrastAqua,
            ]

        guard let current  = NSApp.effectiveAppearance.bestMatch( from: Array( opposites.keys ) ),
              let inverted = opposites[ current ]
        else
        {
            return
        }

        NSApp.appearance = NSAppearance( named: inverted )
    }
}
