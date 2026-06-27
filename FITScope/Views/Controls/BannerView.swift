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

/// A compact, dismissible banner that overlays content with an icon, a title
/// and a message, plus a close button.
///
/// It is deliberately content-agnostic — the icon, tint and text are all
/// supplied by the caller — so it can surface any transient notice (an error,
/// a warning, an informational message) layered over an existing view rather
/// than replacing it.
public struct BannerView: View
{
    /// The banner's bold headline.
    public let title: String

    /// The secondary descriptive text below the title.
    public let message: String

    /// The SF Symbol name shown as the leading icon.
    public let systemImage: String

    /// The tint applied to the leading icon.
    public let tint: Color

    /// Invoked when the user taps the close button.
    public let onDismiss: () -> Void

    /// Creates a banner.
    ///
    /// - Parameters:
    ///   - title:       The bold headline.
    ///   - message:     The secondary descriptive text.
    ///   - systemImage: The SF Symbol name for the leading icon.
    ///   - tint:        The icon tint; defaults to the accent colour.
    ///   - onDismiss:   The action run when the close button is tapped.
    public init( title: String, message: String, systemImage: String, tint: Color = .accentColor, onDismiss: @escaping () -> Void )
    {
        self.title       = title
        self.message     = message
        self.systemImage = systemImage
        self.tint        = tint
        self.onDismiss   = onDismiss
    }

    /// The view's content.
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
        {}
    }
    .padding()
    .frame( width: 500 )
}
