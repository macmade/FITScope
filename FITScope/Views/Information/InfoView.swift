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

import SwiftFITS
import SwiftUI

/// The properties window: a header-keyword table with a section picker and a
/// search field that filters the visible keywords.
public struct InfoView: View
{
    /// The file metadata being browsed.
    public let info: FITSImageInfo

    /// The index of the section currently shown in the table.
    @State private var selectedSection = 0

    /// The current search query used to filter keywords.
    @State private var searchText      = ""

    /// The view's content.
    public var body: some View
    {
        VStack( spacing: 0 )
        {
            if let section = self.info.sections.first( where: { $0.index == self.selectedSection } )
            {
                InfoViewTable( properties: Self.filter( properties: section.properties, text: self.searchText ) )
                    .accessibilityIdentifier( AccessibilityIdentifier.InfoView.table )
            }
            else
            {
                ErrorView( title: "No section selected", message: nil )
                    .padding()
            }

            Divider()

            HStack
            {
                Picker( "Section:", selection: $selectedSection )
                {
                    ForEach( self.info.sections )
                    {
                        Text( $0.title ).tag( $0.index )
                    }
                }
                .labelsHidden()
                .fixedSize()
                .accessibilityIdentifier( AccessibilityIdentifier.InfoView.sectionPicker )

                SearchField( text: $searchText )
                {
                    _ in
                }
                .accessibilityIdentifier( AccessibilityIdentifier.InfoView.searchField )

                self.exportMenu
            }
            .padding()
        }
        .frame( minWidth: 600, minHeight: 500 )
        .onChange( of: self.selectedSection )
        {
            _, _ in self.searchText = ""
        }
    }

    /// Filters properties to those whose name, kind, value or comment contains
    /// the query, case- and diacritic-insensitively.
    ///
    /// - Parameters:
    ///   - properties: The properties to filter.
    ///   - text:       The search query; an empty query returns all properties.
    /// - Returns: The matching properties.
    public static func filter( properties: [ FITSImageProperty ], text: String ) -> [ FITSImageProperty ]
    {
        if text.isEmpty
        {
            return properties
        }

        return properties.filter
        {
            let values = [ $0.name, $0.kind, $0.value, $0.comment ]

            return values.contains
            {
                $0.localizedCaseInsensitiveContains( text )
            }
        }
    }

    /// The export menu: a format choice per scope. The displayed-section options
    /// appear only when the file has more than one section (otherwise the displayed
    /// section is the whole file).
    private var exportMenu: some View
    {
        Menu( "Export…" )
        {
            if self.info.sections.count > 1
            {
                Button( "Displayed Section as CSV" ) { self.export( sections: self.displayedSections, format: .csv ) }
                Button( "Displayed Section as TSV" ) { self.export( sections: self.displayedSections, format: .tsv ) }

                Divider()

                Button( "All Sections as CSV" ) { self.export( sections: self.info.sections, format: .csv ) }
                Button( "All Sections as TSV" ) { self.export( sections: self.info.sections, format: .tsv ) }
            }
            else
            {
                Button( "As CSV" ) { self.export( sections: self.info.sections, format: .csv ) }
                Button( "As TSV" ) { self.export( sections: self.info.sections, format: .tsv ) }
            }
        }
        .fixedSize()
        .accessibilityIdentifier( AccessibilityIdentifier.InfoView.exportButton )
    }

    /// The sections currently shown in the picker (a single section).
    private var displayedSections: [ FITSImageSection ]
    {
        self.info.sections.filter { $0.index == self.selectedSection }
    }

    /// Exports the given sections to a CSV or TSV file the user chooses, in a save
    /// panel for the chosen format (so the extension is fixed). A cancelled panel is
    /// a no-op; a write failure is surfaced in an alert rather than failing silently.
    ///
    /// - Parameters:
    ///   - sections: The sections to serialize.
    ///   - format:   The output format.
    private func export( sections: [ FITSImageSection ], format: HeaderExport.Format )
    {
        let suggestedName = "\( self.info.url.deletingPathExtension().lastPathComponent )-headers"

        guard let destination = AppModel.runSavePanel( suggestedName: suggestedName, contentTypes: [ format.contentType ] )
        else
        {
            return
        }

        let content = HeaderExport.export( sections, as: format )

        do
        {
            try Data( content.utf8 ).write( to: destination )
        }
        catch
        {
            AppModel.presentFailureAlert( "Could not export the FITS headers.", error: error )
        }
    }
}

#Preview
{
    if let url  = PreviewHelper.url( file: .HST_FOS ),
       let file = PreviewHelper.file( file: .HST_FOS )
    {
        InfoView( info: FITSImageInfo( url: url, file: file ) )
    }
    else
    {
        ErrorView( title: "No Data", message: nil )
    }
}
