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

/// The root view of a window: a three-column layout (files + image info |
/// image canvas | inspector). The image canvas hosts its own floating toolbar
/// and status pill, so the leading and trailing sidebars extend the full
/// height of the window. Owns the window's ``WindowModel``.
public struct MainWindowView: View
{
    /// The window's open files and selection.
    @StateObject private var model = WindowModel()

    /// Whether the trailing inspector is shown.
    @State private var showInspector = true

    /// The shared app model used to route global open actions.
    @EnvironmentObject private var appModel: AppModel

    /// Whether the window is currently the key window.
    @Environment( \.appearsActive ) private var appearsActive

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
        NavigationSplitView
        {
            FilesSidebarView( model: self.model )
                .navigationSplitViewColumnWidth( min: 200, ideal: 215, max: 320 )
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

                        Text( "Open a FITS file, or drag one here." )
                            .foregroundStyle( .secondary )
                    }
                    .frame( maxWidth: .infinity, maxHeight: .infinity )
                    .background( .black )
                }
                else if let file = self.model.selectedFile
                {
                    ImageCanvasView( file: file )
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
            .inspectorColumnWidth( min: 240, ideal: 255, max: 360 )
        }
        .toolbar
        {
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
        .navigationTitle( self.model.selectedFile?.displayName ?? Bundle.main.title )
        .navigationDocument( ifPresent: self.model.selectedFile?.url )
        // Publish the selected file as the scene's focused object so the File-menu
        // commands (Save As / Export) target and validate against it.
        .focusedSceneObject( self.model.selectedFile )
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
        let fitsProviders = providers.filter { $0.hasItemConformingToTypeIdentifier( UTType.fileURL.identifier ) }

        guard fitsProviders.isEmpty == false
        else
        {
            return false
        }

        for provider in fitsProviders
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
