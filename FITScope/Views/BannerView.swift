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

/// A compact, dismissible banner that overlays content with an icon, a title
/// and a message, plus a close button.
///
/// It is deliberately content-agnostic — the icon, tint and text are all
/// supplied by the caller — so it can surface any transient notice (an error,
/// a warning, an informational message) layered over an existing view rather
/// than replacing it.
public struct BannerView: View
{
    public let title:       String
    public let message:     String
    public let systemImage: String
    public let tint:        Color
    public let onDismiss:   () -> Void

    public init( title: String, message: String, systemImage: String, tint: Color = .accentColor, onDismiss: @escaping () -> Void )
    {
        self.title       = title
        self.message     = message
        self.systemImage = systemImage
        self.tint        = tint
        self.onDismiss   = onDismiss
    }

    public var body: some View
    {
        HStack( alignment: .top, spacing: 8 )
        {
            Image( systemName: self.systemImage )
                .foregroundStyle( self.tint )

            VStack( alignment: .leading, spacing: 2 )
            {
                Text( self.title )
                    .font( .headline )

                Text( self.message )
                    .font( .callout )
                    .foregroundStyle( .secondary )
            }

            Spacer()

            Button
            {
                self.onDismiss()
            }
            label:
            {
                Image( systemName: "xmark.circle.fill" )
                    .foregroundStyle( .secondary )
            }
            .buttonStyle( .plain )
        }
        .padding( 12 )
        .background( .regularMaterial, in: RoundedRectangle( cornerRadius: 8 ) )
    }
}

#Preview
{
    VStack
    {
        BannerView( title: "Error Rendering Image", message: "Hyperbolic stretch requires n != 0: 0.0", systemImage: "exclamationmark.triangle.fill", tint: .yellow )
        {
        }
    }
    .padding()
    .frame( width: 500 )
}
