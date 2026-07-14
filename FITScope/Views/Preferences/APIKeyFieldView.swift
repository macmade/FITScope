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

/// A plain text field for a single API key, with a trailing clear button that
/// empties the field — and so removes the stored key — when it is non-empty.
public struct APIKeyFieldView: View
{
    /// The field's label.
    private let title: String

    /// The SF Symbol shown before the label.
    private let systemImage: String

    /// The binding to the key's value in the store.
    @Binding private var key: String

    /// The field's accessibility identifier.
    private let identifier: String

    /// The field's tooltip.
    private let help: String

    /// Creates an API-key field.
    ///
    /// - Parameters:
    ///   - title:       The field's label.
    ///   - systemImage: The SF Symbol shown before the label.
    ///   - key:         The binding to the key's value in the store.
    ///   - identifier:  The field's accessibility identifier.
    ///   - help:        The field's tooltip.
    public init( _ title: String, systemImage: String, key: Binding< String >, identifier: String, help: String )
    {
        self.title       = title
        self.systemImage = systemImage
        self._key        = key
        self.identifier  = identifier
        self.help        = help
    }

    /// The view's content.
    public var body: some View
    {
        LabeledContent
        {
            HStack( spacing: 6 )
            {
                TextField( "", text: self.$key, prompt: Text( "<enter key here>" ) )
                    .font( .body.monospaced() )
                    .foregroundStyle( .secondary )
                    .accessibilityIdentifier( self.identifier )
                    .help( self.help )

                if self.key.isEmpty == false
                {
                    Button
                    {
                        self.key = ""
                    }
                    label:
                    {
                        Image( systemName: "xmark.circle.fill" )
                            .foregroundStyle( .secondary )
                    }
                    .buttonStyle( .plain )
                    .help( "Clear" )
                }
            }
        }
        label:
        {
            Label( self.title, systemImage: self.systemImage )
        }
    }
}

#Preview
{
    APIKeyFieldView( "Astrometry.net", systemImage: "sparkles", key: .constant( "secret-key" ), identifier: "preview.field", help: "An API key." )
        .formStyle( .grouped )
        .padding()
}
