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

public struct DebayerControlView: View
{
    public enum Mode: CaseIterable, CustomStringConvertible
    {
        case none
        case auto
        case bggr
        case rgbg
        case grbg
        case rggb

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

    private let adjustments: ImageAdjustments
    private let reRender:    () -> Void

    // Seeded to mirror the pipeline's default debayer selection ( .auto ).
    @State private var mode = Mode.auto

    public init( adjustments: ImageAdjustments, reRender: @escaping () -> Void )
    {
        self.adjustments = adjustments
        self.reRender    = reRender
    }

    /// Maps the control's selection to a debayer selection.
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
