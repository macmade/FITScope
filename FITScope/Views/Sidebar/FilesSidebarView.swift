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

    /// App-wide coordination, used to open a file in a new window.
    @EnvironmentObject private var appModel: AppModel

    /// The shared, persisted preferences, used for the trash-confirmation setting.
    @EnvironmentObject private var preferences: Preferences

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
                .help( "Open FITS Files…" )
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

                    OpenFileRowView(
                        file:              file,
                        isSelected:        file.id == self.model.selectedFileID,
                        onOpenInNewWindow: { self.appModel.openInNewWindow( urls: [ file.url ] ) },
                        onSaveAs:          { self.appModel.saveCopy( of: file ) },
                        onExport:          { self.appModel.exportImage( of: file ) },
                        onRevealInFinder:  { NSWorkspace.shared.activateFileViewerSelecting( [ file.url ] ) },
                        onMoveToTrash:     { self.moveToTrash( file ) },
                        onClose:           { self.model.close( file ) }
                    )
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

    /// Moves a file to the Trash, asking the user to confirm first unless they
    /// have turned the confirmation off. Presents an alert if the operation fails
    /// so a destructive action never fails silently.
    ///
    /// - Parameter file: The file to trash.
    private func moveToTrash( _ file: OpenFile )
    {
        if self.preferences.confirmMoveToTrash, self.confirmTrashing( file ) == false
        {
            return
        }

        do
        {
            try self.model.trash( file )
        }
        catch
        {
            AppModel.presentFailureAlert( "Could not move \u{201C}\( file.displayName )\u{201D} to the Trash.", error: error )
        }
    }

    /// Presents the trash-confirmation alert for a file, including a "Don't ask
    /// again" checkbox that, when ticked, turns the confirmation off in the
    /// preferences so it is not shown again.
    ///
    /// - Parameter file: The file about to be trashed.
    /// - Returns: `true` if the user confirmed, `false` if they cancelled.
    private func confirmTrashing( _ file: OpenFile ) -> Bool
    {
        let confirm = NSAlert()

        confirm.messageText            = "Move \u{201C}\( file.displayName )\u{201D} to the Trash?"
        confirm.informativeText        = "The file will be removed from its directory and moved to the Trash."
        confirm.alertStyle             = .warning
        confirm.showsSuppressionButton = true
        confirm.suppressionButton?.title = "Don\u{2019}t ask again"

        confirm.addButton( withTitle: "Move to Trash" ).hasDestructiveAction = true
        confirm.addButton( withTitle: "Cancel" )

        let confirmed = confirm.runModal() == .alertFirstButtonReturn

        if confirmed, confirm.suppressionButton?.state == .on
        {
            self.preferences.confirmMoveToTrash = false
        }

        return confirmed
    }
}
