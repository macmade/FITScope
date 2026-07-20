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

/// A horizontal filmstrip of a file's frames, shown below the canvas when a file
/// holds more than one image, letting the user pick which frame to display.
///
/// It is format-neutral: it lists whatever ``LoadedImage`` frames the file
/// produced (a FITS cube's planes, an XISF or HEIC file's sub-images) and reports
/// the chosen index through a binding. A tap or the left/right arrow keys change
/// the selection, and the selected cell is kept scrolled into view.
public struct ImageCarouselView: View
{
    /// The frames to list, in display order.
    private let frames: [ LoadedImage ]

    /// The selected frame's index, into ``frames``.
    @Binding private var selection: Int

    /// Whether the strip currently has keyboard focus, so the arrow keys drive it.
    @FocusState private var isFocused: Bool

    /// The strip's vertical padding around the cells.
    private static let verticalPadding: CGFloat = 8

    /// Creates the carousel.
    ///
    /// - Parameters:
    ///   - frames:    The frames to list.
    ///   - selection: A binding to the selected frame's index.
    public init( frames: [ LoadedImage ], selection: Binding< Int > )
    {
        self.frames      = frames
        self._selection  = selection
    }

    /// The view's content.
    public var body: some View
    {
        ScrollViewReader
        {
            proxy in

            ScrollView( .horizontal, showsIndicators: false )
            {
                LazyHStack( spacing: 8 )
                {
                    ForEach( Array( self.frames.enumerated() ), id: \.offset )
                    {
                        index, frame in

                        ImageCarouselCellView(
                            frame:      frame,
                            label:      Self.label( title: frame.frameTitle, index: index ),
                            isSelected: index == self.selection
                        )
                        .id( index )
                        .onTapGesture
                        {
                            // Take keyboard focus too, so the arrow keys drive the
                            // strip immediately after a click.
                            self.isFocused = true
                            self.selection = index
                        }
                        .accessibilityIdentifier( AccessibilityIdentifier.ImageCarouselView.frame( index ) )
                    }
                }
                .padding( .horizontal, 12 )
                .padding( .vertical, Self.verticalPadding )
            }
            .focusable()
            .focused( self.$isFocused )
            // Keep the strip focusable for arrow-key navigation, but suppress the
            // system focus ring: on a full-width scroll view it draws as a blue
            // border spanning the whole window when the strip takes focus.
            .focusEffectDisabled()
            .onKeyPress( .leftArrow )
            {
                self.move( by: -1 )

                return .handled
            }
            .onKeyPress( .rightArrow )
            {
                self.move( by: 1 )

                return .handled
            }
            .onChange( of: self.selection )
            {
                _, index in

                withAnimation( .easeInOut( duration: 0.2 ) )
                {
                    proxy.scrollTo( index, anchor: .center )
                }
            }
        }
        .background( .ultraThinMaterial )
        .overlay( alignment: .top ) { Divider() }
        .accessibilityIdentifier( AccessibilityIdentifier.ImageCarouselView.strip )
    }

    /// Moves the selection by the given signed offset, clamped to the ends.
    ///
    /// - Parameter offset: The number of frames to move by (negative to go left).
    private func move( by offset: Int )
    {
        self.selection = Self.neighborIndex( from: self.selection, offset: offset, count: self.frames.count )
    }

    /// The display label for a frame: its title, or a 1-based frame number when it
    /// has none.
    ///
    /// - Parameters:
    ///   - title: The frame's title, or `nil`.
    ///   - index: The frame's zero-based index.
    /// - Returns: The label to show.
    nonisolated static func label( title: String?, index: Int ) -> String
    {
        title ?? "Frame \( index + 1 )"
    }

    /// The index reached by moving `offset` frames from `index`, clamped to
    /// `0 ..< count` so navigation stops at the ends rather than wrapping. Returns
    /// the starting index unchanged when there are no frames.
    ///
    /// - Parameters:
    ///   - index:  The current index.
    ///   - offset: The signed number of frames to move.
    ///   - count:  The total number of frames.
    /// - Returns: The clamped destination index.
    nonisolated static func neighborIndex( from index: Int, offset: Int, count: Int ) -> Int
    {
        guard count > 0
        else
        {
            return index
        }

        return min( max( index + offset, 0 ), count - 1 )
    }
}

#Preview
{
    @Previewable @State var selection = 0

    if let frame = PreviewHelper.image( file: .color )
    {
        ImageCarouselView( frames: [ frame, frame, frame ], selection: $selection )
            .frame( height: 96 )
            .task
            {
                await frame.renderer.render()
            }
    }
    else
    {
        Text( "Sample file unavailable." )
    }
}
