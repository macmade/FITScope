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

/// The "FILES" sidebar: a titled header with an add button and a selectable
/// list of open files.
public struct FilesSidebarView: View
{
    /// The window's open files and selection.
    @ObservedObject private var model: WindowModel

    /// App-wide coordination, used to open files via the Open panel.
    @EnvironmentObject private var appModel: AppModel

    /// Opens the session metric-trend charts window.
    @Environment( \.openWindow ) private var openWindow

    /// The shared file actions the rows' context menu invokes.
    private let actions: FileActions

    /// Creates the files sidebar.
    ///
    /// - Parameters:
    ///   - model:   The window model to drive.
    ///   - actions: The shared file actions the rows' context menu invokes.
    public init( model: WindowModel, actions: FileActions )
    {
        self.model   = model
        self.actions = actions
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

                if let count = Self.fileCountLabel( for: self.model.files.count )
                {
                    Text( count )
                        .font( .system( size: 10, weight: .semibold ) )
                        .monospacedDigit()
                        .foregroundStyle( .tertiary )
                        .accessibilityIdentifier( AccessibilityIdentifier.FilesSidebarView.fileCount )
                }

                Spacer()

                self.metricsButton

                self.sortMenu

                Button( action: self.runOpenPanel )
                {
                    Image( systemName: "plus" )
                }
                .buttonStyle( .plain )
                .foregroundStyle( .secondary )
                .help( "Open Images…" )
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
                        file:       file,
                        isSelected: file.id == self.model.selectedFileID,
                        sortKey:    self.model.sortKey,
                        actions:    self.actions
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

    /// The button that opens the session metric-trend charts window, styled like
    /// the header's other icon buttons. Disabled until at least one file is open,
    /// mirroring the menu command.
    private var metricsButton: some View
    {
        Button
        {
            self.openWindow( id: "SessionMetricsWindow", value: SingletonWindow.token )
        }
        label:
        {
            Image( systemName: "chart.line.uptrend.xyaxis" )
        }
        .buttonStyle( .plain )
        .foregroundStyle( .secondary )
        .disabled( self.model.files.isEmpty )
        .help( "Session Metrics…" )
        .accessibilityIdentifier( AccessibilityIdentifier.FilesSidebarView.metricsButton )
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

    /// Presents an open panel and opens the chosen image files into the window.
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

    /// The badge label to show next to the "FILES" header for the given open-file
    /// count, or `nil` when the count is zero so an empty sidebar shows no badge.
    ///
    /// - Parameter count: The number of open files.
    /// - Returns: The count as a string, or `nil` when no files are open.
    nonisolated static func fileCountLabel( for count: Int ) -> String?
    {
        count > 0 ? String( count ) : nil
    }
}

#Preview
{
    let model      = WindowModel()
    let appModel   = AppModel()
    let actions    = FileActions( appModel: appModel, model: model, preferences: Preferences() )
    let sampleURLs = [ PreviewHelper.url( file: .M42 ), PreviewHelper.url( file: .HST_FOS ) ].compactMap { $0 }

    model.open( urls: sampleURLs )

    return FilesSidebarView( model: model, actions: actions )
        .environmentObject( appModel )
        .frame( width: 280, height: 400 )
}
