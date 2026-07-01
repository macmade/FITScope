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

/// App-wide coordination that the per-window models register with, so global
/// actions (the Open panel, Finder/Dock file opens) can route files to the
/// frontmost window or request a new one.
@MainActor
public final class AppModel: ObservableObject
{
    /// The model of the window that is currently key, or `nil` when no window
    /// is key.
    ///
    /// Observed (via a manual `objectWillChange` on assignment) so an auxiliary
    /// window — the Levels editor — can follow the frontmost document. It stays
    /// `weak` to avoid retaining a closed window's model, which rules out
    /// `@Published` (a property wrapper cannot combine with `weak`); the
    /// `willSet` publishes the change instead. The automatic weak-nil on
    /// deallocation does not publish, but `windowDidClose(_:)` clears it
    /// explicitly, which does.
    public weak var activeModel: WindowModel?
    {
        willSet
        {
            if newValue !== self.activeModel
            {
                self.objectWillChange.send()
            }
        }
    }

    /// Set by `FITScopeApp` so non-SwiftUI call sites (the delegate) can open a
    /// new window carrying initial URLs.
    public var openWindowWithURLs: ( ( [ URL ] ) -> Void )?

    /// The in-flight or finished plate-solve sessions, keyed by the file they
    /// solve. The results window resolves the live session for a file from here,
    /// so the long-running solve outlives the view that started it.
    @Published public private( set ) var plateSolveSessions: [ OpenFile.ID: PlateSolveSession ] = [ : ]

    /// The Preferences tab to show, bound by ``PreferencesView``'s `TabView` so a
    /// call site outside the window — the "no API key" alert — can open
    /// Preferences directly to a specific tab.
    @Published public var selectedPreferencesTab: PreferencesTab = .general

    /// Whether the "no Astrometry.net API key" alert should be shown. Set when a
    /// plate solve is attempted with no key stored; the active window presents the
    /// alert — with an *Open Preferences* action — in SwiftUI.
    @Published public var isMissingAPIKeyAlertPresented = false

    /// Whether the "Plate Solve" prompt should be shown. Raised when a
    /// solve-dependent overlay is tapped with nothing to reveal and no solve is
    /// running; the active window presents the alert in SwiftUI, its confirm action
    /// calling ``confirmPlateSolvePrompt(apiKey:openWindow:)``.
    @Published public var isPlateSolvePromptPresented = false

    /// The file the plate-solve prompt is about, retained while it is shown so the
    /// confirm action can start (or re-open) the solve. Cleared once resolved.
    private var plateSolvePromptFile: OpenFile?

    /// Creates an empty app model.
    public init()
    {}

    /// The plate-solve session for a file, or `nil` when none has been started.
    ///
    /// - Parameter id: The file's identifier.
    /// - Returns: The session, if one exists.
    public func plateSolveSession( for id: OpenFile.ID ) -> PlateSolveSession?
    {
        self.plateSolveSessions[ id ]
    }

    /// Begins a plate solve for a file, returning whether it could be started.
    ///
    /// With no API key, the solve cannot run: the user is told where to add one
    /// and `false` is returned so the caller does not open an empty results
    /// window. Otherwise a fresh session replaces any prior one for the file (so
    /// re-solving starts clean), is started, and `true` is returned.
    ///
    /// - Parameters:
    ///   - file:   The file to solve.
    ///   - apiKey: The Astrometry.net API key.
    ///   - client: The Astrometry.net client to use. Defaults to a live client;
    ///             tests inject one backed by a mock transport.
    /// - Returns: `true` when a solve was started, `false` when no key is set.
    public func beginPlateSolve( of file: OpenFile, apiKey: String, client: AstrometryClient = AstrometryClient() ) -> Bool
    {
        guard apiKey.trimmingCharacters( in: .whitespacesAndNewlines ).isEmpty == false
        else
        {
            self.isMissingAPIKeyAlertPresented = true

            return false
        }

        let session = PlateSolveSession( file: file, apiKey: apiKey, client: client )

        self.plateSolveSessions[ file.id ] = session

        session.start()

        return true
    }

    /// Ends the plate solve for a file: cancels any in-flight solve and forgets the
    /// session, so a closed file leaves nothing behind. Safe to call for a file
    /// that has no session. The results window keyed to the file is dismissed
    /// separately by the caller, since that needs SwiftUI's dismiss action.
    ///
    /// - Parameter id: The file's identifier.
    public func endPlateSolve( for id: OpenFile.ID )
    {
        guard let session = self.plateSolveSessions[ id ]
        else
        {
            return
        }

        session.cancel()

        self.plateSolveSessions[ id ] = nil
    }

