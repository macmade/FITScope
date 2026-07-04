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

    /// Whether the section deviates from its defaults, so its header reset button
    /// should be shown. Ignored when ``onReset`` is `nil`.
    public let isModified: Bool

    /// The accessibility identifier for the header reset button, or `nil`.
    public let resetIdentifier: String?

    /// Resets the section to its defaults, or `nil` for a section with no reset
    /// affordance (the default).
    public let onReset: ( () -> Void )?

    /// The section's content.
    @ViewBuilder public let content: Content

    /// Creates a section.
    ///
    /// - Parameters:
    ///   - title:           The uppercase header text.
    ///   - identifier:      A stable accessibility identifier for the section, or
    ///                      `nil` to leave it unidentified.
    ///   - isModified:      Whether the section deviates from its defaults, so its
    ///                      reset button should show. Ignored when `onReset` is nil.
    ///   - resetIdentifier: The reset button's accessibility identifier, or `nil`.
    ///   - onReset:         Resets the section to its defaults, or `nil` for no
    ///                      reset affordance.
    ///   - content:         The section body.
    public init( _ title: String, identifier: String? = nil, isModified: Bool = false, resetIdentifier: String? = nil, onReset: ( () -> Void )? = nil, @ViewBuilder content: () -> Content )
    {
        self.title           = title
        self.identifier      = identifier
        self.isModified      = isModified
        self.resetIdentifier = resetIdentifier
        self.onReset         = onReset
        self.content         = content()
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
            self.header

            self.content
        }
        .frame( maxWidth: .infinity, alignment: .leading )
        .padding( .horizontal, 14 )
        .padding( .vertical, 12 )
    }

    /// The section header: the uppercase title and, when the section is modified
    /// and resettable, a trailing reset button.
    @ViewBuilder private var header: some View
    {
        HStack( spacing: 6 )
        {
            Text( self.title.uppercased() )
                .font( .system( size: 10, weight: .semibold ) )
                .foregroundStyle( .secondary )
                .kerning( 1.2 )

            if let onReset = self.onReset, self.isModified
            {
                Spacer()

                self.resetButton( onReset: onReset )
            }
        }
        .frame( maxWidth: .infinity, alignment: .leading )
    }

    /// The header reset button, carrying ``resetIdentifier`` when one was supplied.
    @ViewBuilder
    private func resetButton( onReset: @escaping () -> Void ) -> some View
    {
        let button = ResetButton( help: "Reset This Section", action: onReset )

        if let resetIdentifier = self.resetIdentifier
        {
            button.accessibilityIdentifier( resetIdentifier )
        }
        else
        {
            button
        }
    }
}

#Preview
{
    VStack( spacing: 0 )
    {
        // A plain section, no reset affordance.
        InspectorSectionView( "Statistics" )
        {
            Text( "Section content" )
        }

        Divider()

        // A modified, resettable section: the header shows its reset button.
        InspectorSectionView( "White Balance", isModified: true, onReset: {} )
        {
            Text( "Section content" )
        }
    }
    .frame( width: 255 )
}
