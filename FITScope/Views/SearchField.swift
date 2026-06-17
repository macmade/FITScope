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

/// A rounded search field with a leading magnifying-glass icon and a trailing
/// clear button that appears once text is entered.
struct SearchField: View
{
    /// The bound search text.
    @Binding public var text: String

    /// The leading icon.
    public let icon             = Image( systemName: "magnifyingglass" )

    /// The colour of the leading and clear icons.
    public let iconColor        = Color( .gray )

    /// The placeholder shown when the field is empty.
    public let placeholder      = "Search"

    /// The placeholder text colour.
    public let placeholderColor = Color( .gray )

    /// The field's background fill.
    public let background       = Color( .controlBackgroundColor )

    /// The corner radius of the background.
    public let cornerRadius     = 10.0

    /// The fixed height of the field.
    public let height           = 30.0

    /// Called with the new text whenever it changes.
    public var onTextChange: ( ( String ) -> Void )?

    /// The view's content.
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
        @State private var text = ""

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
