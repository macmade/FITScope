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

/// The single definition of an open file's context menu, shared by the files
/// sidebar row and the image canvas so the two menus are identical. Each item's
/// icon mirrors the main menu's symbol for the same action (with `folder`,
/// `trash` and `xmark` chosen for the items the main menu has no counterpart
/// for).
///
/// The modifier observes ``file`` so the enabled state of the info- and
/// export-dependent items refreshes as the image loads and renders — the reason
/// the menu is applied on the observing row (and here on the canvas) rather than
/// on a non-observing container.
public struct FileContextMenu: ViewModifier
{
    /// The file the menu acts on.
    @ObservedObject private var file: OpenFile

    /// The actions the menu items invoke.
    private let actions: FileActions

    /// Opens the auxiliary FITS-headers window for the "View FITS Headers" item;
    /// this action lives in the environment rather than in ``FileActions``.
    @Environment( \.openWindow ) private var openWindow

    /// Creates the menu modifier.
    ///
    /// - Parameters:
    ///   - file:    The file the menu acts on.
    ///   - actions: The shared file actions the items invoke.
    public init( file: OpenFile, actions: FileActions )
    {
        self.file    = file
        self.actions = actions
    }

    /// Attaches the context menu to `content`.
    ///
    /// - Parameter content: The view the menu is attached to.
    public func body( content: Content ) -> some View
    {
        content.contextMenu
        {
            Button
            {
                self.actions.openInNewWindow( self.file )
            }
            label:
            {
                Label( "Open in New Window", systemImage: "macwindow.badge.plus" )
            }

            Button
            {
                if let info = self.file.image?.info
                {
                    self.openWindow( id: "InfoWindow", value: info )
                }
            }
            label:
            {
                Label( "View FITS Headers", systemImage: "tablecells" )
            }
            .disabled( self.file.image?.info == nil )

            Divider()

            Button
            {
                self.actions.saveAs( self.file )
            }
            label:
            {
                Label( "Save As\u{2026}", systemImage: "square.and.arrow.down" )
            }

            Button
            {
                self.actions.export( self.file )
            }
            label:
            {
                Label( "Export\u{2026}", systemImage: "square.and.arrow.up" )
            }
            .disabled( self.file.image?.renderer.result == nil )

            Divider()

            // The same two "Open With" submenus the File menu offers, mirroring the
            // original/processed split of Save-As/Export above, set apart in their
            // own group by the dividers around them.
            OpenWithMenu(
                title:       "Open Original With",
                systemImage: "arrow.up.forward.app",
                source:      .url( self.file.url ),
                open:        { self.actions.openOriginal( self.file, with: $0.url ) },
                openOther:   { self.actions.openOriginalWithOther( self.file ) }
            )

            OpenWithMenu(
                title:       "Open Rendered Image With",
                systemImage: "photo",
                source:      .contentType( .tiff ),
                open:        { self.actions.openRendered( self.file, with: $0.url ) },
                openOther:   { self.actions.openRenderedWithOther( self.file ) }
            )
            .disabled( self.file.image?.renderer.result == nil )

            Divider()

            Button
            {
                self.actions.revealInFinder( self.file )
            }
            label:
            {
                Label( "Reveal in Finder", systemImage: "folder" )
            }

            Divider()

            Button( role: .destructive )
            {
                self.actions.moveToTrash( self.file )
            }
            label:
            {
                Label( "Move to Trash", systemImage: "trash" )
            }

            Button( role: .destructive )
            {
                self.actions.close( self.file )
            }
            label:
            {
                Label( "Close", systemImage: "xmark" )
            }
        }
    }
}

public extension View
{
    /// Attaches the shared open-file context menu for `file`, driven by `actions`.
    ///
    /// - Parameters:
    ///   - file:    The file the menu acts on.
    ///   - actions: The shared file actions the items invoke.
    /// - Returns: The view with the file context menu attached.
    func fileContextMenu( for file: OpenFile, actions: FileActions ) -> some View
    {
        self.modifier( FileContextMenu( file: file, actions: actions ) )
    }
}
