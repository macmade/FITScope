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

public struct InfoView: View
{
    public let info: FITSImageInfo

    @State private var selectedSection = 0
    @State private var searchText      = ""

    public var body: some View
    {
        VStack( spacing: 0 )
        {
            if let section = self.info.sections.first( where: { $0.index == self.selectedSection } )
            {
                InfoViewTable( properties: Self.filter( properties: section.properties, text: self.searchText ) )
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
                .fixedSize()

                SearchField( text: $searchText )
                {
                    _ in
                }
            }
            .padding()
        }
        .frame( minWidth: 600, minHeight: 500 )
        .onChange( of: self.selectedSection )
        {
            _, _ in self.searchText = ""
        }
    }

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