    /// Shows the plate-solving results window for a file, starting a solve only
    /// when the file has not been solved (or attempted) yet.
    ///
    /// Once a file has a session — whether it is solving, already solved, or
    /// failed — the trigger simply brings its window forward, showing the previous
    /// results rather than re-solving; re-solving is an explicit choice from the
    /// window's *Plate Solve Again* button. The shared entry point for both the
    /// toolbar button and the *Image* menu command.
    ///
    /// - Parameters:
    ///   - file:       The file to solve.
    ///   - apiKey:     The Astrometry.net API key.
    ///   - openWindow: The action that opens the results window.
    public func presentPlateSolve( for file: OpenFile, apiKey: String, openWindow: OpenWindowAction )
    {
        if self.plateSolveSession( for: file.id ) != nil
        {
            openWindow( id: "PlateSolveWindow", value: file.id )

            return
        }

        guard self.beginPlateSolve( of: file, apiKey: apiKey )
        else
        {
            return
        }

        openWindow( id: "PlateSolveWindow", value: file.id )
    }

    /// Responds to a solve-dependent overlay being tapped with nothing to reveal.
    ///
    /// When a solve is already running for the file, its results window is brought
    /// forward so the user can watch progress; otherwise the "Plate Solve" prompt is
    /// raised, proposing one. Owning this decision here keeps the canvas view from
    /// knowing anything about plate solving.
    ///
    /// - Parameters:
    ///   - file:       The file the tapped overlay belongs to.
    ///   - openWindow: The action that opens the results window.
    public func presentPlateSolveOrProgress( for file: OpenFile, openWindow: OpenWindowAction )
    {
        if self.plateSolveSession( for: file.id )?.phase.isInProgress == true
        {
            openWindow( id: "PlateSolveWindow", value: file.id )
        }
        else
        {
            self.presentPlateSolvePrompt( for: file )
        }
    }

    /// Raises the "Plate Solve" prompt for a file, retaining it so the confirm
    /// action can act on it. The active window presents the alert in SwiftUI.
    ///
    /// - Parameter file: The file the prompt is about.
    public func presentPlateSolvePrompt( for file: OpenFile )
    {
        self.plateSolvePromptFile        = file
        self.isPlateSolvePromptPresented = true
    }

    /// The message for the "Plate Solve" prompt, tailored to whether the file has
    /// been solved (but yielded nothing for the tapped overlay) or not solved at all.
    public var plateSolvePromptMessage: String
    {
        self.plateSolvePromptFile?.plateSolve == nil
            ? "This image hasn’t been plate-solved yet. Plate solve it to map its field — labelling the objects in view and showing the sky orientation."
            : "The plate solve didn’t provide what this overlay needs. You can run the plate solve again from the results window."
    }

    /// Confirms the "Plate Solve" prompt: starts (or re-opens) the solve for the
    /// prompted file and shows its results window. A no-op if no file is pending.
    ///
    /// - Parameters:
    ///   - apiKey:     The Astrometry.net API key.
    ///   - openWindow: The action that opens the results window.
    public func confirmPlateSolvePrompt( apiKey: String, openWindow: OpenWindowAction )
    {
        guard let file = self.plateSolvePromptFile
        else
        {
            return
        }

        self.plateSolvePromptFile = nil

        self.presentPlateSolve( for: file, apiKey: apiKey, openWindow: openWindow )
    }

    /// Routes URLs to the active window, or opens a new window when none exists.
    ///
    /// - Parameter urls: The file URLs to open.
    public func openIntoActiveWindowOrNew( urls: [ URL ] )
    {
        guard urls.isEmpty == false
        else
        {
            return
        }

        if let model = self.activeModel
        {
            model.open( urls: urls )
        }
        else
        {
            self.openWindowWithURLs?( urls )
        }
    }

    /// Forgets a window's model once its window has closed. The active model is a
    /// `weak` reference, but a closed window's model can briefly outlive its
    /// window (held by SwiftUI's scene storage); leaving it as the active model
    /// would route a subsequently opened file into a window that is gone, so no
    /// window appears. Clearing it here makes the next open create a new window.
    ///
    /// - Parameter model: The closing window's model.
    public func windowDidClose( _ model: WindowModel )
    {
        if self.activeModel === model
        {
            self.activeModel = nil
        }
    }

    /// Opens the given URLs in a brand-new window, regardless of any active
    /// window. Used by the file list's "Open in New Window" action, which must
    /// always spawn a window rather than route into the current one.
    ///
    /// - Parameter urls: The file URLs to open.
    public func openInNewWindow( urls: [ URL ] )
    {
        guard urls.isEmpty == false
        else
        {
            return
        }

        self.openWindowWithURLs?( urls )
    }

