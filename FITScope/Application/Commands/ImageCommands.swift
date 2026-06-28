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

/// The app's *Image* menu commands, currently the plate-solve action.
///
/// The command acts on the frontmost window's selected file — published as the
/// scene's focused object by ``MainWindowView`` — so it follows the key window
/// and disables itself when no file is selected, mirroring ``FileCommands``.
struct ImageCommands: View
{
    /// The frontmost window's selected file, or `nil` when none.
    @FocusedObject private var file: OpenFile?

    /// Opens the plate-solving results window.
    @Environment( \.openWindow ) private var openWindow

    /// App-wide coordination, used to start and track the solve.
    private let appModel: AppModel

    /// The API-key store, read for the Astrometry.net key.
    private let apiKeyStore: APIKeyStore

    /// Creates the Image-menu commands.
    ///
    /// - Parameters:
    ///   - appModel:    The shared coordination object.
    ///   - apiKeyStore: The API-key store.
    init( appModel: AppModel, apiKeyStore: APIKeyStore )
    {
        self.appModel    = appModel
        self.apiKeyStore = apiKeyStore
    }

    /// The menu items.
    var body: some View
    {
        Button( "Plate Solve\u{2026}" )
        {
            if let file = self.file
            {
                self.appModel.presentPlateSolve( for: file, apiKey: self.apiKeyStore.astrometryNetKey, openWindow: self.openWindow )
            }
        }
        .keyboardShortcut( "p", modifiers: [ .command, .shift ] )
        .disabled( self.file == nil )
    }
}
