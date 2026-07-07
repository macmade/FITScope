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

/// A single frame in the ``ImageCarouselView`` filmstrip: the frame's thumbnail
/// with its label beneath, highlighted when selected.
///
/// The frame is observed so the thumbnail appears (or refreshes) as soon as the
/// frame renders — a not-yet-rendered frame shows a progress placeholder, and a
/// frame that failed to render shows a warning glyph.
public struct ImageCarouselCellView: View
{
    /// The frame this cell represents, observed so the thumbnail tracks its render.
    @ObservedObject private var frame: LoadedImage

    /// The frame's display label.
    private let label: String

    /// Whether this frame is the selected one, driving the highlight.
    private let isSelected: Bool

    /// The side length of the square thumbnail.
    private static let thumbnailSize: CGFloat = 56

    /// The thumbnail's corner radius.
    private static let cornerRadius: CGFloat = 6

    /// Creates a carousel cell.
    ///
    /// - Parameters:
    ///   - frame:      The frame to represent.
    ///   - label:      The frame's display label.
    ///   - isSelected: Whether the frame is selected.
    public init( frame: LoadedImage, label: String, isSelected: Bool )
    {
        self.frame      = frame
        self.label      = label
        self.isSelected = isSelected
    }

    /// The view's content.
    public var body: some View
    {
        VStack( spacing: 4 )
        {
            self.thumbnail
                .frame( width: Self.thumbnailSize, height: Self.thumbnailSize )
                .clipShape( RoundedRectangle( cornerRadius: Self.cornerRadius ) )
                .overlay
                {
                    RoundedRectangle( cornerRadius: Self.cornerRadius )
                        .stroke( self.isSelected ? Color.accentColor : Color.white.opacity( 0.15 ), lineWidth: self.isSelected ? 2 : 1 )
                }

            Text( self.label )
                .font( .caption2 )
                .lineLimit( 1 )
                .truncationMode( .middle )
                .foregroundStyle( self.isSelected ? AnyShapeStyle( .primary ) : AnyShapeStyle( .secondary ) )
                .frame( maxWidth: Self.thumbnailSize )
        }
        .contentShape( Rectangle() )
    }

    /// The frame's thumbnail: its rendered image once available, a warning glyph on
    /// a render failure, a spinner while it is actively rendering, or a neutral
    /// image glyph for a frame not yet prepared (frames are rendered lazily, the
    /// first time they are selected).
    @ViewBuilder     private var thumbnail: some View
    {
        if let image = self.frame.renderer.result?.image
        {
            Image( decorative: image, scale: 1, orientation: .up )
                .resizable()
                .aspectRatio( contentMode: .fill )
        }
        else if self.frame.renderer.error != nil
        {
            self.placeholder
            {
                Image( systemName: "exclamationmark.triangle" )
                    .foregroundStyle( .secondary )
            }
        }
        else if self.frame.renderer.isRendering
        {
            self.placeholder
            {
                ProgressView().controlSize( .small )
            }
        }
        else
        {
            self.placeholder
            {
                Image( systemName: "photo" )
                    .foregroundStyle( .secondary )
            }
        }
    }

    /// A neutral placeholder tile hosting the given content, used while a frame has
    /// no rendered image to show.
    ///
    /// - Parameter content: The glyph or indicator to centre in the tile.
    /// - Returns: The placeholder view.
    @ViewBuilder
    private func placeholder( @ViewBuilder _ content: () -> some View ) -> some View
    {
        ZStack
        {
            Color.black.opacity( 0.35 )
            content()
        }
    }
}

#Preview
{
    if let frame = PreviewHelper.image( file: .M42 )
    {
        HStack( spacing: 8 )
        {
            ImageCarouselCellView( frame: frame, label: "Frame 1", isSelected: true )
            ImageCarouselCellView( frame: frame, label: "Hα", isSelected: false )
        }
        .padding()
        .background( .black )
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
