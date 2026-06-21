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

/// A placeholder tab for a Preferences section that is not yet available.
public struct PreferencesPlaceholderView: View
{
    /// The section's name.
    private let title: String

    /// The SF Symbol shown above the message.
    private let systemImage: String

    /// Creates a placeholder tab.
    ///
    /// - Parameters:
    ///   - title:       The section's name.
    ///   - systemImage: The SF Symbol shown above the message.
    public init( _ title: String, systemImage: String )
    {
        self.title       = title
        self.systemImage = systemImage
    }

    /// The view's content.
    public var body: some View
    {
        VStack( spacing: 10 )
        {
            Image( systemName: self.systemImage )
                .font( .system( size: 34 ) )
                .foregroundStyle( .secondary )

            Text( self.title )
                .font( .headline )

            Text( "Coming soon." )
                .font( .subheadline )
                .foregroundStyle( .secondary )
        }
        .frame( maxWidth: .infinity, maxHeight: .infinity )
    }
}

#Preview
{
    PreferencesPlaceholderView( "Information Panel", systemImage: "list.bullet.rectangle" )
        .frame( width: 480, height: 260 )
}
