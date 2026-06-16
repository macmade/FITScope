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

import SwiftFITS
import SwiftUI

/// A sortable, selectable table of FITS header keywords, with columns for
/// index, name, kind, value and comment.
///
/// Keeps a locally sorted copy of the input that re-sorts when the sort order or
/// the input changes, so the displayed order tracks both the user's column
/// sorting and any change of section.
public struct InfoViewTable: View
{
    /// The keywords to display, in their natural (unsorted) order.
    public let properties: [ FITSImageProperty ]

    /// The locally sorted copy actually rendered by the table.
    @State private var sortedProperties   = [ FITSImageProperty ]()

    /// The active column sort order, defaulting to ascending index.
    @State private var sortOrder          = [ KeyPathComparator( \FITSImageProperty.index ) ]

    /// The identifiers of the currently selected rows.
    @State private var selectedProperties = Set< FITSImageProperty.ID >()

    /// The view's content.
    public var body: some View
    {
        Table( self.sortedProperties, selection: $selectedProperties, sortOrder: $sortOrder )
        {
            TableColumn( "Index", value: \.index )
            {
                InfoViewTableCell( value: "\( $0.index )", size: 10, style: .secondary )
            }
            .width( min: 20, ideal: 55, max: 1000 )

            TableColumn( "Name", value: \.name )
            {
                InfoViewTableCell( value: $0.name, size: 10, style: .primary )
            }
            .width( min: 20, ideal: 70, max: 1000 )

            TableColumn( "Kind", value: \.kind )
            {
                InfoViewTableCell( value: $0.kind, size: 10, style: .secondary )
            }
            .width( min: 20, ideal: 70, max: 1000 )

            TableColumn( "Value", value: \.value )
            {
                InfoViewTableCell( value: $0.value, size: 10, style: .primary )
            }
            .width( min: 20, ideal: 150, max: 1000 )

            TableColumn( "Comment", value: \.comment )
            {
                InfoViewTableCell( value: $0.comment, size: 10, style: .secondary )
            }
            .width( min: 20, ideal: 150, max: 1000 )
        }
        .onChange( of: sortOrder )
        {
            _, order in self.sortedProperties = self.properties.sorted( using: order )
        }
        .onChange( of: properties )
        {
            _, properties in self.sortedProperties = properties.sorted( using: self.sortOrder )
        }
        .onAppear
        {
            self.sortedProperties = self.properties.sorted( using: self.sortOrder )
        }
    }
}

#Preview
{
    if let properties = PreviewHelper.properties( file: .HST_FOS )
    {
        InfoViewTable( properties: properties )
    }
    else
    {
        ErrorView( title: "No Data", message: nil )
    }
}
