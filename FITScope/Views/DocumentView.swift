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

public struct DocumentView: View
{
    @Binding        private var document: FITSDocument
    @ObservedObject private var loader:   FITSImageLoader

    @Environment( \.openWindow ) private var openWindow

    public init( url: URL, document: Binding< FITSDocument > )
    {
        self._document = document
        self.loader    = FITSImageLoader( url: url, document: document.wrappedValue )
    }

    public var body: some View
    {
        VStack
        {
            if let image = self.loader.image
            {
                VStack( alignment: .leading, spacing: 0 )
                {
                    Button( action: { self.openWindow( id: "InfoWindow", value: image.info ) }, label: { Text( "Properties" ) } )
                        .keyboardShortcut( "I", modifiers: [ .command ] )
                        .padding()

                    Divider()

                    ImageView( renderer: image.renderer )
                        .frame( maxWidth: .infinity, maxHeight: .infinity )
                }
            }
            else if let error = self.loader.error
            {
                ErrorView( title: "Error Loading FITS File", message: error.localizedDescription )
                    .padding()
            }
            else
            {
                LoadingView( title: "Loading FITS file..." )
                    .padding()
            }
        }
        .frame( minWidth: 800, minHeight: 600 )
        .task
        {
            await self.loader.load()
        }
    }
}

#Preview
{
    VStack
    {
        if let url  = PreviewHelper.url( file: .M42 ),
           let data = PreviewHelper.data( file: .M42 )
        {
            DocumentView( url: url, document: .constant( FITSDocument( data: data ) ) )
        }
        else
        {
            ErrorView( title: "No Data", message: nil )
        }

        Divider()

        if let url  = PreviewHelper.url( file: .HST_FOS ),
           let data = PreviewHelper.data( file: .HST_FOS )
        {
            DocumentView( url: url, document: .constant( FITSDocument( data: data ) ) )
        }
        else
        {
            ErrorView( title: "No Data", message: nil )
        }
    }
}
