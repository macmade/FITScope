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

import SwiftPixel
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

    /// The shared user preferences; drives whether the floating bars auto-hide.
    @EnvironmentObject private var preferences: Preferences

    /// App-wide coordination, used to start and track the plate solve.
    @EnvironmentObject private var appModel: AppModel

    /// The API-key store, read for the Astrometry.net key when plate solving.
    @EnvironmentObject private var apiKeyStore: APIKeyStore

    /// Opens the plate-solving results window.
    @Environment( \.openWindow ) private var openWindow

    /// The current magnification.
    @State private var zoom: CGFloat = 1.0

    /// Whether zoom-out is available; `false` once the whole image is visible.
    @State private var canZoomOut = true

    /// The latest one-shot canvas command.
    @State private var command = CanvasCommand( kind: .fit, token: 0 )

    /// A monotonically increasing token source for commands.
    @State private var tokens = 0

    /// The latest cursor readout, shown in the status pill.
    @State private var readout = CursorReadout.empty

    /// The on-screen rectangle the displayed image currently occupies, reported
    /// by the canvas and used to register overlays to image space.
    @State private var displayedImageRect = CGRect.zero

    /// The identifiers of the overlays the user has turned on for this file.
    @State private var enabledOverlays = Set< String >()

    /// Whether the alert proposing a plate solve is shown. Raised when the
    /// always-offered objects toggle is tapped with no plate-solved objects to
    /// reveal.
    @State private var isObjectsPlateSolvePromptPresented = false

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
        // The black background drives the pane's size and fills it; the
        // state-dependent content is layered on top as an overlay so a
        // placeholder's minimum width (``LoadingView`` / ``ErrorView``) can never
        // widen the detail column and push the split-view sidebars off-window.
        Color.black
            .frame( maxWidth: .infinity, maxHeight: .infinity )
            .overlay
            {
                self.canvasContent
            }
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
            .onChange( of: self.preferences.autoHideFloatingBars )
            {
                _, autoHide in

                if autoHide
                {
                    // Re-enabled: start the countdown so the bars fade as usual.
                    self.scheduleHide()
                }
                else
                {
                    // Disabled: cancel any pending hide and reveal the bars to stay.
                    self.cancelHide()

                    withAnimation( .easeInOut( duration: 0.2 ) )
                    {
                        self.barsVisible = true
                    }
                }
            }
            .task( id: self.file.id )
            {
                // The file loads and renders itself in a model-owned task (see
                // `OpenFile.prepare`); the canvas only observes the result. Reset
                // the per-file view state on a fresh run-loop turn: the task body
                // runs within SwiftUI's update pass, and writing this @State
                // synchronously there is reported as "publishing changes from
                // within view updates".
                DispatchQueue.main.async
                {
                    self.readout         = .empty
                    self.enabledOverlays = []

                    self.revealBars()
                }
            }
            .alert( "Identify Objects", isPresented: self.$isObjectsPlateSolvePromptPresented )
            {
                Button( "Plate Solve…" ) { self.plateSolve() }
                Button( "Cancel", role: .cancel ) {}
            }
            message:
            {
                Text( self.objectsPlateSolvePromptMessage )
            }
    }

    /// The state-dependent canvas content: the zoomable image with its floating
    /// bars once rendered, an error view on failure, or a loading placeholder
    /// while loading or rendering. Hosted as an overlay over the black canvas, so
    /// its size never feeds back into the split-view column layout.
    @ViewBuilder     private var canvasContent: some View
    {
        if let image = self.file.image
        {
            if let result = image.renderer.result
            {
                ZoomableImageView(
                    image:                      result.image,
                    command:                    self.command,
                    onHover:                    { coordinate in self.report( coordinate: coordinate ) },
                    onZoomChange:               { self.zoom = $0 },
                    onCanZoomOutChange:         { self.canZoomOut = $0 },
                    onDisplayedImageRectChange: { self.displayedImageRect = $0 }
                )
                .accessibilityIdentifier( AccessibilityIdentifier.ImageCanvasView.canvas )
                .overlay
                {
                    // The annotation overlays, registered to image space through
                    // the reported displayed-image rectangle. Hit-test transparent,
                    // so the cursor read-out and panning underneath keep working.
                    CanvasOverlayLayer( overlays: self.activeOverlays, imageSize: CGSize( width: result.image.width, height: result.image.height ), displayedRect: self.displayedImageRect )
                }
                .overlay
                {
                    // Dim the retained image and spin while a re-render is in
                    // flight. Layered beneath the floating bars (added after) and
                    // non-interactive, so hovering still reveals the bars and the
                    // status pill — which reads "Processing…" — stays legible.
                    if image.renderer.isRendering
                    {
                        ZStack
                        {
                            Color.black.opacity( 0.3 )
                            ProgressView().controlSize( .large )
                        }
                        .allowsHitTesting( false )
                    }
                }
                .overlay( alignment: .top )
                {
                    self.floatingBar
                    {
                        ImageToolbarView(
                            zoom:             self.zoom,
                            canZoomOut:       self.canZoomOut,
                            onFit:            { self.send( .fit ) },
                            onActualSize:     { self.send( .actualSize ) },
                            onRecenter:       { self.send( .recenter ) },
                            onZoomIn:         { self.send( .zoomIn ) },
                            onZoomOut:        { self.send( .zoomOut ) },
                            onPlateSolve:     { self.plateSolve() },
                            isPlateSolved:    self.file.plateSolve != nil,
                            isPlateSolving:   self.file.isPlateSolving,
                            overlays:         self.toolbarOverlays,
                            isOverlayEnabled: { self.enabledOverlays.contains( $0 ) },
                            onToggleOverlay:  { self.toggleOverlay( $0 ) }
                        )
                        .padding( .top, 16 )
                    }
                }
                .overlay( alignment: .bottom )
                {
                    self.floatingBar
                    {
                        StatusBarView( status: image.renderer.isRendering ? "Processing…" : "Ready", readout: self.readout, dimensions: self.dimensionsSummary )
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

    /// Starts (or restarts) the auto-hide countdown, unless auto-hide is turned
    /// off in preferences or the cursor is resting over a bar — in either case
    /// the bars stay visible.
    private func scheduleHide()
    {
        self.hideTask?.cancel()
        self.hideTask = nil

        guard self.preferences.autoHideFloatingBars, self.isHoveringBar == false
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

    /// The overlays applicable to the current image, in toolbar (back-to-front)
    /// order. The frame overlay is always present; data-driven overlays gate
    /// themselves through ``CanvasOverlay/isAvailable`` — the stars overlay is
    /// offered only once detection has populated ``FITSImage/starField``.
    private var overlays: [ any CanvasOverlay ]
    {
        [
            FrameOverlay(),
            // The orientation comes from the committed render result, not the live
            // adjustment, so the markers reorient together with the image rather
            // than jumping ahead while a rotation is still rendering. `isLoading`
            // surfaces detection progress through the overlay, so the toolbar shows
            // it generically without knowing about star detection.
            StarsOverlay( stars: self.file.image?.starField?.stars ?? [], orientation: self.file.image?.renderer.result?.orientation ?? .identity, isLoading: self.file.image?.isDetectingStars ?? false ),
            // The plate-solved objects, registered to image space through the same
            // committed-render orientation as the stars, so the labels track the
            // image under rotate/flip. Available only once a solve has identified
            // objects (``ObjectsOverlay/isAvailable``).
            ObjectsOverlay( annotations: self.file.plateSolve?.annotations ?? [], orientation: self.file.image?.renderer.result?.orientation ?? .identity ),
        ]
    }

    /// The overlays surfaced in the toolbar: those with something to show, plus
    /// those still computing their data (shown as an in-progress button). The
    /// objects overlay is always offered, even with nothing to show — its toggle
    /// then proposes a plate solve rather than revealing an empty layer.
    private var toolbarOverlays: [ any CanvasOverlay ]
    {
        self.overlays.filter { $0.isAvailable || $0.isLoading || $0.id == ObjectsOverlay.identifier }
    }

    /// The available overlays the user has enabled, drawn back-to-front. A loading
    /// overlay has no data yet, so it is never drawn.
    private var activeOverlays: [ any CanvasOverlay ]
    {
        self.overlays.filter { $0.isAvailable && self.enabledOverlays.contains( $0.id ) }
    }

    /// Toggles an overlay on or off by identifier.
    ///
    /// The always-offered objects toggle is special: with no plate-solved objects
    /// to reveal it proposes a plate solve instead of switching on an empty layer.
    private func toggleOverlay( _ id: String )
    {
        if id == ObjectsOverlay.identifier, self.file.plateSolve?.annotations.isEmpty ?? true
        {
            self.isObjectsPlateSolvePromptPresented = true

            return
        }

        if self.enabledOverlays.contains( id )
        {
            self.enabledOverlays.remove( id )
        }
        else
        {
            self.enabledOverlays.insert( id )
        }
    }

    /// The message for the plate-solve prompt, tailored to whether the image has
    /// been solved (but yielded no objects) or has not been solved at all.
    private var objectsPlateSolvePromptMessage: String
    {
        self.file.plateSolve == nil
            ? "This image hasn’t been plate-solved yet. Plate solve it to identify and label the objects in its field."
            : "No catalogue objects were identified in this field. You can run the plate solve again from the results window."
    }

    /// Starts (or re-opens) a plate solve for the displayed file and shows the
    /// results window, via the app model's shared entry point.
    private func plateSolve()
    {
        self.appModel.presentPlateSolve( for: self.file, apiKey: self.apiKeyStore.astrometryNetKey, openWindow: self.openWindow )
    }

    /// Issues a one-shot canvas command with a fresh token.
    private func send( _ kind: CanvasCommand.Kind )
    {
        self.tokens  += 1
        self.command  = CanvasCommand( kind: kind, token: self.tokens )
    }

    /// Decodes the value under the cursor and reports a formatted readout.
    ///
    /// The cursor coordinate comes from the *displayed* image, which a rotation
    /// or flip may have reoriented relative to the source data. It is mapped
    /// back to the source pixel so both the reported coordinate and its value
    /// refer to the same sample in the FITS file.
    private func report( coordinate: ( x: Int, y: Int )? )
    {
        guard let coordinate,
              let renderer = self.file.image?.renderer,
              let input    = try? renderer.renderInputSnapshot()
        else
        {
            self.readout = .empty

            return
        }

        let orientation = renderer.adjustments.orientation
        let source:        ( x: Int, y: Int )

        if orientation.isIdentity == false, let size = ImageProcessor.imageDimensions( from: input.properties )
        {
            source = orientation.sourceCoordinate( displayX: coordinate.x, displayY: coordinate.y, sourceWidth: size.width, sourceHeight: size.height )
        }
        else
        {
            source = coordinate
        }

        let pixel = ImageProcessor.rawPixelValue( data: input.data, properties: input.properties, x: source.x, y: source.y )

        self.readout = CursorReadout( x: source.x, y: source.y, value: pixel?.value, fraction: pixel?.fraction )
    }
}
