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

/// A centred icon-and-text placeholder filling its container over an opaque
/// material — shown in the Map tab when there is nothing to map: no GPS
/// coordinates, or a map that failed to load (an error or no connection).
public struct MapStatusView: View
{
    /// The SF Symbol shown above the title.
    private let systemImage: String

    /// The bold one-line headline.
    private let title: String

    /// An optional secondary line below the title.
    private let message: String?

    /// Creates a status placeholder.
    ///
    /// - Parameters:
    ///   - systemImage: The SF Symbol shown above the title.
    ///   - title:       The bold one-line headline.
    ///   - message:     An optional secondary line below the title.
    public init( systemImage: String, title: String, message: String? = nil )
    {
        self.systemImage = systemImage
        self.title       = title
        self.message     = message
    }

    /// The view's content.
    public var body: some View
    {
        VStack( spacing: 6 )
        {
            Image( systemName: self.systemImage )
                .font( .title2 )
                .foregroundStyle( .secondary )

            Text( self.title )
                .font( .system( size: 11, weight: .semibold ) )

            if let message = self.message
            {
                Text( message )
                    .font( .system( size: 10 ) )
                    .foregroundStyle( .secondary )
                    .multilineTextAlignment( .center )
            }
        }
        .padding( 12 )
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .background( .regularMaterial )
    }
}

#Preview
{
    MapStatusView( systemImage: "location.slash", title: "No Location Data", message: "This image has no GPS coordinates." )
        .frame( width: 260, height: 200 )
}
