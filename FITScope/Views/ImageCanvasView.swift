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

/// The center pane: triggers the file's load + render, and hosts the zoomable
/// canvas with its floating zoom toolbar (top) and status pill (bottom). Both
/// bars auto-hide after a delay of cursor inactivity and reappear on movement.
public struct ImageCanvasView: View
{
    /// How long the floating bars stay visible after the last cursor movement.
    private static let autoHideDelay = Duration.seconds( 2 )

    /// The file to display.
    @ObservedObject private var file: OpenFile

    /// The current magnification.
    @State private var zoom:    CGFloat = 1.0

    /// The latest one-shot canvas command.
    @State private var command  = CanvasCommand( kind: .fit, token: 0 )

    /// A monotonically increasing token source for commands.
    @State private var tokens   = 0

    /// The latest cursor readout, shown in the status pill.
    @State private var readout  = CursorReadout.empty

    /// Whether the floating bars are currently shown.
    @State private var barsVisible = true

    /// Whether the cursor is currently resting over one of the floating bars,
    /// which suppresses the auto-hide so a bar never vanishes under the pointer.
    @State private var isHoveringBar = false

    /// The pending auto-hide work, cancelled whenever the bars are revealed or
    /// the cursor rests over a bar.
    @State private var hideTask: Task< Void, Never >?

    /// Creates the canvas view.
    public init( file: OpenFile )
    {
        self.file = file
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
                    .accessibilityIdentifier( AccessibilityIdentifier.ImageCanvasView.canvas )
                    .overlay( alignment: .top )
                    {
                        self.floatingBar
                        {
                            ImageToolbarView(
                                zoom:         self.zoom,
                                onFit:        { self.send( .fit ) },
                                onActualSize: { self.send( .actualSize ) },
                                onRecenter:   { self.send( .recenter ) },
                                onZoomIn:     { self.send( .zoomIn ) },
                                onZoomOut:    { self.send( .zoomOut ) }
                            )
                            .padding( .top, 16 )
                        }
                    }
                    .overlay( alignment: .bottom )
                    {
                        self.floatingBar
                        {
                            StatusBarView( status: "Ready", readout: self.readout, dimensions: self.dimensionsSummary )
                                .padding( .bottom, 16 )
                        }
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
        .onContinuousHover
        {
            phase in

            switch phase
            {
                case .active: self.revealBars()
                case .ended:  break
                @unknown default: break
            }
        }
        .task( id: self.file.id )
        {
            self.readout = .empty

            await self.file.load()
            await self.file.image?.renderer.render()
            await self.file.makeThumbnail( maxDimension: 64 )

            self.revealBars()
        }
    }

    /// Wraps a floating bar with the shared show / hide behavior: it fades with
    /// ``barsVisible``, stays out of hit-testing while hidden, and keeps itself
    /// visible while the cursor rests directly over it.
    @ViewBuilder
    private func floatingBar( @ViewBuilder _ content: () -> some View ) -> some View
    {
        content()
            .opacity( self.barsVisible ? 1 : 0 )
            .allowsHitTesting( self.barsVisible )
            .onHover
            {
                hovering in

                self.isHoveringBar = hovering

                if hovering
                {
                    self.cancelHide()
                }
                else
                {
                    self.scheduleHide()
                }
            }
    }

    /// Reveals the floating bars and restarts the auto-hide countdown.
    private func revealBars()
    {
        withAnimation( .easeInOut( duration: 0.2 ) )
        {
            self.barsVisible = true
        }

        self.scheduleHide()
    }

    /// Starts (or restarts) the auto-hide countdown, unless the cursor is
    /// resting over a bar, in which case the bars stay visible.
    private func scheduleHide()
    {
        self.hideTask?.cancel()
        self.hideTask = nil

        guard self.isHoveringBar == false
        else
        {
            return
        }

        self.hideTask = Task
        {
            try? await Task.sleep( for: Self.autoHideDelay )

            guard Task.isCancelled == false
            else
            {
                return
            }

            withAnimation( .easeInOut( duration: 0.2 ) )
            {
                self.barsVisible = false
            }
        }
    }

    /// Cancels the auto-hide countdown, keeping the bars visible.
    private func cancelHide()
    {
        self.hideTask?.cancel()
        self.hideTask = nil
    }

    /// The dimensions / bit-depth summary for the file, or `nil` when no image
    /// is loaded.
    private var dimensionsSummary: String?
    {
        guard let info = self.file.image?.info,
              let summary = ImageInformation( info: info )
        else
        {
            return nil
        }

        return "\( summary.dimensions ) • \( summary.bitDepth )"
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
            self.readout = .empty

            return
        }

        let pixel = ImageProcessor.rawPixelValue( data: input.data, properties: input.properties, x: coordinate.x, y: coordinate.y )

        self.readout = CursorReadout( x: coordinate.x, y: coordinate.y, value: pixel?.value, fraction: pixel?.fraction )
    }
}
