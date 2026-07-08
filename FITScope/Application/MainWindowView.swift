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
import SwiftUtilities
import UniformTypeIdentifiers

/// The root view of a window: a three-column layout (files + image info |
/// image canvas | inspector). The image canvas hosts its own floating toolbar
/// and status pill, so the leading and trailing sidebars extend the full
/// height of the window. Owns the window's ``WindowModel``.
public struct MainWindowView: View
{
    /// The size a main window opens at on first launch, before the user has
    /// resized one. Once resized, the remembered size (``Preferences/mainWindowSize``)
    /// takes over, so this default only ever applies to a never-resized install.
    ///
    /// Sits comfortably above the window's `900 × 600` minimum and fits a 13"
    /// display while giving the image canvas room on larger screens.
    public static let defaultSize = CGSize( width: 1280, height: 840 )

    /// The window's open files and selection.
    @StateObject private var model = WindowModel()

    /// Retains the window's close-confirmation delegate for the window's lifetime
    /// (`NSWindow.delegate` is weak), so closing a window with adjustments prompts
    /// before discarding them. Installed once the hosting `NSWindow` is known.
    @State private var closeConfirmation = WindowCloseConfirmationDelegate()

    /// Whether the trailing inspector is shown.
    @State private var showInspector = true

    /// The shared app model used to route global open actions.
    @EnvironmentObject private var appModel: AppModel

    /// The shared preferences, whose ``Preferences/weightFormula`` drives the
    /// window's per-image weight computation.
    @EnvironmentObject private var preferences: Preferences

    /// Whether the window is currently the key window.
    @Environment( \.appearsActive ) private var appearsActive

    /// Opens the Settings scene, used by the "no API key" alert's action.
    @Environment( \.openSettings ) private var openSettings

    /// Dismisses a window by id/value, used to close a file's plate-solve results
    /// window when the file itself is closed.
    @Environment( \.dismissWindow ) private var dismissWindow

    /// Opens the plate-solve results window when the shared "Plate Solve" prompt is
    /// confirmed.
    @Environment( \.openWindow ) private var openWindow

    /// The API-key store, read for the Astrometry.net key when confirming a plate
    /// solve from the shared prompt.
    @EnvironmentObject private var apiKeyStore: APIKeyStore

    /// The file URLs to load when the window first appears.
    private let initialURLs: [ URL ]

    /// Creates the window view.
    ///
    /// - Parameter initialURLs: The file URLs to load when the window appears.
    public init( initialURLs: [ URL ] = [] )
    {
        self.initialURLs = initialURLs
    }

