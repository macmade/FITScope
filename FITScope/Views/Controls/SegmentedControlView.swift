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

import AppKit
import SwiftUI

/// A single-selection segmented control whose segments expand to share the full
/// available width.
///
/// The macOS system segmented `Picker` sizes itself to its content and does not
/// stretch its segments, so this draws its own equal-width segments over a
/// rounded track to fill the inspector width.
public struct SegmentedControlView< Value: Hashable >: View
{
    /// The currently selected value.
    @Binding private var selection: Value

    /// The selectable values, in display order.
    private let values: [ Value ]

    /// The label shown for a value.
    private let title: ( Value ) -> String

    /// The SF Symbol shown before the label for a value, or `nil` for no icon.
    /// Evaluated on each render, so it may vary with state (e.g. a live icon).
    private let icon: ( Value ) -> String?

    /// Creates a segmented control.
    ///
    /// - Parameters:
    ///   - selection: A binding to the selected value.
    ///   - values:    The selectable values, in display order.
    ///   - title:     The label shown for a value.
    ///   - icon:      The SF Symbol shown before the label, or `nil` for none.
    ///                Defaults to no icon.
    public init( selection: Binding< Value >, values: [ Value ], title: @escaping ( Value ) -> String, icon: @escaping ( Value ) -> String? = { _ in nil } )
    {
        self._selection = selection
        self.values     = values
        self.title      = title
        self.icon       = icon
    }

    /// The view's content.
    public var body: some View
    {
        HStack( spacing: 2 )
        {
            ForEach( self.values, id: \.self )
            {
                value in self.segment( value )
            }
        }
        .padding( 2 )
        .background( .quinary, in: RoundedRectangle( cornerRadius: 7 ) )
        .overlay( RoundedRectangle( cornerRadius: 7 ).strokeBorder( .quaternary, lineWidth: 0.5 ) )
    }

    /// One equal-width segment.
    ///
    /// - Parameter value: The value the segment selects.
    /// - Returns: The segment button.
    @ViewBuilder
    private func segment( _ value: Value ) -> some View
    {
        let isSelected = value == self.selection

        Button
        {
            self.selection = value
        }
        label:
        {
            HStack( spacing: 4 )
            {
                if let icon = self.icon( value )
                {
                    Image( systemName: icon )
                }

                Text( self.title( value ) )
            }
            .font( .system( size: 11, weight: isSelected ? .semibold : .regular ) )
            .foregroundStyle( isSelected ? Color.primary : Color.secondary )
            .lineLimit( 1 )
            .truncationMode( .tail )
            .frame( maxWidth: .infinity )
            .padding( .vertical, 3 )
            .contentShape( Rectangle() )
            .background
            {
                if isSelected
                {
                    RoundedRectangle( cornerRadius: 5 ).fill( Color( nsColor: .controlColor ) )
                }
            }
        }
        .buttonStyle( .plain )
    }
}

#Preview
{
    struct Wrapper: View
    {
        @State private var selection = "RGB"

        var body: some View
        {
            SegmentedControlView( selection: self.$selection, values: [ "RGB", "Luminance" ], title: { $0 } )
                .padding()
                .frame( width: 255 )
        }
    }

    return Wrapper()
}
