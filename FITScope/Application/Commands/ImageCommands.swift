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

    /// Whether the frontmost window has a loaded image, gating the file-targeted
    /// items (orientation, invert, reset, the editors, and the headers window).
    private var hasImage: Bool
    {
        self.file?.image != nil
    }

    /// The menu items: zoom, overlay toggles, orientation, invert / reset, the
    /// Levels and Curves editors, the FITS-headers window, then plate solving.
    var body: some View
    {
        // Each item carries the same SF Symbol as its toolbar / inspector button,
        // so the menu reads as the same actions in a different place.
        Button
        {
            self.canvas?.zoomIn()
        }
        label:
        {
            Label( "Zoom In", systemImage: "plus" )
        }
        .keyboardShortcut( "+", modifiers: .command )
        .disabled( self.canvas == nil )

        Button
        {
            self.canvas?.zoomOut()
        }
        label:
        {
            Label( "Zoom Out", systemImage: "minus" )
        }
        .keyboardShortcut( "-", modifiers: .command )
        .disabled( self.canvas == nil || self.canvas?.canZoomOut == false )

        Button
        {
            self.canvas?.actualSize()
        }
        label:
        {
            Label( "Actual Size", systemImage: "1.magnifyingglass" )
        }
        .keyboardShortcut( "0", modifiers: .command )
        .disabled( self.canvas == nil )

        Button
        {
            self.canvas?.fit()
        }
        label:
        {
            Label( "Fit to Window", systemImage: "arrow.up.left.and.arrow.down.right" )
        }
        .keyboardShortcut( "9", modifiers: .command )
        .disabled( self.canvas == nil )

        Button
        {
            self.canvas?.recenter()
        }
        label:
        {
            Label( "Recenter", systemImage: "scope" )
        }
        .disabled( self.canvas == nil )

        Divider()

        // The before/after comparison — a canvas view aid, so it toggles the same
        // controller state the floating toolbar's compare button drives. The
        // binding ignores the new value and routes to the shared toggle, so both
        // places behave identically. Needs a rendered image, like the orientation
        // and editor items below.
        Toggle( isOn: Binding( get: { self.canvas?.isComparing ?? false }, set: { _ in self.canvas?.toggleComparison() } ) )
        {
            Label( "Compare Before/After", systemImage: "rectangle.split.2x1" )
        }
        .disabled( self.canvas == nil || self.hasImage == false )

        if let canvas = self.canvas, canvas.overlays.isEmpty == false
        {
            Divider()

            // Each overlay mirrors its toolbar toggle — same icon, and a binding that
            // ignores the new value and routes to the shared tap handler, so an
            // overlay with no data explains itself (or proposes a plate solve)
            // instead of switching on, exactly as tapping its toolbar button does.
            ForEach( canvas.overlays, id: \.id )
            {
                overlay in

                Toggle( isOn: Binding( get: { canvas.isOverlayEnabled( overlay.id ) }, set: { _ in canvas.overlayTapped( overlay.id ) } ) )
                {
                    Label( overlay.title, systemImage: overlay.systemImageName )
                }
            }
        }

        Divider()

        // Orientation — the same actions and icons as the inspector's orientation
        // control, driving the shared adjustments so the inspector stays in step.
        Button
        {
            self.file?.image?.rotateLeft()
        }
        label:
        {
            Label( "Rotate Left", systemImage: "rotate.left" )
        }
        .disabled( self.hasImage == false )

        Button
        {
            self.file?.image?.rotateRight()
        }
        label:
        {
            Label( "Rotate Right", systemImage: "rotate.right" )
        }
        .disabled( self.hasImage == false )

        Button
        {
            self.file?.image?.flipHorizontal()
        }
        label:
        {
            Label( "Flip Horizontal", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right" )
        }
        .disabled( self.hasImage == false )

        Button
        {
            self.file?.image?.flipVertical()
        }
        label:
        {
            Label( "Flip Vertical", systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down" )
        }
        .disabled( self.hasImage == false )

        Divider()

        // Invert mirrors the inspector's toggle: the binding ignores the new value
        // and routes to the shared action, which also reseeds the inspector.
        Toggle( isOn: Binding( get: { self.file?.image?.renderer.adjustments.invert ?? false }, set: { _ in self.file?.image?.toggleInvert() } ) )
        {
            Label( "Invert", systemImage: "circle.righthalf.filled" )
        }
        .disabled( self.hasImage == false )

        Button
        {
            self.file?.image?.resetAdjustments()
        }
        label:
        {
            Label( "Reset View", systemImage: "arrow.counterclockwise" )
        }
        .disabled( self.hasImage == false )

        Divider()

        Button
        {
            self.openWindow( id: "LevelsWindow" )
        }
        label:
        {
            Label( "Levels\u{2026}", systemImage: "slider.horizontal.below.rectangle" )
        }
        .disabled( self.hasImage == false )

        Button
        {
            self.openWindow( id: "CurvesWindow" )
        }
        label:
        {
            Label( "Curves\u{2026}", systemImage: "point.topleft.down.to.point.bottomright.curvepath" )
        }
        .disabled( self.hasImage == false )

        Divider()

        Button
        {
            if let info = self.file?.image?.info
            {
                self.openWindow( id: "InfoWindow", value: info )
            }
        }
        label:
        {
            Label( "View FITS Headers\u{2026}", systemImage: "tablecells" )
        }
        .disabled( self.hasImage == false )

        Divider()

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
        .disabled( self.file == nil )
    }
}
