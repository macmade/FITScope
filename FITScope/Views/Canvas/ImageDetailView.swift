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

/// The detail region for the selected file: the image canvas, with the
/// multi-frame carousel beneath it when the file holds more than one frame.
///
/// The file is observed here so the region reacts to its frames appearing and to
/// the carousel selection: a single-frame file shows the canvas exactly as before
/// (no carousel), while a multi-frame file gains the filmstrip and drives the
/// canvas from the chosen frame.
public struct ImageDetailView: View
{
    /// The file whose selected frame the canvas shows.
    @ObservedObject private var file: OpenFile

    /// The shared file actions, applied as the canvas's context menu.
    private let actions: FileActions

    /// The height reserved for the carousel filmstrip.
    private static let carouselHeight: CGFloat = 96

    /// Creates the detail region.
    ///
    /// - Parameters:
    ///   - file:    The file to display.
    ///   - actions: The file actions for the canvas context menu.
    public init( file: OpenFile, actions: FileActions )
    {
        self.file    = file
        self.actions = actions
    }

    /// The view's content: the one-dimensional graph for a `NAXIS=1` file, otherwise
    /// the image canvas with the multi-frame carousel beneath it when the file holds
    /// more than one frame.
    @ViewBuilder     public var body: some View
    {
        if let graph = self.file.image?.graph
        {
            GraphView( series: graph )
                .fileContextMenu( for: self.file, actions: self.actions )
        }
        else
        {
            VStack( spacing: 0 )
            {
                ImageCanvasView( file: self.file )
                    .fileContextMenu( for: self.file, actions: self.actions )

                if self.file.frames.count > 1
                {
                    ImageCarouselView( frames: self.file.frames, selection: self.frameSelection )
                        .frame( height: Self.carouselHeight )
                }
            }
        }
    }

    /// A binding that reads the file's selected frame and routes a change through
    /// ``OpenFile/selectFrame(_:)`` so the newly shown frame is prepared on demand.
    private var frameSelection: Binding< Int >
    {
        Binding(
            get: { self.file.selectedFrameIndex },
            set: { self.file.selectFrame( $0 ) }
        )
    }
}

#Preview
{
    if let file = PreviewHelper.openFile( file: .color )
    {
        let actions = FileActions( appModel: AppModel(), model: WindowModel(), preferences: Preferences() )

        ImageDetailView( file: file, actions: actions )
            .task
            {
                await file.load()
                await file.image?.renderer.render()
            }
    }
    else
    {
        Text( "Sample file unavailable." )
    }
}