    /// Presents a Save panel and copies the file's original, unmodified FITS
    /// bytes to the chosen location. Presents an alert if the copy fails, so a
    /// save never fails silently. A cancelled panel is a no-op.
    ///
    /// The copy is byte-identical to the opened file — no re-encoding — so this
    /// is "Save As…", not an export of the rendered image.
    ///
    /// - Parameter file: The open file to copy.
    public func saveCopy( of file: OpenFile )
    {
        guard let destination = Self.runSavePanel( suggestedName: file.displayName, contentTypes: [ .fits ] )
        else
        {
            return
        }

        do
        {
            try file.copyOriginalFile( to: destination )
        }
        catch
        {
            Self.presentFailureAlert( "Could not save a copy of \u{201C}\( file.displayName )\u{201D}.", error: error )
        }
    }

    /// Presents a Save panel — with a format/quality accessory — and exports the
    /// file's *rendered* image (TIFF, PNG, or JPEG) to the chosen location.
    /// Presents an alert if encoding fails, so an export never fails silently. A
    /// cancelled panel is a no-op.
    ///
    /// Unlike ``saveCopy(of:)``, which duplicates the original FITS bytes, this
    /// encodes the display-ready pixels. If the image has not finished rendering
    /// there is nothing to export, so the user is told to try again rather than
    /// shown an empty panel.
    ///
    /// - Parameter file: The open file whose rendered image to export.
    public func exportImage( of file: OpenFile )
    {
        guard let image = file.image?.renderer.result?.image
        else
        {
            let alert = NSAlert()

            alert.messageText     = "\u{201C}\( file.displayName )\u{201D} is not ready to export yet."
            alert.informativeText = "Wait until the image has finished rendering, then try again."
            alert.alertStyle      = .informational

            alert.runModal()

            return
        }

        let options = ImageExportOptions()

        let destination = Self.runSavePanel( suggestedName: ( file.displayName as NSString ).deletingPathExtension, contentTypes: [ options.kind.utType ] )
        {
            panel in

            AnyView(
                ImageExportOptionsView( options: options )
                {
                    [ weak panel ] kind in panel?.allowedContentTypes = [ kind.utType ]
                }
            )
        }

        guard let destination
        else
        {
            return
        }

        do
        {
            try ImageExporter.write( image, format: options.format, to: destination )
        }
        catch
        {
            Self.presentFailureAlert( "Could not export \u{201C}\( file.displayName )\u{201D}.", error: error )
        }
    }

    /// Presents a Save panel with the common configuration applied and returns
    /// the chosen URL, or `nil` if the user cancels.
    ///
    /// - Parameters:
    ///   - suggestedName: The file name to pre-fill.
    ///   - contentTypes:  The allowed content types, driving the file extension.
    ///   - accessory:     An optional builder for a SwiftUI accessory view. It
    ///                    receives the panel — so the accessory can update, for
    ///                    example, `allowedContentTypes` as the user changes
    ///                    format — and the returned view is hosted with the
    ///                    event-routing fix below.
    /// - Returns: The chosen destination URL, or `nil` on cancel.
    public static func runSavePanel( suggestedName: String, contentTypes: [ UTType ], accessory: ( ( NSSavePanel ) -> AnyView )? = nil ) -> URL?
    {
        let panel = NSSavePanel()

        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes  = contentTypes

        if let accessory
        {
            // A hosting view set directly as the accessory leaves its SwiftUI
            // controls unable to receive mouse events (a menu would not open).
            // Hosting it inside a plain container pinned with Auto Layout restores
            // event routing, and tracking the intrinsic content size lets the
            // panel resize with the content.
            let hosting = NSHostingView( rootView: accessory( panel ) )

            hosting.sizingOptions = [ .intrinsicContentSize ]
            hosting.translatesAutoresizingMaskIntoConstraints = false

            let container = NSView()

            container.addSubview( hosting )

            NSLayoutConstraint.activate(
                [
                    hosting.leadingAnchor.constraint( equalTo: container.leadingAnchor ),
                    hosting.trailingAnchor.constraint( equalTo: container.trailingAnchor ),
                    hosting.topAnchor.constraint( equalTo: container.topAnchor ),
                    hosting.bottomAnchor.constraint( equalTo: container.bottomAnchor ),
                ]
            )

            panel.accessoryView = container
        }

        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Presents a warning alert describing a failed file operation, so a failure
    /// is never silent.
    ///
    /// - Parameters:
    ///   - message: The headline describing what failed.
    ///   - error:   The underlying error, shown as the informative text.
    public static func presentFailureAlert( _ message: String, error: Error )
    {
        let alert = NSAlert()

        alert.messageText     = message
        alert.informativeText = error.localizedDescription
        alert.alertStyle      = .warning

        alert.runModal()
    }

    /// Presents an Open panel for FITS files.
    ///
    /// - Returns: The chosen URLs, or an empty array if cancelled.
    public func runOpenPanel() -> [ URL ]
    {
        let panel = NSOpenPanel()

        panel.allowsMultipleSelection = true
        panel.canChooseDirectories    = false
        panel.canChooseFiles          = true
        panel.allowedContentTypes     = [ .fits ]

        return panel.runModal() == .OK ? panel.urls : []
    }
}
