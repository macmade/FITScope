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

/// The floating toolbar over the image canvas: pan (always-on placeholder),
/// recenter, zoom out / percent / zoom in, and fit. Region-select and measure
/// tools are intentionally omitted in this iteration.
public struct ImageToolbarView: View
{
    /// The current magnification (1.0 == 100%), shown as a percentage.
    public let zoom:       CGFloat

    /// Called to request a fit.
    public let onFit:      () -> Void

    /// Called to request a recenter.
    public let onRecenter: () -> Void

    /// Called to request a zoom-in step.
    public let onZoomIn:   () -> Void

    /// Called to request a zoom-out step.
    public let onZoomOut:  () -> Void

    /// Creates the toolbar.
    public init( zoom: CGFloat, onFit: @escaping () -> Void, onRecenter: @escaping () -> Void, onZoomIn: @escaping () -> Void, onZoomOut: @escaping () -> Void )
    {
        self.zoom       = zoom
        self.onFit      = onFit
        self.onRecenter = onRecenter
        self.onZoomIn   = onZoomIn
        self.onZoomOut  = onZoomOut
    }

    /// The view's content.
    public var body: some View
    {
        HStack( spacing: 4 )
        {
            Image( systemName: "hand.raised.fill" )
                .frame( width: 26, height: 24 )
                .background( Color.accentColor, in: RoundedRectangle( cornerRadius: 7 ) )
                .foregroundStyle( .white )

            Button( action: self.onRecenter )
            {
                Image( systemName: "scope" )
            }

            Divider().frame( height: 16 )

            Button( action: self.onZoomOut )
            {
                Image( systemName: "minus" )
            }

            Text( "\( Int( ( self.zoom * 100 ).rounded() ) )%" )
                .font( .system( size: 11, design: .monospaced ) )
                .frame( minWidth: 42 )

            Button( action: self.onZoomIn )
            {
                Image( systemName: "plus" )
            }

            Divider().frame( height: 16 )

            Button( action: self.onFit )
            {
                Image( systemName: "arrow.up.left.and.arrow.down.right" )
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
    ImageToolbarView( zoom: 1.0, onFit: {}, onRecenter: {}, onZoomIn: {}, onZoomOut: {} )
        .padding()
        .background( .black )
}
