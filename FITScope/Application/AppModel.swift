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

    /// The in-flight or finished plate-solve sessions, keyed by the frame they
    /// solve (plate solving is per-frame). The results window resolves the live
    /// session for a frame from here, so the long-running solve outlives the view
    /// that started it.
    @Published public private( set ) var plateSolveSessions: [ PlateSolveTarget: PlateSolveSession ] = [ : ]

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

    /// The plate-solve session for a frame, or `nil` when none has been started.
    ///
    /// - Parameter target: The frame's plate-solve target.
    /// - Returns: The session, if one exists.
    public func plateSolveSession( for target: PlateSolveTarget ) -> PlateSolveSession?
    {
        self.plateSolveSessions[ target ]
    }

    /// The plate-solve target for a file's currently shown frame.
    ///
    /// - Parameter file: The file.
    /// - Returns: The target identifying the selected frame.
    private func target( for file: OpenFile ) -> PlateSolveTarget
    {
        PlateSolveTarget( fileID: file.id, frameIndex: file.selectedFrameIndex )
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

        guard let frame = file.image
        else
        {
            return false
        }

        let target  = self.target( for: file )
        let session = PlateSolveSession( frame: frame, fileName: file.displayName, fileURL: file.url, frameCount: file.frames.count, apiKey: apiKey, client: client )

        self.plateSolveSessions[ target ] = session

        session.start()

        return true
    }

    /// Ends every plate solve for a file — one per frame — cancelling each in-flight
    /// solve and forgetting its session, so a closed file leaves nothing behind. Safe
    /// to call for a file that has no session. Returns the targets whose sessions were
    /// removed, so the caller can dismiss each frame's results window (which needs
    /// SwiftUI's dismiss action).
    ///
    /// - Parameter id: The file's identifier.
    /// - Returns: The frame targets whose sessions were ended.
    @discardableResult
    public func endPlateSolve( for id: OpenFile.ID ) -> [ PlateSolveTarget ]
    {
        let targets = self.plateSolveSessions.keys.filter { $0.fileID == id }

        targets.forEach
        {
            self.plateSolveSessions[ $0 ]?.cancel()
            self.plateSolveSessions[ $0 ] = nil
        }

        return targets
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
        let target = self.target( for: file )

        if self.plateSolveSession( for: target ) != nil
        {
            openWindow( id: "PlateSolveWindow", value: target )

            return
        }

        guard self.beginPlateSolve( of: file, apiKey: apiKey )
        else
        {
            return
        }

        openWindow( id: "PlateSolveWindow", value: target )
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
        if self.plateSolveSession( for: self.target( for: file ) )?.phase.isInProgress == true
        {
            openWindow( id: "PlateSolveWindow", value: self.target( for: file ) )
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
        self.plateSolvePromptFile?.image?.plateSolve == nil
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

    /// Presents a Save panel and copies the file's original, unmodified bytes
    /// to the chosen location. Presents an alert if the copy fails, so a
    /// save never fails silently. A cancelled panel is a no-op.
    ///
    /// The copy is byte-identical to the opened file — no re-encoding — so this
    /// is "Save As…", not an export of the rendered image.
    ///
    /// - Parameter file: The open file to copy.
    public func saveCopy( of file: OpenFile )
    {
        let contentType = UTType( filenameExtension: file.url.pathExtension ) ?? .fits

        guard let destination = Self.runSavePanel( suggestedName: file.displayName, contentTypes: [ contentType ] )
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
    /// Unlike ``saveCopy(of:)``, which duplicates the original bytes, this
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

    /// Opens the file's *original*, unmodified file in the given external
    /// application. The launch errors are surfaced in an alert so an *Open With*
    /// never fails silently.
    ///
    /// This is the counterpart of ``saveCopy(of:)``: it hands the original bytes
    /// to another app, rather than the rendered image.
    ///
    /// - Parameters:
    ///   - file:        The open file whose original to open.
    ///   - application: The application bundle URL to open it with.
    public func openOriginalFile( _ file: OpenFile, with application: URL )
    {
        self.open( [ file.url ], with: application, failureMessage: "Could not open \u{201C}\( file.displayName )\u{201D}." )
    }

    /// Opens the file's *rendered* image in the given external application.
    ///
    /// The display-ready pixels are written to a temporary lossless TIFF (via
    /// ``ExternalImageFile``) and that file is opened, so the external app sees
    /// the processed result rather than the raw source data. If the image has not
    /// finished rendering there is nothing to open, so the user is told to try
    /// again. Encoding and launch errors are surfaced in an alert.
    ///
    /// - Parameters:
    ///   - file:        The open file whose rendered image to open.
    ///   - application: The application bundle URL to open it with.
    public func openRenderedImage( of file: OpenFile, with application: URL )
    {
        guard let image = file.image?.renderer.result?.image
        else
        {
            Self.presentNotReadyAlert( for: file )

            return
        }

        do
        {
            let url = try ExternalImageFile.write( image, sourceName: file.displayName )

            self.open( [ url ], with: application, failureMessage: "Could not open \u{201C}\( file.displayName )\u{201D}." )
        }
        catch
        {
            Self.presentFailureAlert( "Could not open \u{201C}\( file.displayName )\u{201D}.", error: error )
        }
    }

    /// Presents an application chooser and opens the file's *original* file
    /// with the picked application. A cancelled chooser is a no-op. Backs the
    /// *Open With ▸ Other…* menu item.
    ///
    /// - Parameter file: The open file whose original to open.
    public func openOriginalFile( withOther file: OpenFile )
    {
        guard let application = Self.runChooseApplicationPanel()
        else
        {
            return
        }

        self.openOriginalFile( file, with: application )
    }

    /// Presents an application chooser and opens the file's *rendered* image with
    /// the picked application. A cancelled chooser is a no-op. Backs the *Open
    /// With ▸ Other…* menu item.
    ///
    /// - Parameter file: The open file whose rendered image to open.
    public func openRenderedImage( withOther file: OpenFile )
    {
        guard let application = Self.runChooseApplicationPanel()
        else
        {
            return
        }

        self.openRenderedImage( of: file, with: application )
    }

    /// Opens the given files in an external application, surfacing any launch
    /// error in an alert. The completion handler runs off the main actor, so the
    /// alert is hopped back onto it.
    ///
    /// - Parameters:
    ///   - urls:           The files to open.
    ///   - application:    The application bundle URL to open them with.
    ///   - failureMessage: The alert headline shown if the launch fails.
    private func open( _ urls: [ URL ], with application: URL, failureMessage: String )
    {
        NSWorkspace.shared.open( urls, withApplicationAt: application, configuration: NSWorkspace.OpenConfiguration() )
        {
            _, error in

            guard let error
            else
            {
                return
            }

            let details = error.localizedDescription

            Task
            {
                @MainActor in Self.presentFailureAlert( failureMessage, details: details )
            }
        }
    }

    /// Presents an informational alert telling the user the image is still
    /// rendering, so an *Open With* on the rendered image never fails silently.
    ///
    /// - Parameter file: The file that is not ready yet.
    private static func presentNotReadyAlert( for file: OpenFile )
    {
        let alert = NSAlert()

        alert.messageText     = "\u{201C}\( file.displayName )\u{201D} is not ready yet."
        alert.informativeText = "Wait until the image has finished rendering, then try again."
        alert.alertStyle      = .informational

        alert.runModal()
    }

    /// Presents an Open panel restricted to applications and returns the chosen
    /// application bundle URL, or `nil` if the user cancels. Backs the *Open With
    /// ▸ Other…* menu items.
    ///
    /// - Returns: The chosen application bundle URL, or `nil` on cancel.
    public static func runChooseApplicationPanel() -> URL?
    {
        let panel = NSOpenPanel()

        panel.allowsMultipleSelection = false
        panel.canChooseDirectories    = false
        panel.canChooseFiles          = true
        panel.allowedContentTypes     = [ .application ]
        panel.directoryURL            = URL( fileURLWithPath: "/Applications" )
        panel.prompt                  = "Open"
        panel.message                 = "Choose an application to open the file with."

        return panel.runModal() == .OK ? panel.url : nil
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
        self.presentFailureAlert( message, details: error.localizedDescription )
    }

    /// Presents a warning alert describing a failed file operation, so a failure
    /// is never silent. Takes the informative text directly, so a caller with
    /// only a `Sendable` description — such as an off-main completion handler —
    /// can present it without capturing a non-`Sendable` `Error`.
    ///
    /// - Parameters:
    ///   - message: The headline describing what failed.
    ///   - details: The informative text shown below the headline.
    public static func presentFailureAlert( _ message: String, details: String )
    {
        let alert = NSAlert()

        alert.messageText     = message
        alert.informativeText = details
        alert.alertStyle      = .warning

        alert.runModal()
    }

    /// Presents an Open panel for opening images.
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
