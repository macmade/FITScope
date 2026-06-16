/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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

/// The center pane: triggers the file's load + render, hosts the zoomable
/// canvas with its floating toolbar, and reports the cursor readout upward.
public struct ImageCanvasView: View
{
    /// The file to display.
    @ObservedObject private var file: OpenFile

    /// Reports the current cursor readout (or `.empty` off-image).
    public let onReadout: ( CursorReadout ) -> Void

    /// The current magnification.
    @State private var zoom:    CGFloat = 1.0

    /// The latest one-shot canvas command.
    @State private var command  = CanvasCommand( kind: .fit, token: 0 )

    /// A monotonically increasing token source for commands.
    @State private var tokens   = 0

    /// Creates the canvas view.
    public init( file: OpenFile, onReadout: @escaping ( CursorReadout ) -> Void )
    {
        self.file      = file
        self.onReadout = onReadout
    }

    /// The view's content.
    public var body: some View
    {
        ZStack
        {
            Color.black

            if let image = self.file.image
            {
                if let result = image.renderer.result
                {
                    ZoomableImageView( image: result.image, zoom: self.$zoom, command: self.command )
                    {
                        coordinate in self.report( coordinate: coordinate )
                    }
                    .overlay( alignment: .bottom )
                    {
                        ImageToolbarView(
                            zoom:       self.zoom,
                            onFit:      { self.send( .fit ) },
                            onRecenter: { self.send( .recenter ) },
                            onZoomIn:   { self.send( .zoomIn ) },
                            onZoomOut:  { self.send( .zoomOut ) }
                        )
                        .padding( .bottom, 16 )
                    }
                }
                else if let error = image.renderer.error
                {
                    ErrorView( title: "Error Rendering Image", message: error.localizedDescription )
                }
                else
                {
                    LoadingView( title: "Rendering Image..." )
                }
            }
            else if let error = self.file.error
            {
                ErrorView( title: "Error Loading FITS File", message: error.localizedDescription )
            }
            else
            {
                LoadingView( title: "Loading FITS file..." )
            }
        }
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .task( id: self.file.id )
        {
            await self.file.load()
            await self.file.image?.renderer.render()
        }
    }

    /// Issues a one-shot canvas command with a fresh token.
    private func send( _ kind: CanvasCommand.Kind )
    {
        self.tokens  += 1
        self.command  = CanvasCommand( kind: kind, token: self.tokens )
    }

    /// Decodes the value under the cursor and reports a formatted readout.
    private func report( coordinate: ( x: Int, y: Int )? )
    {
        guard let coordinate,
              let input = try? self.file.image?.renderer.renderInputSnapshot()
        else
        {
            self.onReadout( .empty )

            return
        }

        let pixel = ImageProcessor.rawPixelValue( data: input.data, properties: input.properties, x: coordinate.x, y: coordinate.y )

        self.onReadout( CursorReadout( x: coordinate.x, y: coordinate.y, value: pixel?.value, fraction: pixel?.fraction ) )
    }
}
