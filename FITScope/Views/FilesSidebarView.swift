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

/// The "FILES" sidebar: a titled header with an add button and a selectable
/// list of open files.
public struct FilesSidebarView: View
{
    /// The window's open files and selection.
    @ObservedObject private var model: WindowModel

    /// Creates the files sidebar.
    ///
    /// - Parameter model: The window model to drive.
    public init( model: WindowModel )
    {
        self.model = model
    }

    /// The view's content.
    public var body: some View
    {
        VStack( spacing: 0 )
        {
            HStack
            {
                Text( "FILES" )
                    .font( .system( size: 10, weight: .semibold ) )
                    .foregroundStyle( .secondary )
                    .kerning( 1.2 )

                Spacer()

                Button( action: self.runOpenPanel )
                {
                    Image( systemName: "plus" )
                }
                .buttonStyle( .borderless )
                .help( "Open FITS files…" )
                .accessibilityIdentifier( AccessibilityIdentifier.FilesSidebarView.addButton )
            }
            .padding( .horizontal, 14 )
            .padding( .top, 12 )
            .padding( .bottom, 6 )

            List( selection: self.selectionBinding )
            {
                ForEach( self.model.files )
                {
                    file in

                    OpenFileRowView( file: file )
                    {
                        self.model.close( file )
                    }
                    .tag( file.id )
                }
            }
            .listStyle( .sidebar )
            .accessibilityIdentifier( AccessibilityIdentifier.FilesSidebarView.list )

            if let selected = self.model.selectedFile
            {
                Divider()

                ImageInfoPanelView( file: selected )
            }
        }
    }

    /// The List's selection binding, which writes the model's selection on the
    /// next run-loop turn.
    ///
    /// `List` writes its selection binding from within SwiftUI's view-update
    /// pass; writing the model's `@Published` selection there is reported as
    /// "publishing changes from within view updates". Deferring the write moves
    /// it out of the update pass. The one-turn delay is imperceptible.
    private var selectionBinding: Binding< OpenFile.ID? >
    {
        Binding(
            get: { self.model.selectedFileID },
            set: { id in DispatchQueue.main.async { self.model.selectedFileID = id } }
        )
    }

    /// Presents an open panel and opens the chosen FITS files into the window.
    private func runOpenPanel()
    {
        let panel = NSOpenPanel()

        panel.allowsMultipleSelection = true
        panel.canChooseDirectories    = false
        panel.canChooseFiles          = true
        panel.allowedContentTypes     = [ .fits ]

        if panel.runModal() == .OK
        {
            self.model.open( urls: panel.urls )
        }
    }
}
