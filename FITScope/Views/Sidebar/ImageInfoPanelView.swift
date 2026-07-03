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

/// The sidebar's bottom panel: the selected file's Image Information grid and a
/// button that opens the full FITS headers window.
public struct ImageInfoPanelView: View
{
    /// The file whose information is shown.
    @ObservedObject private var file: OpenFile

    /// The shared preferences, whose ``Preferences/infoPanelFields`` selects and
    /// orders the fields shown here.
    @EnvironmentObject private var preferences: Preferences

    /// Opens the auxiliary headers window.
    @Environment( \.openWindow ) private var openWindow

    /// Creates the panel.
    ///
    /// - Parameter file: The file to describe.
    public init( file: OpenFile )
    {
        self.file = file
    }

    /// The view's content.
    public var body: some View
    {
        VStack( alignment: .leading, spacing: 10 )
        {
            Text( "IMAGE INFORMATION" )
                .font( .system( size: 10, weight: .semibold ) )
                .foregroundStyle( .secondary )
                .kerning( 1.2 )

            if let info = self.file.image?.info, let summary = ImageInformation( info: info )
            {
                Grid( alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3 )
                {
                    ForEach( summary.rows( for: self.visibleFields, additionalValues: self.computedValues ), id: \.field )
                    {
                        row in self.row( row )
                    }
                }
                // Let the field labels and values be selected and copied. Applied
                // to the grid so every row's text is selectable at once; it
                // coexists with each value's single-line truncation and tooltip.
                .textSelection( .enabled )

                // Given more height than the content needs (few fields), this
                // keeps the fields at the top and pushes the button to the bottom;
                // with many fields it collapses and the button follows the grid.
                Spacer( minLength: 0 )

                Button( "View Full FITS Headers" )
                {
                    self.openWindow( id: "InfoWindow", value: info )
                }
                .frame( maxWidth: .infinity )
                .accessibilityIdentifier( AccessibilityIdentifier.ImageInfoPanelView.viewHeadersButton )
            }
            else
            {
                Text( "No information available." )
                    .font( .system( size: 10 ) )
                    .foregroundStyle( .tertiary )

                Spacer( minLength: 0 )
            }
        }
        .padding( 14 )
        .frame( maxWidth: .infinity, alignment: .leading )
    }

    /// The fields the user wants shown, in their chosen order.
    private var visibleFields: [ InfoField ]
    {
        self.preferences.infoPanelFields.filter { $0.isVisible }.map { $0.field }
    }

    /// Values not derived from the header — the computed per-image weight, ranked
    /// against the other open files — keyed by their field. Empty when no weight
    /// is available, so the row is then omitted.
    private var computedValues: [ InfoField: String ]
    {
        self.file.formattedWeight.map { [ .weight: $0 ] } ?? [ : ]
    }

    /// An icon + label / value grid row.
    private func row( _ row: ImageInformation.Row ) -> some View
    {
        GridRow
        {
            HStack( spacing: 5 )
            {
                Image( systemName: row.systemImageName )
                    .foregroundStyle( .secondary )
                    .frame( width: 12 )

                Text( row.label )
                    .foregroundStyle( .secondary )
            }

            // Keep long values on a single line, truncated with a trailing
            // ellipsis, and surface the full value in a tooltip on hover — rather
            // than wrapping onto several lines and growing the panel. The flexible
            // frame lets the value fill the remaining width so it truncates there
            // instead of being clipped at the panel's edge.
            Text( row.value )
                .lineLimit( 1 )
                .truncationMode( .tail )
                .frame( maxWidth: .infinity, alignment: .leading )
                .help( row.value )
        }
        .font( .system( size: 10 ) )
    }
}