    /// The view's content.
    public var body: some View
    {
        // Stable references for the window accessor's escaping callback, grabbed
        // here during `body` (where reading them is valid) rather than from the
        // property wrappers inside the deferred closure.
        let model             = self.model
        let closeConfirmation = self.closeConfirmation
        let preferences       = self.preferences

        // The file actions shared by the sidebar rows' and the image canvas's
        // context menus, so both menus behave identically. Built here where the
        // app model, window model and preferences are all in scope.
        let fileActions = FileActions( appModel: self.appModel, model: self.model, preferences: self.preferences )

        NavigationSplitView
        {
            FilesSidebarView( model: self.model, actions: fileActions )
                .navigationSplitViewColumnWidth( min: 250, ideal: 300, max: 500 )
        }
        detail:
        {
            Group
            {
                if self.model.selectedFile == nil
                {
                    VStack( spacing: 12 )
                    {
                        Image( nsImage: NSImage( named: NSImage.applicationIconName ) ?? NSImage() )
                            .resizable()
                            .aspectRatio( contentMode: .fit )
                            .frame( width: 160, height: 160 )

                        Text( "No File Open" )
                            .font( .title2 ).bold()

                        Text( "Open an image, or drag one here." )
                            .foregroundStyle( .secondary )
                    }
                    .frame( maxWidth: .infinity, maxHeight: .infinity )
                    .background( .black )
                }
                else if let file = self.model.selectedFile
                {
                    ImageDetailView( file: file, actions: fileActions )
                }
            }
        }
        .navigationSplitViewStyle( .balanced )
        .inspector( isPresented: self.$showInspector )
        {
            Group
            {
                if let file = self.model.selectedFile
                {
                    InspectorColumnView( file: file )
                }
                else
                {
                    Color.clear
                }
            }
            .inspectorColumnWidth( min: 250, ideal: 300, max: 500 )
        }
        .toolbar
        {
            ToolbarItem( placement: .primaryAction )
            {
                if let file = self.model.selectedFile
                {
                    ImageShareLink( file: file )
                }
            }

            ToolbarItem( placement: .primaryAction )
            {
                Button
                {
                    self.showInspector.toggle()
                }
                label:
                {
                    Image( systemName: "sidebar.trailing" )
                }
                .help( self.inspectorToggleHelp )
                .accessibilityIdentifier( AccessibilityIdentifier.MainWindowView.inspectorToggle )
            }
        }
        .frame( minWidth: 900, minHeight: 600 )
        // Remember the window's size across launches. State restoration (SwiftUI's
        // built-in frame persistence) is disabled app-wide so the app always
        // launches clean, so the size is persisted manually: the window's frame
        // size is written to the shared preferences here and reapplied via
        // `.defaultWindowPlacement` in `FITScopeApp` whenever a window is placed.
        // The frame size (not the SwiftUI content size) is stored deliberately —
        // `WindowPlacement(size:)` restores the whole window frame, so saving the
        // content size would lose the title bar's height on every launch, shrinking
        // the window each time. `mainWindowSize` is non-`@Published`, so writing it
        // here churns no re-renders.
        .onWindowSizeChange { preferences.mainWindowSize = $0 }
        // Warn before closing a window whose images have adjustments, so they are
        // not discarded silently. Installed on the hosting NSWindow (the veto point
        // for both the close button and ⌘W), forwarding to SwiftUI's own delegate.
        .background(
            WindowAccessor
            {
                window in closeConfirmation.install( on: window ) { [ weak model ] in model?.hasAdjustedFiles ?? false }
            }
        )
        .navigationTitle( self.model.selectedFile?.displayName ?? Bundle.main.title )
        .navigationDocument( ifPresent: self.model.selectedFile?.url )
        // Publish the selected file as the scene's focused object so the File-menu
        // commands (Save As / Export) target and validate against it.
        .focusedSceneObject( self.model.selectedFile )
        // The "no API key" alert, with an action that opens Settings (the native
        // SwiftUI way) straight to the API Keys tab. Bound directly to the shared
        // flag — a single source of truth, so SwiftUI never writes a derived value
        // back during an update ("publishing changes from within view updates").
        .alert( "No Astrometry.net API Key", isPresented: self.$appModel.isMissingAPIKeyAlertPresented )
        {
            Button( "Open Preferences\u{2026}" )
            {
                self.appModel.selectedPreferencesTab = .apiKeys

                self.openSettings()
            }

            Button( "Cancel", role: .cancel ) {}
        }
        message:
        {
            Text( "Add your free Astrometry.net API key in Preferences \u{25B8} API Keys, then try plate solving again." )
        }
        // The shared "Plate Solve" prompt, raised by the app model when a
        // solve-dependent overlay is tapped with nothing to reveal. Bound to the
        // shared flag so the canvas view stays free of plate-solve details.
        .alert( "Plate Solve", isPresented: self.$appModel.isPlateSolvePromptPresented )
        {
            Button( "Plate Solve\u{2026}" )
            {
                self.appModel.confirmPlateSolvePrompt( apiKey: self.apiKeyStore.astrometryNetKey, openWindow: self.openWindow )
            }

            Button( "Cancel", role: .cancel ) {}
        }
        message:
        {
            Text( self.appModel.plateSolvePromptMessage )
        }
        .onOpenURL
        {
            url in self.model.open( urls: [ url ] )
        }
        .onDrop( of: [ .fileURL ], isTargeted: nil )
        {
            providers in self.handleDrop( providers: providers )
        }
        .onAppear
        {
            // When a file is closed, end every frame's solve and dismiss each frame's
            // results window, so none is left behind referencing a no-longer-open
            // file. `endPlateSolve` returns the ended frames' targets to dismiss.
            // Captured explicitly (not the whole view) since the closure outlives this
            // call, and set before any file can close.
            let appModel = self.appModel
            let dismiss  = self.dismissWindow

            self.model.onFileClosed =
            {
                id in

                appModel.endPlateSolve( for: id ).forEach
                {
                    dismiss( id: "PlateSolveWindow", value: $0 )
                }
            }

            guard self.model.files.isEmpty, self.initialURLs.isEmpty == false
            else
            {
                return
            }

            // `onAppear` runs within SwiftUI's update pass; opening here sets the
            // model's @Published state, which would be reported as "publishing
            // changes from within view updates". Defer it to a fresh run-loop turn.
            DispatchQueue.main.async
            {
                self.model.open( urls: self.initialURLs )
            }
        }
        .onChange( of: self.appearsActive, initial: true )
        {
            _, active in if active { self.appModel.activeModel = self.model }
        }
        // Keep the window's weight formula in step with the user's preference, so
        // editing it re-ranks the open files live.
        .onChange( of: self.preferences.weightFormula, initial: true )
        {
            _, source in self.model.weightFormulaSource = source
        }
        .onDisappear
        {
            self.appModel.windowDidClose( self.model )
        }
    }

    /// The inspector toggle's tooltip, matching the system sidebar toggle's
    /// wording exactly ("Show Sidebar" / "Hide Sidebar") so the two
    /// window-chrome toggles read consistently.
    private var inspectorToggleHelp: String
    {
        self.showInspector ? "Hide Inspector" : "Show Inspector"
    }

    /// Loads dropped file URLs into the window.
    ///
    /// - Parameter providers: The dropped item providers.
    /// - Returns: `true` when at least one file URL was accepted.
    private func handleDrop( providers: [ NSItemProvider ] ) -> Bool
    {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier( UTType.fileURL.identifier ) }

        guard fileProviders.isEmpty == false
        else
        {
            return false
        }

        for provider in fileProviders
        {
            _ = provider.loadObject( ofClass: URL.self )
            {
                url, _ in

                guard let url, DropAcceptance.acceptable( url )
                else
                {
                    return
                }

                Task
                {
                    @MainActor in self.model.open( urls: [ url ] )
                }
            }
        }

        return true
    }
}
