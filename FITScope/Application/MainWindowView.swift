/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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
/// image canvas | inspector) above a full-width status bar. Owns the window's
/// ``WindowModel``.
public struct MainWindowView: View
{
    /// The window's open files and selection.
    @StateObject private var model = WindowModel()

    /// The current cursor readout shown in the status bar.
    @State private var readout = CursorReadout.empty

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
        VStack( spacing: 0 )
        {
            NavigationSplitView
            {
                FilesSidebarView( model: self.model )
                    .navigationSplitViewColumnWidth( min: 200, ideal: 215, max: 320 )
            }
            content:
            {
                Group
                {
                    if self.model.selectedFile == nil
                    {
                        ContentUnavailableView
                        {
                            Label( "No File Open", systemImage: "photo.on.rectangle.angled" )
                        }
                        description:
                        {
                            Text( "Open a FITS file, or drag one here." )
                        }
                        .frame( maxWidth: .infinity, maxHeight: .infinity )
                        .background( .black )
                    }
                    else if let file = self.model.selectedFile
                    {
                        ImageCanvasView( file: file )
                        {
                            readout in self.readout = readout
                        }
                    }
                }
            }
            detail:
            {
                Group
                {
                    if let image = self.model.selectedFile?.image
                    {
                        InspectorView( image: image )
                    }
                    else
                    {
                        Color.clear
                    }
                }
                .frame( maxWidth: .infinity, maxHeight: .infinity )
                .navigationSplitViewColumnWidth( min: 240, ideal: 255, max: 360 )
            }
            .navigationSplitViewStyle( .balanced )

            StatusBarView( status: "Ready", readout: self.readout, dimensions: self.dimensionsSummary )
        }
        .frame( minWidth: 900, minHeight: 600 )
        .navigationTitle( self.model.selectedFile?.displayName ?? Bundle.main.title )
        .onOpenURL
        {
            url in self.model.open( urls: [ url ] )
        }
        .onDrop( of: [ .fileURL ], isTargeted: nil )
        {
            providers in self.handleDrop( providers: providers )
        }
        .onChange( of: self.model.selectedFileID )
        {
            _, _ in self.readout = .empty
        }
        .onAppear
        {
            if self.model.files.isEmpty, self.initialURLs.isEmpty == false
            {
                self.model.open( urls: self.initialURLs )
            }
        }
        .onChange( of: self.appearsActive, initial: true )
        {
            _, active in if active { self.appModel.activeModel = self.model }
        }
    }

    /// The trailing dimensions / bit-depth summary for the selected file, or
    /// `nil` when no image is loaded.
    private var dimensionsSummary: String?
    {
        guard let info = self.model.selectedFile?.image?.info,
              let summary = ImageInformation( info: info )
        else
        {
            return nil
        }

        return "\( summary.dimensions ) • \( summary.bitDepth )"
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
