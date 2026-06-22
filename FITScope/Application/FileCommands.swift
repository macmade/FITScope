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

/// The app's contributions to the standard *File* menu.
///
/// The "Save As…" command targets the frontmost window's selected file. It reads
/// the active window from the shared ``AppModel``, which publishes when its
/// active model changes, so the command re-targets as the user switches windows.
/// Observing `AppModel` alone is not enough, though: it does not publish when the
/// selection changes *within* the active window — including the file being
/// selected just after the window becomes active — so the command would be stuck
/// in its initial (no-selection) state. ``ActiveFileCommands`` therefore observes
/// the active window model itself, so the enabled state tracks the selection.
struct FileCommands: View
{
    /// The app-wide coordination object that tracks the frontmost window.
    @ObservedObject var appModel: AppModel

    /// The menu items, present only while a window is active — there is no
    /// document to save without one.
    var body: some View
    {
        if let model = self.appModel.activeModel
        {
            ActiveFileCommands( appModel: self.appModel, model: model )
        }
    }
}

/// The *File*-menu items for a specific, active window model, observed so the
/// command's enabled state follows that window's selection (a command-group
/// closure cannot itself observe the model, and `@ObservedObject` cannot wrap an
/// optional, so the active-model case is factored into this child view).
private struct ActiveFileCommands: View
{
    /// The app-wide coordination object, used to run the Save panel.
    let appModel: AppModel

    /// The frontmost window's model, observed so selection changes re-evaluate
    /// the command's enabled state.
    @ObservedObject var model: WindowModel

    /// The menu items.
    var body: some View
    {
        Button( "Save As\u{2026}" )
        {
            if let file = self.model.selectedFile
            {
                self.appModel.saveCopy( of: file )
            }
        }
        .keyboardShortcut( "s", modifiers: [ .command, .shift ] )
        .disabled( self.model.selectedFile == nil )
    }
}
