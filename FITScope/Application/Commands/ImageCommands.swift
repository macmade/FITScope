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

/// The app's *Image* menu commands: the same zoom, overlay and plate-solve
/// actions the floating ``ImageToolbarView`` offers, so they are discoverable and
/// keyboard-accessible from the menu bar too.
///
/// The zoom and overlay actions drive the frontmost window's ``ImageCanvasController``,
/// and the plate-solve action targets its selected ``OpenFile`` — both published as
/// the scene's focused objects (see ``ImageCanvasView`` and ``MainWindowView``), so
/// every item follows the key window and disables itself when no image is shown,
/// mirroring ``FileCommands``. The overlay items call the same tap handler the
/// toolbar does, so a toggle on an overlay with no data behaves identically (it
/// explains itself or proposes a plate solve) from either place.
struct ImageCommands: View
{
    /// The frontmost window's selected file, or `nil` when none.
    @FocusedObject private var file: OpenFile?

    /// The frontmost window's canvas controller, or `nil` when no image is shown.
    /// Observed, so the menu re-validates as zoom and overlay state change.
    @FocusedObject private var canvas: ImageCanvasController?

    /// Opens the plate-solving results window.
    @Environment( \.openWindow ) private var openWindow

    /// App-wide coordination, used to start and track the solve.
    private let appModel: AppModel

    /// The API-key store, read for the Astrometry.net key.
    private let apiKeyStore: APIKeyStore

    /// Creates the Image-menu commands.
    ///
    /// - Parameters:
    ///   - appModel:    The shared coordination object.
    ///   - apiKeyStore: The API-key store.
    init( appModel: AppModel, apiKeyStore: APIKeyStore )
    {
        self.appModel    = appModel
        self.apiKeyStore = apiKeyStore
    }

    /// Whether the frontmost window has a loaded *raster* image, gating the
    /// pixel-oriented items (orientation, invert, reset, the editors, compare, plate
    /// solve). A one-dimensional graph file (`NAXIS=1`) has a loaded image but no
    /// pixels, so those items disable for it. The metadata window is gated separately
    /// on metadata, which a graph does have.
    private var hasImage: Bool
    {
        guard let image = self.file?.image
        else
        {
            return false
        }

        return image.graph == nil
    }

    /// The *Image* menu, as an ordered outline: zoom, the before/after compare
    /// toggle, overlay toggles, orientation, invert / reset, the Levels and Curves
    /// editors, the metadata window, session metrics, then plate solving. Each
    /// item is built by its own method, and each carries the same SF Symbol as its
    /// toolbar / inspector button so the menu reads as the same actions elsewhere.
    var body: some View
    {
        self.zoomInButton()
        self.zoomOutButton()
        self.actualSizeButton()
        self.fitButton()
        self.recenterButton()

        Divider()

        self.compareToggle()
        self.overlayToggles()

        Divider()

        self.rotateLeftButton()
        self.rotateRightButton()
        self.flipHorizontalButton()
        self.flipVerticalButton()

        Divider()

        self.invertToggle()
        self.resetButton()

        Divider()

        self.levelsButton()
        self.curvesButton()

        Divider()

        self.headersButton()

        Divider()

        self.sessionMetricsButton()

        Divider()

        self.plateSolveButton()
    }

    /// Zooms the canvas in.
    private func zoomInButton() -> some View
    {
        Button
        {
            self.canvas?.zoomIn()
        }
        label:
        {
            Label( "Zoom In", systemImage: "plus" )
        }
        .keyboardShortcut( "+", modifiers: .command )
        .disabled( self.canDriveCanvas == false )
    }

    /// Zooms the canvas out.
    private func zoomOutButton() -> some View
    {
        Button
        {
            self.canvas?.zoomOut()
        }
        label:
        {
            Label( "Zoom Out", systemImage: "minus" )
        }
        .keyboardShortcut( "-", modifiers: .command )
        .disabled( self.canDriveCanvas == false || self.canvas?.canZoomOut == false )
    }

    /// Restores the canvas to its actual pixel size.
    private func actualSizeButton() -> some View
    {
        Button
        {
            self.canvas?.actualSize()
        }
        label:
        {
            Label( "Actual Size", systemImage: "1.magnifyingglass" )
        }
        .keyboardShortcut( "0", modifiers: .command )
        .disabled( self.canDriveCanvas == false )
    }

    /// Fits the image to the window.
    private func fitButton() -> some View
    {
        Button
        {
            self.canvas?.fit()
        }
        label:
        {
            Label( "Fit to Window", systemImage: "arrow.up.left.and.arrow.down.right" )
        }
        .keyboardShortcut( "9", modifiers: .command )
        .disabled( self.canDriveCanvas == false )
    }

    /// Recenters the image in the window.
    private func recenterButton() -> some View
    {
        Button
        {
            self.canvas?.recenter()
        }
        label:
        {
            Label( "Recenter", systemImage: "scope" )
        }
        .disabled( self.canDriveCanvas == false )
    }

    /// Whether the canvas-driven zoom items apply: there is a canvas controller AND a
    /// raster image is shown. A graph file (`NAXIS=1`) shows no canvas, but the
    /// window's previously-focused ``ImageCanvasController`` can linger as the focused
    /// object, so gating on ``hasImage`` too keeps zoom/fit/recenter disabled for it.
    private var canDriveCanvas: Bool
    {
        self.canvas != nil && self.hasImage
    }

