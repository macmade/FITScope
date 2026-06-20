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

/// A titled inspector section: an uppercase, tracked header above arbitrary
/// content, with consistent padding and a divider.
public struct InspectorSectionView< Content: View >: View
{
    /// The section's uppercase title.
    public let title: String

    /// A stable accessibility identifier for the section, or `nil` to leave it
    /// unidentified. Passed explicitly by the call site rather than derived from
    /// ``title``, so the identifier never changes when the heading does.
    public let identifier: String?

    /// The section's content.
    @ViewBuilder public let content: Content

    /// Creates a section.
    ///
    /// - Parameters:
    ///   - title:      The uppercase header text.
    ///   - identifier: A stable accessibility identifier for the section, or
    ///                 `nil` to leave it unidentified.
    ///   - content:    The section body.
    public init( _ title: String, identifier: String? = nil, @ViewBuilder content: () -> Content )
    {
        self.title      = title
        self.identifier = identifier
        self.content    = content()
    }

    /// The view's content.
    public var body: some View
    {
        if let identifier = self.identifier
        {
            self.sectionContent
                .accessibilityElement( children: .contain )
                .accessibilityIdentifier( identifier )
        }
        else
        {
            self.sectionContent
        }
    }

    /// The styled section, before any accessibility grouping is applied.
    private var sectionContent: some View
    {
        VStack( alignment: .leading, spacing: 8 )
        {
            Text( self.title.uppercased() )
                .font( .system( size: 10, weight: .semibold ) )
                .foregroundStyle( .secondary )
                .kerning( 1.2 )

            self.content
        }
        .frame( maxWidth: .infinity, alignment: .leading )
        .padding( .horizontal, 14 )
        .padding( .vertical, 12 )
    }
}

#Preview
{
    InspectorSectionView( "Statistics" )
    {
        Text( "Section content" )
    }
    .frame( width: 255 )
}
