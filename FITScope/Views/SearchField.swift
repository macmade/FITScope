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

struct SearchField: View
{
    @Binding public var text: String

    public let icon             = Image( systemName: "magnifyingglass" )
    public let iconColor        = Color( .gray )
    public let placeholder      = "Search"
    public let placeholderColor = Color( .gray )
    public let background       = Color( .controlBackgroundColor )
    public let cornerRadius     = 10.0
    public let height           = 30.0

    public var onTextChange: ( ( String ) -> Void )?

    var body: some View
    {
        ZStack
        {
            HStack
            {
                self.icon.foregroundColor( self.iconColor )

                TextField(
                    "",
                    text:   $text,
                    prompt: Text( self.placeholder ).foregroundStyle( self.placeholderColor )
                )
                .textFieldStyle( PlainTextFieldStyle() )
                .onChange( of: text )
                {
                    self.onTextChange?( self.text )
                }

                if self.text.isEmpty == false
                {
                    Button
                    {
                        self.text = ""
                    }
                    label:
                    {
                        Image( systemName: "xmark.circle.fill" ).foregroundStyle( self.iconColor )
                    }
                    .buttonStyle( PlainButtonStyle() )
                }
            }
            .padding( 5 )
        }
        .frame( height: self.height )
        .background
        {
            RoundedRectangle( cornerRadius: self.cornerRadius ).foregroundColor( self.background )
        }
    }
}

#Preview
{
    struct Preview: View
    {
        @State public var text = ""

        var body: some View
        {
            SearchField( text: $text )
            {
                print( "Search Text: \( $0 )" )
            }
            .padding()
        }
    }

    return Preview()
}
