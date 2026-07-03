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

                self.sortMenu

                Button( action: self.runOpenPanel )
                {
                    Image( systemName: "plus" )
                }
                .buttonStyle( .plain )
                .foregroundStyle( .secondary )
                .help( "Open FITS Files…" )
                .accessibilityIdentifier( AccessibilityIdentifier.FilesSidebarView.addButton )
            }
            .padding( .horizontal, 14 )
            .padding( .top, 12 )
            .padding( .bottom, 6 )

            List( selection: self.selectionBinding )
            {
                ForEach( self.model.sortedFiles )
                {
                    file in

                    OpenFileRowView(
                        file:              file,
                        isSelected:        file.id == self.model.selectedFileID,
                        sortKey:           self.model.sortKey,
                        onOpenInNewWindow: { self.appModel.openInNewWindow( urls: [ file.url ] ) },
                        onSaveAs:          { self.appModel.saveCopy( of: file ) },
                        onExport:          { self.appModel.exportImage( of: file ) },
                        onRevealInFinder:  { NSWorkspace.shared.activateFileViewerSelecting( [ file.url ] ) },
                        onMoveToTrash:     { self.moveToTrash( file ) },
                        onClose:           { self.close( file ) }
                    )
                    .tag( file.id )
                }
            }
            .listStyle( .sidebar )
            .accessibilityIdentifier( AccessibilityIdentifier.FilesSidebarView.list )

            if let selected = self.model.selectedFile
            {
                Divider()

                ImageInfoTabView( file: selected )
            }
        }
    }

    /// The sort menu: a key picker and an ascending/descending picker, driving the
    /// window model's sort state.
    private var sortMenu: some View
    {
        Menu
        {
            Picker( "Sort By", selection: self.$model.sortKey )
            {
                ForEach( FileSortKey.allCases )
                {
                    key in Text( key.title ).tag( key )
                }
            }
            .pickerStyle( .inline )

            Picker( "Order", selection: self.$model.sortAscending )
            {
                Text( "Ascending" ).tag( true )
                Text( "Descending" ).tag( false )
            }
            .pickerStyle( .inline )
        }
        label:
        {
            Image( systemName: "arrow.up.arrow.down" )
        }
        .menuStyle( .button )
        .buttonStyle( .plain )
        .menuIndicator( .hidden )
        .foregroundStyle( .secondary )
        .fixedSize()
        .help( "Sort Files" )
        .accessibilityIdentifier( AccessibilityIdentifier.FilesSidebarView.sortMenu )
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
    ///
    /// Reuses ``AppModel/runOpenPanel()`` so the Open panel is built in one place
    /// rather than duplicated per call site.
    private func runOpenPanel()
    {
        let urls = self.appModel.runOpenPanel()

        if urls.isEmpty == false
        {
            self.model.open( urls: urls )
        }
    }

    /// Closes a file, warning first when it has adjustments that would be lost, so
    /// closing an edited image from the context menu never discards work silently
    /// (mirroring the window-close confirmation).
    ///
    /// - Parameter file: The file to close.
    private func close( _ file: OpenFile )
    {
        if file.hasAdjustments, self.confirmDiscardingAdjustments( of: file ) == false
        {
            return
        }

        self.model.close( file )
    }

    /// Presents the "adjustments will be lost" warning for a single file about to
    /// be closed, matching the window-close confirmation's style. "Cancel" is the
    /// default, so an accidental dismissal keeps the file and its adjustments.
    ///
    /// - Parameter file: The file whose adjustments would be discarded.
    /// - Returns: `true` if the user chose to close anyway, `false` to cancel.
    private func confirmDiscardingAdjustments( of file: OpenFile ) -> Bool
    {
        let alert             = NSAlert()
        alert.alertStyle      = .warning
        alert.messageText     = "Close \u{201C}\( file.displayName )\u{201D} and discard its adjustments?"
        alert.informativeText = "This image has adjustments that haven\u{2019}t been exported. Closing it will discard them."

        let closeButton  = alert.addButton( withTitle: "Close Anyway" )
        let cancelButton = alert.addButton( withTitle: "Cancel" )

        closeButton.hasDestructiveAction = true
        closeButton.keyEquivalent        = ""
        cancelButton.keyEquivalent       = "\r"

        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Moves a file to the Trash, asking the user to confirm first. The
    /// confirmation appears when the user has it enabled *or* the file has
    /// adjustments (so losing edited work is never silent, even with the trash
    /// confirmation turned off). Presents an alert if the operation fails so a
    /// destructive action never fails silently.
    ///
    /// - Parameter file: The file to trash.
    private func moveToTrash( _ file: OpenFile )
    {
        let hasAdjustments = file.hasAdjustments

        if self.preferences.confirmMoveToTrash || hasAdjustments,
           self.confirmTrashing( file, notingAdjustments: hasAdjustments ) == false
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

    /// Presents the trash-confirmation alert for a file, noting when its
    /// adjustments will also be discarded.
    ///
    /// The "Don't ask again" checkbox — which turns the trash confirmation off — is
    /// offered only when that confirmation is enabled; when the alert is shown
    /// solely to warn about losing adjustments, the checkbox is hidden so a
    /// data-loss warning can't be suppressed.
    ///
    /// - Parameters:
    ///   - file:           The file about to be trashed.
    ///   - hasAdjustments: Whether the file also has adjustments to be discarded.
    /// - Returns: `true` if the user confirmed, `false` if they cancelled.
    private func confirmTrashing( _ file: OpenFile, notingAdjustments hasAdjustments: Bool ) -> Bool
    {
        let confirm = NSAlert()

        confirm.messageText     = "Move \u{201C}\( file.displayName )\u{201D} to the Trash?"
        confirm.informativeText = hasAdjustments
            ? "The file will be removed from its directory and moved to the Trash, and its adjustments will be discarded."
            : "The file will be removed from its directory and moved to the Trash."
        confirm.alertStyle      = .warning

        if self.preferences.confirmMoveToTrash
        {
            confirm.showsSuppressionButton   = true
            confirm.suppressionButton?.title = "Don\u{2019}t ask again"
        }

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
