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
import UniformTypeIdentifiers

/// The app's contributions to the standard *File* menu.
///
/// Both commands act on the frontmost window's selected file, which each window
/// publishes as its scene's focused object (see ``MainWindowView``). Reading it
/// with `@FocusedObject` follows the key window, updates when the selection
/// changes, and — because `@FocusedObject` observes the file — re-validates when
/// the file's render result commits. "Save As…" only needs a selected file;
/// "Export…" additionally needs a rendered image, so it stays disabled until one
/// exists.
///
/// The two *Open With* submenus mirror that split: "Open Original With" hands the
/// unmodified FITS file to another app (like "Save As…", so it only needs a
/// selected file), while "Open Rendered Image With" hands the processed image
/// (like "Export…", so it needs a committed render result). Each lists the
/// applications the system associates with that file kind, plus an *Other…* entry
/// that presents an application chooser.
struct FileCommands: View
{
    /// The frontmost window's selected file, or `nil` when none. Observed, so the
    /// commands re-validate as it loads, renders, and changes.
    @FocusedObject private var file: OpenFile?

    /// The app-wide coordination object, used to run the Save / Export panels.
    private let appModel: AppModel

    /// Creates the File-menu commands.
    ///
    /// - Parameter appModel: The shared coordination object.
    init( appModel: AppModel )
    {
        self.appModel = appModel
    }

    /// The menu items.
    var body: some View
    {
        Button
        {
            if let file = self.file
            {
                self.appModel.saveCopy( of: file )
            }
        }
        label:
        {
            Label( "Save As\u{2026}", systemImage: "square.and.arrow.down" )
        }
        .keyboardShortcut( "s", modifiers: [ .command, .shift ] )
        .disabled( self.file == nil )

        Button
        {
            if let file = self.file
            {
                self.appModel.exportImage( of: file )
            }
        }
        label:
        {
            Label( "Export\u{2026}", systemImage: "square.and.arrow.up" )
        }
        .keyboardShortcut( "e", modifiers: [ .command, .shift ] )
        .disabled( self.file?.image?.renderer.result == nil )

        Divider()

        // Open the *original* FITS file in another app — enabled whenever a file
        // is selected, like "Save As…". When no file is selected the menu is
        // disabled, so the `.fits` fallback source is never used.
        OpenWithMenu(
            title:       "Open Original With",
            systemImage: "arrow.up.forward.app",
            source:      self.file.map { .url( $0.url ) } ?? .contentType( .fits ),
            open:        { application in self.file.map { self.appModel.openOriginalFile( $0, with: application.url ) } },
            openOther:   { self.file.map { self.appModel.openOriginalFile( withOther: $0 ) } }
        )
        .disabled( self.file == nil )

        // Open the *rendered* image in another app — needs a committed render
        // result, like "Export…". The rendered image is written as a TIFF, so the
        // candidates are the TIFF handlers.
        OpenWithMenu(
            title:       "Open Rendered Image With",
            systemImage: "photo",
            source:      .contentType( .tiff ),
            open:        { application in self.file.map { self.appModel.openRenderedImage( of: $0, with: application.url ) } },
            openOther:   { self.file.map { self.appModel.openRenderedImage( withOther: $0 ) } }
        )
        .disabled( self.file?.image?.renderer.result == nil )
    }
}
