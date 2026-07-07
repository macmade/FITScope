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

/// The file-level actions offered by the file list's and the image canvas's
/// context menus, gathered in one place so both menus behave identically.
///
/// Built once per window from the shared app model, the window model and the
/// preferences, then handed to every consumer (the sidebar rows and the canvas).
/// It owns the trash/close confirmation flow — previously private to
/// ``FilesSidebarView`` — so a file can be trashed or closed, with the same
/// warnings, from either menu. Opening the metadata window is not here: it
/// needs the SwiftUI `openWindow` action, so ``FileContextMenu`` handles it.
@MainActor
public struct FileActions
{
    /// App-wide coordination, used to open, save and export files.
    private let appModel: AppModel

    /// The window's open files and selection, used to close and trash files.
    private let model: WindowModel

    /// The shared preferences, read for the trash-confirmation setting and
    /// written when the user suppresses it.
    private let preferences: Preferences

    /// Creates a file-actions helper.
    ///
    /// - Parameters:
    ///   - appModel:    App-wide coordination.
    ///   - model:       The window's file model.
    ///   - preferences: The shared preferences.
    public init( appModel: AppModel, model: WindowModel, preferences: Preferences )
    {
        self.appModel    = appModel
        self.model       = model
        self.preferences = preferences
    }

    /// Opens the file in a new window.
    ///
    /// - Parameter file: The file to open.
    public func openInNewWindow( _ file: OpenFile )
    {
        self.appModel.openInNewWindow( urls: [ file.url ] )
    }

    /// Saves a byte-identical copy of the file's original bytes.
    ///
    /// - Parameter file: The file to copy.
    public func saveAs( _ file: OpenFile )
    {
        self.appModel.saveCopy( of: file )
    }

    /// Exports the file's rendered image (TIFF/PNG/JPEG).
    ///
    /// - Parameter file: The file to export.
    public func export( _ file: OpenFile )
    {
        self.appModel.exportImage( of: file )
    }

    /// Reveals the file in Finder.
    ///
    /// - Parameter file: The file to reveal.
    public func revealInFinder( _ file: OpenFile )
    {
        NSWorkspace.shared.activateFileViewerSelecting( [ file.url ] )
    }

    /// Opens the file's original, unmodified file in an external application.
    ///
    /// - Parameters:
    ///   - file:        The file to open.
    ///   - application: The application bundle URL to open it with.
    public func openOriginal( _ file: OpenFile, with application: URL )
    {
        self.appModel.openOriginalFile( file, with: application )
    }

    /// Opens the file's original file in a user-chosen application.
    ///
    /// - Parameter file: The file to open.
    public func openOriginalWithOther( _ file: OpenFile )
    {
        self.appModel.openOriginalFile( withOther: file )
    }

    /// Opens the file's rendered image in an external application.
    ///
    /// - Parameters:
    ///   - file:        The file whose rendered image to open.
    ///   - application: The application bundle URL to open it with.
    public func openRendered( _ file: OpenFile, with application: URL )
    {
        self.appModel.openRenderedImage( of: file, with: application )
    }

    /// Opens the file's rendered image in a user-chosen application.
    ///
    /// - Parameter file: The file whose rendered image to open.
    public func openRenderedWithOther( _ file: OpenFile )
    {
        self.appModel.openRenderedImage( withOther: file )
    }

    /// Closes a file, warning first when it has adjustments that would be lost, so
    /// closing an edited image never discards work silently (mirroring the
    /// window-close confirmation).
    ///
    /// - Parameter file: The file to close.
    public func close( _ file: OpenFile )
    {
        if file.hasAdjustments, self.confirmDiscardingAdjustments( of: file ) == false
        {
            return
        }

        self.model.close( file )
    }

    /// Moves a file to the Trash, asking the user to confirm first. The
    /// confirmation appears when the user has it enabled *or* the file has
    /// adjustments (so losing edited work is never silent, even with the trash
    /// confirmation turned off). Presents an alert if the operation fails so a
    /// destructive action never fails silently.
    ///
    /// - Parameter file: The file to trash.
    public func moveToTrash( _ file: OpenFile )
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
