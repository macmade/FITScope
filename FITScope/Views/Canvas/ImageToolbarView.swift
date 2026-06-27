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
    public let zoom: CGFloat

    /// Whether zoom-out is available; the zoom-out button is disabled otherwise
    /// (the whole image is already visible).
    public let canZoomOut: Bool

    /// Called to request a fit.
    public let onFit: () -> Void

    /// Called to request showing the image at actual size (100%).
    public let onActualSize: () -> Void

    /// Called to request a recenter.
    public let onRecenter: () -> Void

    /// Called to request a zoom-in step.
    public let onZoomIn: () -> Void

    /// Called to request a zoom-out step.
    public let onZoomOut: () -> Void

    /// The overlays available for the current image, in toolbar order. Empty when
    /// none apply, in which case no overlay section is shown.
    public let overlays: [ any CanvasOverlay ]

    /// Whether the overlay with a given identifier is currently enabled.
    public let isOverlayEnabled: ( String ) -> Bool

    /// Called to toggle the overlay with a given identifier on or off.
    public let onToggleOverlay: ( String ) -> Void

    /// Creates the toolbar.
    public init( zoom: CGFloat, canZoomOut: Bool, onFit: @escaping () -> Void, onActualSize: @escaping () -> Void, onRecenter: @escaping () -> Void, onZoomIn: @escaping () -> Void, onZoomOut: @escaping () -> Void, overlays: [ any CanvasOverlay ], isOverlayEnabled: @escaping ( String ) -> Bool, onToggleOverlay: @escaping ( String ) -> Void )
    {
        self.zoom             = zoom
        self.canZoomOut       = canZoomOut
        self.onFit            = onFit
        self.onActualSize     = onActualSize
        self.onRecenter       = onRecenter
        self.onZoomIn         = onZoomIn
        self.onZoomOut        = onZoomOut
        self.overlays         = overlays
        self.isOverlayEnabled = isOverlayEnabled
        self.onToggleOverlay  = onToggleOverlay
    }

    /// The view's content.
    public var body: some View
    {
        HStack( spacing: 4 )
        {
            ImageToolbarButton( systemImage: "scope", help: "Center the Image", identifier: AccessibilityIdentifier.ImageToolbarView.recenter, action: self.onRecenter )

            Divider().frame( height: 16 )

            ImageToolbarButton( systemImage: "minus", help: "Zoom Out", identifier: AccessibilityIdentifier.ImageToolbarView.zoomOut, isEnabled: self.canZoomOut, action: self.onZoomOut )

            Text( "\( Int( ( self.zoom * 100 ).rounded() ) )%" )
                .font( .system( size: 11, design: .monospaced ) )
                .frame( minWidth: 42 )
                .accessibilityIdentifier( AccessibilityIdentifier.ImageToolbarView.zoomReadout )

            ImageToolbarButton( systemImage: "plus", help: "Zoom In", identifier: AccessibilityIdentifier.ImageToolbarView.zoomIn, action: self.onZoomIn )

            Divider().frame( height: 16 )

            ImageToolbarButton( systemImage: "arrow.up.left.and.arrow.down.right", help: "Fit the Image to the Window", identifier: AccessibilityIdentifier.ImageToolbarView.fit, action: self.onFit )
            ImageToolbarButton( systemImage: "1.magnifyingglass", help: "Show the Image at Actual Size (100%)", identifier: AccessibilityIdentifier.ImageToolbarView.actualSize, action: self.onActualSize )

            if self.overlays.isEmpty == false
            {
                Divider().frame( height: 16 )

                // Each overlay renders the same control. A loading overlay (its data
                // still being computed) shows the disabled, pulsing state; the
                // toolbar needs no knowledge of what any overlay computes.
                ForEach( self.overlays, id: \.id )
                {
                    overlay in

                    ImageToolbarButton( systemImage: overlay.systemImageName, help: overlay.title, identifier: AccessibilityIdentifier.ImageToolbarView.overlayToggle( overlay.id ), isActive: self.isOverlayEnabled( overlay.id ), isLoading: overlay.isLoading )
                    {
                        self.onToggleOverlay( overlay.id )
                    }
                }
            }
        }
        .buttonStyle( .borderless )
        .padding( .horizontal, 8 )
        .padding( .vertical, 6 )
        .background( .ultraThinMaterial, in: RoundedRectangle( cornerRadius: 12 ) )
        .overlay( RoundedRectangle( cornerRadius: 12 ).stroke( .white.opacity( 0.1 ) ) )
    }
}

#Preview
{
    ImageToolbarView( zoom: 1.0, canZoomOut: true, onFit: {}, onActualSize: {}, onRecenter: {}, onZoomIn: {}, onZoomOut: {}, overlays: [ FrameOverlay() ], isOverlayEnabled: { _ in false }, onToggleOverlay: { _ in } )
        .padding()
        .background( .black )
}
