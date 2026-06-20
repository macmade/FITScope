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

/// The color section of the controls panel: an invert toggle, with a note that
/// the colour map and high-contrast options are not yet available.
public struct ColorControlView: View
{
    /// The shared adjustment values this control writes to.
    private let adjustments: ImageAdjustments

    /// Requests a debounced re-render after a change.
    private let reRender:    () -> Void

    /// Whether the image is inverted. Seeded to mirror the pipeline's default
    /// (off).
    @State private var invert = false

    /// Creates the color control.
    ///
    /// - Parameters:
    ///   - adjustments: The shared adjustment values to write to.
    ///   - reRender:    The closure to call after a change.
    public init( adjustments: ImageAdjustments, reRender: @escaping () -> Void )
    {
        self.adjustments = adjustments
        self.reRender    = reRender
    }

    /// The view's content.
    public var body: some View
    {
        VStack( alignment: .leading, spacing: 10 )
        {
            Toggle( "Invert", isOn: $invert )
                .help( "Invert the image (photographic negative)." )
                .accessibilityIdentifier( AccessibilityIdentifier.ColorControlView.invertToggle )

            Text( "Color map and high contrast are not yet available." )
                .font( .system( size: 10 ) )
                .foregroundStyle( .tertiary )
                .frame( maxWidth: .infinity, alignment: .leading )
                .padding( 10 )
                .background( RoundedRectangle( cornerRadius: 8 ).strokeBorder( .quaternary, style: StrokeStyle( lineWidth: 1, dash: [ 3 ] ) ) )
        }
        .onChange( of: self.invert )
        {
            self.adjustments.invert = self.invert

            self.reRender()
        }
    }
}

#Preview
{
    ColorControlView( adjustments: ImageAdjustments(), reRender: {} )
        .frame( maxWidth: .infinity, alignment: .leading )
        .frame( maxHeight: .infinity, alignment: .top )
        .padding()
}
