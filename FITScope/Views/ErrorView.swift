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

/// A full-pane error placeholder showing the app icon above an optional title
/// and message. Empty or `nil` text is omitted.
public struct ErrorView: View
{
    /// The bold error title, or `nil`/empty to omit it.
    public let title:   String?

    /// The descriptive message, or `nil`/empty to omit it.
    public let message: String?

    /// The view's content.
    public var body: some View
    {
        VStack( alignment: .center )
        {
            Image( nsImage: NSImage( named: NSImage.applicationIconName ) ?? NSImage() )
                .resizable()
                .frame( width: 200, height: 200 )
                .aspectRatio( contentMode: .fit )

            if let title = self.title, title.isEmpty == false
            {
                Text( title )
                    .font( .title2 )
                    .bold()
            }

            if let message = self.message, message.isEmpty == false
            {
                Text( message )
                    .font( .body )
                    .foregroundStyle( Color.secondary )
            }
        }
        .frame( minWidth: 400, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity )
    }
}

#Preview
{
    VStack( alignment: .center )
    {
        ErrorView( title: "Error", message: "An error occured - Please try again..." )
        Divider()
        ErrorView( title: nil, message: "An error occured - Please try again..." )
        Divider()
        ErrorView( title: "Error", message: nil )
    }
    .padding()
}
