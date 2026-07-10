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

/// The root of the single, app-wide Screen Transfer editor window.
///
/// The window is a singleton scene that edits whichever document window is
/// frontmost: it reads the key window's model from the shared ``AppModel`` and,
/// because `AppModel` publishes when its active model changes, re-targets the
/// editor as the user switches windows. Focusing the Screen Transfer window itself
/// does not clear the active model (the document window only *sets* it when it
/// becomes active), so the editor keeps pointing at the last-active document.
///
/// The window's pieces live in their own files: ``STFActiveModelView`` bridges the
/// frontmost window's model, ``STFEditorView`` is the editor itself, and
/// ``STFUnavailableView`` is the no-image placeholder. Mirrors the Levels and
/// Curves editor windows.
public struct STFWindowView: View
{
    /// The app-wide coordination object that tracks the frontmost window.
    @EnvironmentObject private var appModel: AppModel

    /// Creates the window root.
    public init()
    {}

    /// The view's content.
    public var body: some View
    {
        Group
        {
            if let model = self.appModel.activeModel
            {
                STFActiveModelView( model: model )
            }
            else
            {
                STFUnavailableView()
            }
        }
        // Fixed width, matching the Levels and Curves editors; the window's height
        // adapts to its content via `.windowResizability( .contentSize )`.
        .frame( width: 400 )
        .background
        {
            Rectangle()
                .fill( .windowBackground )
                .overlay( Color.black.opacity( 0.05 ) )
        }
        .persistsWindowFrame( autosaveName: "ScreenTransferEditorWindow", centeredWhenUnsaved: true )
    }
}
