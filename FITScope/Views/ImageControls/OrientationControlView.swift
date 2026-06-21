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

/// The orientation section of the controls panel: rotate-left / rotate-right
/// and flip-horizontal / flip-vertical buttons.
///
/// Each button composes a screen-relative transform onto the shared
/// orientation, so they act on the image as it is currently shown. The buttons
/// hold no state of their own — the orientation lives in the adjustments — so
/// they need no reseeding when the view is reset.
public struct OrientationControlView: View
{
    /// The shared adjustment values this control writes to.
    private let adjustments: ImageAdjustments

    /// Requests a debounced re-render after a change.
    private let reRender:    () -> Void

    /// Creates the orientation control.
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
        HStack( spacing: 8 )
        {
            self.button( image: "rotate.left",  help: "Rotate Left (90° Counter-Clockwise)", identifier: AccessibilityIdentifier.OrientationControlView.rotateLeft )
            {
                $0.rotatedCounterClockwise()
            }

            self.button( image: "rotate.right", help: "Rotate Right (90° Clockwise)", identifier: AccessibilityIdentifier.OrientationControlView.rotateRight )
            {
                $0.rotatedClockwise()
            }

            self.button( image: "arrow.left.and.right.righttriangle.left.righttriangle.right", help: "Flip Horizontally", identifier: AccessibilityIdentifier.OrientationControlView.flipHorizontal )
            {
                $0.flippedHorizontally()
            }

            self.button( image: "arrow.up.and.down.righttriangle.up.righttriangle.down", help: "Flip Vertically", identifier: AccessibilityIdentifier.OrientationControlView.flipVertical )
            {
                $0.flippedVertically()
            }
        }
        .frame( maxWidth: .infinity, alignment: .leading )
    }

    /// A bordered icon button that composes `transform` onto the orientation and
    /// re-renders.
    private func button( image: String, help: String, identifier: String, transform: @escaping ( Processors.Orient.Orientation ) -> Processors.Orient.Orientation ) -> some View
    {
        Button
        {
            self.adjustments.orientation = transform( self.adjustments.orientation )

            self.reRender()
        }
        label:
        {
            Image( systemName: image )
                .frame( width: 26, height: 24 )
                .contentShape( Rectangle() )
        }
        .buttonStyle( .bordered )
        .help( help )
        .accessibilityIdentifier( identifier )
    }
}

#Preview
{
    OrientationControlView( adjustments: ImageAdjustments(), reRender: {} )
        .frame( maxWidth: .infinity, alignment: .leading )
        .padding()
}