    /// Toggles the before/after comparison — a canvas-view aid, so the binding
    /// ignores the new value and routes to the shared controller toggle, mirroring
    /// the floating toolbar's compare button. Needs a rendered image, like the
    /// orientation and editor items.
    private func compareToggle() -> some View
    {
        Toggle( isOn: Binding( get: { self.canvas?.isComparing ?? false }, set: { _ in self.canvas?.toggleComparison() } ) )
        {
            Label( "Compare Before/After", systemImage: "rectangle.split.2x1" )
        }
        .disabled( self.canDriveCanvas == false )
    }

    /// The overlay toggles, one per available overlay, shown (with a leading
    /// divider) only when the canvas has overlays. Each mirrors its toolbar toggle:
    /// the binding ignores the new value and routes to the shared tap handler, so an
    /// overlay with no data explains itself (or proposes a plate solve) instead of
    /// switching on, exactly as tapping its toolbar button does.
    @ViewBuilder
    private func overlayToggles() -> some View
    {
        if let canvas = self.canvas, self.hasImage, canvas.overlays.isEmpty == false
        {
            Divider()

            ForEach( canvas.overlays, id: \.id )
            {
                overlay in

                Toggle( isOn: Binding( get: { canvas.isOverlayEnabled( overlay.id ) }, set: { _ in canvas.overlayTapped( overlay.id ) } ) )
                {
                    Label( overlay.title, systemImage: overlay.systemImageName )
                }
            }
        }
    }

    /// Rotates the image 90° counter-clockwise, driving the shared adjustments so
    /// the inspector's orientation control stays in step.
    private func rotateLeftButton() -> some View
    {
        Button
        {
            self.file?.image?.rotateLeft()
        }
        label:
        {
            Label( "Rotate Left", systemImage: "rotate.left" )
        }
        .disabled( self.hasImage == false )
    }

    /// Rotates the image 90° clockwise.
    private func rotateRightButton() -> some View
    {
        Button
        {
            self.file?.image?.rotateRight()
        }
        label:
        {
            Label( "Rotate Right", systemImage: "rotate.right" )
        }
        .disabled( self.hasImage == false )
    }

    /// Flips the image horizontally.
    private func flipHorizontalButton() -> some View
    {
        Button
        {
            self.file?.image?.flipHorizontal()
        }
        label:
        {
            Label( "Flip Horizontal", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right" )
        }
        .disabled( self.hasImage == false )
    }

    /// Flips the image vertically.
    private func flipVerticalButton() -> some View
    {
        Button
        {
            self.file?.image?.flipVertical()
        }
        label:
        {
            Label( "Flip Vertical", systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down" )
        }
        .disabled( self.hasImage == false )
    }

    /// Toggles the photographic-negative inversion, mirroring the inspector's
    /// toggle: the binding ignores the new value and routes to the shared action,
    /// which also reseeds the inspector.
    private func invertToggle() -> some View
    {
        Toggle( isOn: Binding( get: { self.file?.image?.renderer.adjustments.invert ?? false }, set: { _ in self.file?.image?.toggleInvert() } ) )
        {
            Label( "Invert", systemImage: "circle.righthalf.filled" )
        }
        .disabled( self.hasImage == false )
    }

    /// Resets every image adjustment to its default.
    private func resetButton() -> some View
    {
        Button
        {
            self.file?.image?.resetAdjustments()
        }
        label:
        {
            Label( "Reset View", systemImage: "arrow.counterclockwise" )
        }
        .disabled( self.hasImage == false )
    }

    /// Opens the Levels editor window.
    private func levelsButton() -> some View
    {
        Button
        {
            self.openWindow( id: "LevelsWindow" )
        }
        label:
        {
            Label( "Levels\u{2026}", systemImage: "slider.horizontal.below.rectangle" )
        }
        .disabled( self.hasImage == false )
    }

    /// Opens the Curves editor window.
    private func curvesButton() -> some View
    {
        Button
        {
            self.openWindow( id: "CurvesWindow" )
        }
        label:
        {
            Label( "Curves\u{2026}", systemImage: "point.topleft.down.to.point.bottomright.curvepath" )
        }
        .disabled( self.hasImage == false )
    }

    /// Opens the metadata window for the focused image. The metadata is captured
    /// here so the button's action holds a non-optional value; when there is no image
    /// a disabled placeholder is shown instead.
    @ViewBuilder
    private func headersButton() -> some View
    {
        if let metadata = self.file?.image?.metadata
        {
            Button
            {
                self.openWindow( id: "InfoWindow", value: metadata )
            }
            label:
            {
                Label( "View Metadata\u{2026}", systemImage: "tablecells" )
            }
        }
        else
        {
            Button( action: {} )
            {
                Label( "View Metadata\u{2026}", systemImage: "tablecells" )
            }
            .disabled( true )
        }
    }

    /// Opens the Session Metrics window. It trends every open file's metrics, so it
    /// only needs a window with files — not the selected image finished rendering —
    /// and stays available while the session is still being analysed, which is why it
    /// sits in its own group apart from the headers item.
    private func sessionMetricsButton() -> some View
    {
        Button
        {
            self.openWindow( id: "SessionMetricsWindow" )
        }
        label:
        {
            Label( "Session Metrics\u{2026}", systemImage: "chart.line.uptrend.xyaxis" )
        }
        .disabled( self.file == nil )
    }

    /// Starts plate-solving the focused file with the configured Astrometry.net key.
    private func plateSolveButton() -> some View
    {
        Button
        {
            if let file = self.file
            {
                self.appModel.presentPlateSolve( for: file, apiKey: self.apiKeyStore.astrometryNetKey, openWindow: self.openWindow )
            }
        }
        label:
        {
            Label( "Plate Solve\u{2026}", systemImage: "point.3.connected.trianglepath.dotted" )
        }
        .keyboardShortcut( "p", modifiers: [ .command, .shift ] )
        .disabled( self.hasImage == false )
    }
}
