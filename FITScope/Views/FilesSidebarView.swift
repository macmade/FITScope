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

    /// Opens the auxiliary headers window.
    @Environment( \.openWindow ) private var openWindow

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
            }
            .padding( .horizontal, 14 )
            .padding( .top, 12 )
            .padding( .bottom, 6 )

            List( selection: self.$model.selectedFileID )
            {
                ForEach( self.model.files )
                {
                    file in

                    OpenFileRowView( file: file )
                        .tag( file.id )
                        .contextMenu
                        {
                            Button( "View FITS Headers" )
                            {
                                if let info = file.image?.info
                                {
                                    self.openWindow( id: "InfoWindow", value: info )
                                }
                            }
                            .disabled( file.image?.info == nil )

                            Button( "Close", role: .destructive )
                            {
                                self.model.close( file )
                            }
                        }
                }
            }
            .listStyle( .sidebar )

            if let selected = self.model.selectedFile
            {
                Divider()

                ImageInfoPanelView( file: selected )
            }
        }
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
