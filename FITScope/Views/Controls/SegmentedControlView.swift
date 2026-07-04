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
///
/// With ``collapsesUnselectedToIcon``, an unselected segment that has an icon
/// shows only that icon (compact), while the selected segment expands to show its
/// icon and full label — keeping a many-segment control readable when equal-width
/// titles would otherwise truncate.
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

    /// Whether an unselected segment collapses to just its icon (when it has one),
    /// with only the selected segment showing its label and expanding to fill the
    /// remaining width. Off by default, so every segment shows its label.
    private let collapsesUnselectedToIcon: Bool

    /// Creates a segmented control.
    ///
    /// - Parameters:
    ///   - selection:                 A binding to the selected value.
    ///   - values:                    The selectable values, in display order.
    ///   - title:                     The label shown for a value.
    ///   - icon:                      The SF Symbol shown before the label, or
    ///                                `nil` for none. Defaults to no icon.
    ///   - collapsesUnselectedToIcon: Whether unselected segments show only their
    ///                                icon, leaving the label to the selected one.
    ///                                Defaults to `false`.
    public init( selection: Binding< Value >, values: [ Value ], title: @escaping ( Value ) -> String, icon: @escaping ( Value ) -> String? = { _ in nil }, collapsesUnselectedToIcon: Bool = false )
    {
        self._selection                = selection
        self.values                    = values
        self.title                     = title
        self.icon                      = icon
        self.collapsesUnselectedToIcon = collapsesUnselectedToIcon
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
        .segmentedControlChrome()
    }

    /// One segment.
    ///
    /// Normally every segment fills an equal share of the width and shows its
    /// label. When ``collapsesUnselectedToIcon`` is set, an unselected segment
    /// with an icon shows only that icon at its natural width, and the selected
    /// segment expands to fill the remaining space with its icon and label.
    ///
    /// - Parameter value: The value the segment selects.
    /// - Returns: The segment button.
    @ViewBuilder
    private func segment( _ value: Value ) -> some View
    {
        let isSelected = value == self.selection
        let icon       = self.icon( value )

        // Hide the label only when collapsing an unselected segment that actually
        // has an icon to fall back to; the selected segment (and any iconless one)
        // keeps its label. The selected segment fills the leftover width; collapsed
        // ones size to their icon.
        let showsTitle = isSelected || self.collapsesUnselectedToIcon == false || icon == nil
        let fillsWidth = isSelected || self.collapsesUnselectedToIcon == false

        Button
        {
            self.selection = value
        }
        label:
        {
            HStack( spacing: 4 )
            {
                if let icon
                {
                    Image( systemName: icon )
                }

                if showsTitle
                {
                    Text( self.title( value ) )
                }
            }
            .font( .system( size: 11, weight: isSelected ? .semibold : .regular ) )
            .foregroundStyle( isSelected ? Color.primary : Color.secondary )
            .lineLimit( 1 )
            .truncationMode( .tail )
            .frame( maxWidth: fillsWidth ? .infinity : nil )
            .padding( .vertical, 3 )
            .padding( .horizontal, showsTitle ? 0 : 8 )
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

#Preview( "Labels" )
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

#Preview( "Collapsed to icons" )
{
    struct Wrapper: View
    {
        @State private var selection = "Sun"

        private func icon( _ value: String ) -> String?
        {
            switch value
            {
                case "Info":    return "info.circle"
                case "Moon":    return "moon"
                case "Sun":     return "sun.horizon"
                case "Planets": return "circles.hexagonpath"
                default:        return "cloud.sun"
            }
        }

        var body: some View
        {
            SegmentedControlView( selection: self.$selection, values: [ "Info", "Moon", "Sun", "Planets", "Weather" ], title: { $0 }, icon: self.icon, collapsesUnselectedToIcon: true )
                .padding()
                .frame( width: 255 )
        }
    }

    return Wrapper()
}
