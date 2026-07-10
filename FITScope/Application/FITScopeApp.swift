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
import SwiftUtilities
import UniformTypeIdentifiers

/// The application entry point.
///
/// Declares the app's scenes: a `WindowGroup` whose windows host a
/// ``MainWindowView``, an auxiliary window that shows a file's header properties
/// in an ``InfoView``, and a custom About window. The standard *About* menu item
/// is replaced with one that opens the app's own ``AboutView``.
@main
public struct FITScopeApp: App
{
    /// Drives launch and system file-open behaviour.
    @NSApplicationDelegateAdaptor( AppDelegate.self ) private var appDelegate

    /// Opens an auxiliary window by identifier, used to present the custom About
    /// window.
    @Environment( \.openWindow ) private var openWindow

    /// The project's GitHub page, opened from the Help menu in lieu of a bundled
    /// help book.
    private static let helpURL = URL( string: "https://github.com/macmade/FITScope" )

    /// Creates the application.
    public init()
    {}

    /// The app's scene graph.
    public var body: some Scene
    {
        let _ = self.seedOpenWindowAction()

        WindowGroup( for: WindowContent.self )
        {
            $content in MainWindowView( initialURLs: $content.wrappedValue?.urls ?? [] )
                .environmentObject( self.appDelegate.appModel )
                .environmentObject( self.appDelegate.preferences )
                .environmentObject( self.appDelegate.apiKeyStore )
        }
        .windowStyle( .titleBar )
        // Open at the size the window was last left at, or the app default on first
        // launch. State restoration (which would persist the frame automatically) is
        // disabled below so the app launches clean, so the remembered size is applied
        // here from the shared preferences instead. This closure runs each time a
        // window is placed — including new windows opened mid-session — so it reads
        // the latest remembered size every time, rather than a value captured once at
        // launch (which `.defaultSize` would).
        .defaultWindowPlacement
        {
            _, _ in

            let size = self.appDelegate.preferences.mainWindowSize ?? MainWindowView.defaultSize

            return WindowPlacement( size: size )
        }
        .defaultLaunchBehavior( .suppressed )
        .restorationBehavior( .disabled )
        .commands
        {
            CommandGroup( replacing: CommandGroupPlacement.newItem )
            {
                Button
                {
                    openWindow( value: WindowContent() )
                }
                label:
                {
                    Label( "New Window", systemImage: "macwindow.badge.plus" )
                }
                .keyboardShortcut( "n", modifiers: .command )

                Button
                {
                    let urls = self.appDelegate.appModel.runOpenPanel()

                    if urls.isEmpty == false
                    {
                        self.appDelegate.appModel.openIntoActiveWindowOrNew( urls: urls )
                    }
                }
                label:
                {
                    Label( "Open\u{2026}", systemImage: "folder" )
                }
                .keyboardShortcut( "o", modifiers: .command )
            }

            CommandGroup( after: CommandGroupPlacement.newItem )
            {
                FileCommands( appModel: self.appDelegate.appModel )
            }

            CommandGroup( replacing: CommandGroupPlacement.appInfo )
            {
                Button( action: { openWindow( id: "AboutWindow" ) } )
                {
                    Label( "About \( Bundle.main.title )...", systemImage: "info.circle" )
                }

                Button( action: { CreditsWindowController.show( credits: AppCredits.all ) } )
                {
                    Label( "Credits\u{2026}", systemImage: "heart" )
                }

                Button
                {
                    AppUpdater().checkForUpdates()
                }
                label:
                {
                    Label( "Check for Updates\u{2026}", systemImage: "arrow.triangle.2.circlepath" )
                }
            }

            CommandGroup( after: CommandGroupPlacement.sidebar )
            {
                ViewCommands()
            }

            CommandMenu( "Image" )
            {
                ImageCommands( appModel: self.appDelegate.appModel, apiKeyStore: self.appDelegate.apiKeyStore )
            }

            CommandGroup( replacing: CommandGroupPlacement.help )
            {
                // The app ships no help book, so the standard "Help" item does
                // nothing. Point it at the project's GitHub page instead.
                Button
                {
                    if let url = Self.helpURL
                    {
                        NSWorkspace.shared.open( url )
                    }
                }
                label:
                {
                    Label( "\( Bundle.main.title ) Help", systemImage: "questionmark.circle" )
                }
                .keyboardShortcut( "?", modifiers: .command )
            }
        }

        WindowGroup( id: "InfoWindow", for: ImageMetadata.self )
        {
            if let metadata = $0.wrappedValue
            {
                InfoView( metadata: metadata )
                    .navigationTitle( metadata.url.lastPathComponent )
            }
            else
            {
                ErrorView( title: "No document loaded", message: nil )
                    .padding()
            }
        }
        .windowStyle( .titleBar )
        .restorationBehavior( .disabled )

        WindowGroup( id: "PlateSolveWindow", for: PlateSolveTarget.self )
        {
            PlateSolveWindowView( target: $0.wrappedValue )
                .environmentObject( self.appDelegate.appModel )
        }
        .windowStyle( .titleBar )
        .windowResizability( .contentSize )
        .restorationBehavior( .disabled )

        // The Levels and Curves editors have a fixed, shared width and adapt their
        // height to their content (`.windowResizability( .contentSize )`), like the
        // plate-solve window. They persist their frame across launches via
        // `.persistsWindowFrame(...)` on their content (state restoration stays off,
        // so they never reopen at launch); on first run — before a frame is saved —
        // that modifier centers the window rather than leaving it in a corner.
        Window( "Levels", id: "LevelsWindow" )
        {
            LevelsWindowView()
                .environmentObject( self.appDelegate.appModel )
        }
        .windowStyle( .titleBar )
        .windowResizability( .contentSize )
        .restorationBehavior( .disabled )

        Window( "Curves", id: "CurvesWindow" )
        {
            CurvesWindowView()
                .environmentObject( self.appDelegate.appModel )
        }
        .windowStyle( .titleBar )
        .windowResizability( .contentSize )
        .restorationBehavior( .disabled )

        Window( "Screen Transfer", id: StretchControlView.screenTransferWindowID )
        {
            STFWindowView()
                .environmentObject( self.appDelegate.appModel )
        }
        .windowStyle( .titleBar )
        .windowResizability( .contentSize )
        .restorationBehavior( .disabled )

        // The session metric-trend charts. Unlike the Levels and Curves editors,
        // the charts want room and benefit from resizing, so this window is freely
        // resizable (opening at a sensible default) rather than sized to its
        // content; it persists its frame across launches like the editors do.
        Window( "Session Metrics", id: "SessionMetricsWindow" )
        {
            SessionMetricsWindowView()
                .environmentObject( self.appDelegate.appModel )
        }
        .windowStyle( .titleBar )
        .defaultSize( width: 900, height: 760 )
        .restorationBehavior( .disabled )

        Window( "About \( Bundle.main.title )", id: "AboutWindow" )
        {
            AboutView()
                .padding()
                .fixedSize()
        }
        .windowStyle( .hiddenTitleBar )
        .windowResizability( .contentSize )
        .restorationBehavior( .disabled )
        // Open centered on screen rather than cascaded as an "additional" window.
        // This is only the initial default: while the window is open, re-issuing
        // the About command just brings it forward without moving it.
        .defaultPosition( .center )

        Settings
        {
            PreferencesView()
                .environmentObject( self.appDelegate.appModel )
                .environmentObject( self.appDelegate.preferences )
                .environmentObject( self.appDelegate.apiKeyStore )
        }
        .windowResizability( .contentSize )
    }

    /// Seeds the app model's new-window callback with the SwiftUI `openWindow`
    /// action. This runs during `body` evaluation — at App scope, before the
    /// delegate presents the launch Open panel — so opening files at launch can
    /// create a window. A view's `onAppear` cannot bootstrap this, since no
    /// window (and therefore no view) exists while the launch window is
    /// suppressed.
    private func seedOpenWindowAction()
    {
        if self.appDelegate.appModel.openWindowWithURLs == nil
        {
            self.appDelegate.appModel.openWindowWithURLs = { urls in self.openWindow( value: WindowContent( urls: urls ) ) }
        }
    }
}
