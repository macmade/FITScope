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

/// The debayer section of the controls panel: a picker choosing how a
/// colour-filter-array image is reconstructed into RGB.
public struct DebayerControlView: View
{
    /// The debayer choices offered by the picker.
    public enum Mode: CaseIterable, CustomStringConvertible
    {
        /// Do not debayer; treat the image as monochrome.
        case none

        /// Use the Bayer pattern declared in the file header, if any.
        case auto

        /// Force the BGGR pattern.
        case bggr

        /// Force the RGBG pattern.
        case rgbg

        /// Force the GRBG pattern.
        case grbg

        /// Force the RGGB pattern.
        case rggb

        /// The picker label for the mode.
        public var description: String
        {
            switch self
            {
                case .none: return "None"
                case .auto: return "Auto"
                case .bggr: return "BGGR"
                case .rgbg: return "RGBG"
                case .grbg: return "GRBG"
                case .rggb: return "RGGB"
            }
        }
    }

    /// The shared adjustment values this control writes to.
    private let adjustments: ImageAdjustments

    /// Requests a debounced re-render after the selection changes.
    private let reRender:    () -> Void

    /// The selected mode. Seeded to mirror the pipeline's default debayer
    /// selection (`.auto`).
    @State private var mode = Mode.auto

    /// Creates the debayer control.
    ///
    /// - Parameters:
    ///   - adjustments: The shared adjustment values to write to.
    ///   - reRender:    The closure to call after the selection changes.
    public init( adjustments: ImageAdjustments, reRender: @escaping () -> Void )
    {
        self.adjustments = adjustments
        self.reRender    = reRender
    }

    /// Maps the control's selection to a debayer selection.
    ///
    /// - Parameter mode: The selected mode.
    /// - Returns: The corresponding ``ImageProcessor/DebayerSelection``.
    static func selection( _ mode: Mode ) -> ImageProcessor.DebayerSelection
    {
        switch mode
        {
            case .none: return .none
            case .auto: return .auto
            case .bggr: return .pattern( .bggr )
            case .rgbg: return .pattern( .rgbg )
            case .grbg: return .pattern( .grbg )
            case .rggb: return .pattern( .rggb )
        }
    }

    /// The view's content.
    public var body: some View
    {
        Grid( alignment: .leading )
        {
            GridRow
            {
                Text( "Mode" )
                Picker( "Mode", selection: $mode )
                {
                    ForEach( Mode.allCases, id: \.self )
                    {
                        Text( $0.description ).tag( $0 )
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier( AccessibilityIdentifier.DebayerControlView.modePicker )
            }

            GridRow
            {
                Text( "Algorithm" )
                Picker( "Algorithm", selection: Binding(
                    get: { self.adjustments.debayerAlgorithm },
                    set: { self.adjustments.debayerAlgorithm = $0
                        self.reRender()
                    }
                ) )
                {
                    Text( "Bilinear" ).tag( Processors.Debayer.Mode.bilinear )
                    Text( "VNG" ).tag( Processors.Debayer.Mode.vng )
                }
                .labelsHidden()
                .disabled( self.mode == .none )
                .accessibilityIdentifier( AccessibilityIdentifier.DebayerControlView.algorithmPicker )
            }
        }
        .onChange( of: self.mode )
        {
            self.adjustments.debayer = Self.selection( self.mode )

            self.reRender()
        }
    }
}

#Preview
{
    DebayerControlView( adjustments: ImageAdjustments(), reRender: {} )
        .frame( maxWidth: .infinity, alignment: .leading )
        .frame( maxHeight: .infinity, alignment: .top )
        .padding()
}
