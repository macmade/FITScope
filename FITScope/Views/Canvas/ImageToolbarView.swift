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

/// The floating toolbar over the image canvas: recenter, zoom out / percent /
/// zoom in, fit to window, and actual size (100%).
public struct ImageToolbarView: View
{
    /// The current magnification (1.0 == 100%), shown as a percentage.
    public let zoom:         CGFloat

    /// Whether zoom-out is available; the zoom-out button is disabled otherwise
    /// (the whole image is already visible).
    public let canZoomOut:   Bool

    /// Called to request a fit.
    public let onFit:        () -> Void

    /// Called to request showing the image at actual size (100%).
    public let onActualSize: () -> Void

    /// Called to request a recenter.
    public let onRecenter:   () -> Void

    /// Called to request a zoom-in step.
    public let onZoomIn:     () -> Void

    /// Called to request a zoom-out step.
    public let onZoomOut:    () -> Void

    /// Called to rotate the image 90° counter-clockwise.
    public let onRotateLeft:     () -> Void

    /// Called to rotate the image 90° clockwise.
    public let onRotateRight:    () -> Void

    /// Called to flip the image horizontally.
    public let onFlipHorizontal: () -> Void

    /// Called to flip the image vertically.
    public let onFlipVertical:   () -> Void

    /// The overlays available for the current image, in toolbar order. Empty when
    /// none apply, in which case no overlay section is shown.
    public let overlays:         [ any CanvasOverlay ]

    /// Whether the overlay with a given identifier is currently enabled.
    public let isOverlayEnabled: ( String ) -> Bool

    /// Called to toggle the overlay with a given identifier on or off.
    public let onToggleOverlay:  ( String ) -> Void

    /// Creates the toolbar.
    public init( zoom: CGFloat, canZoomOut: Bool, onFit: @escaping () -> Void, onActualSize: @escaping () -> Void, onRecenter: @escaping () -> Void, onZoomIn: @escaping () -> Void, onZoomOut: @escaping () -> Void, onRotateLeft: @escaping () -> Void, onRotateRight: @escaping () -> Void, onFlipHorizontal: @escaping () -> Void, onFlipVertical: @escaping () -> Void, overlays: [ any CanvasOverlay ], isOverlayEnabled: @escaping ( String ) -> Bool, onToggleOverlay: @escaping ( String ) -> Void )
    {
        self.zoom             = zoom
        self.canZoomOut       = canZoomOut
        self.onFit            = onFit
        self.onActualSize     = onActualSize
        self.onRecenter       = onRecenter
        self.onZoomIn         = onZoomIn
        self.onZoomOut        = onZoomOut
        self.onRotateLeft     = onRotateLeft
        self.onRotateRight    = onRotateRight
        self.onFlipHorizontal = onFlipHorizontal
        self.onFlipVertical   = onFlipVertical
        self.overlays         = overlays
        self.isOverlayEnabled = isOverlayEnabled
        self.onToggleOverlay  = onToggleOverlay
    }

    /// The view's content.
    public var body: some View
    {
        HStack( spacing: 4 )
        {
            self.button( image: "scope", help: "Center the Image", identifier: AccessibilityIdentifier.ImageToolbarView.recenter, action: self.onRecenter )

            Divider().frame( height: 16 )

            self.button( image: "minus", help: "Zoom Out", identifier: AccessibilityIdentifier.ImageToolbarView.zoomOut, action: self.onZoomOut )
                .disabled( self.canZoomOut == false )

            Text( "\( Int( ( self.zoom * 100 ).rounded() ) )%" )
                .font( .system( size: 11, design: .monospaced ) )
                .frame( minWidth: 42 )
                .accessibilityIdentifier( AccessibilityIdentifier.ImageToolbarView.zoomReadout )

            self.button( image: "plus", help: "Zoom In", identifier: AccessibilityIdentifier.ImageToolbarView.zoomIn, action: self.onZoomIn )

            Divider().frame( height: 16 )

            self.button( image: "arrow.up.left.and.arrow.down.right", help: "Fit the Image to the Window", identifier: AccessibilityIdentifier.ImageToolbarView.fit, action: self.onFit )
            self.button( image: "1.magnifyingglass", help: "Show the Image at Actual Size (100%)", identifier: AccessibilityIdentifier.ImageToolbarView.actualSize, action: self.onActualSize )

            Divider().frame( height: 16 )

            self.button( image: "rotate.left",  help: "Rotate Left (90° Counter-Clockwise)", identifier: AccessibilityIdentifier.ImageToolbarView.rotateLeft,  action: self.onRotateLeft )
            self.button( image: "rotate.right", help: "Rotate Right (90° Clockwise)",        identifier: AccessibilityIdentifier.ImageToolbarView.rotateRight, action: self.onRotateRight )
            self.button( image: "arrow.left.and.right.righttriangle.left.righttriangle.right", help: "Flip Horizontally", identifier: AccessibilityIdentifier.ImageToolbarView.flipHorizontal, action: self.onFlipHorizontal )
            self.button( image: "arrow.up.and.down.righttriangle.up.righttriangle.down",       help: "Flip Vertically",   identifier: AccessibilityIdentifier.ImageToolbarView.flipVertical,   action: self.onFlipVertical )

            if self.overlays.isEmpty == false
            {
                Divider().frame( height: 16 )

                ForEach( self.overlays, id: \.id )
                {
                    overlay in self.overlayToggle( overlay )
                }
            }
        }
        .buttonStyle( .borderless )
        .padding( .horizontal, 8 )
        .padding( .vertical, 6 )
        .background( .ultraThinMaterial, in: RoundedRectangle( cornerRadius: 12 ) )
        .overlay( RoundedRectangle( cornerRadius: 12 ).stroke( .white.opacity( 0.1 ) ) )
    }

    /// A toolbar button: an SF Symbol with a consistent hit area, a tooltip and
    /// a stable accessibility identifier.
    private func button( image: String, help: String, identifier: String, action: @escaping () -> Void ) -> some View
    {
        Button( action: action )
        {
            Image( systemName: image )
                .frame( width: 26, height: 24 )
                .contentShape( Rectangle() )
        }
        .help( help )
        .accessibilityIdentifier( identifier )
    }

    /// A toolbar toggle for an overlay: an SF Symbol that tints when the overlay
    /// is enabled, with the overlay's title as its tooltip.
    private func overlayToggle( _ overlay: any CanvasOverlay ) -> some View
    {
        let enabled = self.isOverlayEnabled( overlay.id )

        return Button
        {
            self.onToggleOverlay( overlay.id )
        }
        label:
        {
            Image( systemName: overlay.systemImageName )
                .frame( width: 26, height: 24 )
                .contentShape( Rectangle() )
        }
        .help( overlay.title )
        .foregroundStyle( enabled ? Color.accentColor : Color.primary )
        .accessibilityIdentifier( AccessibilityIdentifier.ImageToolbarView.overlayToggle( overlay.id ) )
    }
}

#Preview
{
    ImageToolbarView( zoom: 1.0, canZoomOut: true, onFit: {}, onActualSize: {}, onRecenter: {}, onZoomIn: {}, onZoomOut: {}, onRotateLeft: {}, onRotateRight: {}, onFlipHorizontal: {}, onFlipVertical: {}, overlays: [ FrameOverlay() ], isOverlayEnabled: { _ in false }, onToggleOverlay: { _ in } )
        .padding()
        .background( .black )
}
