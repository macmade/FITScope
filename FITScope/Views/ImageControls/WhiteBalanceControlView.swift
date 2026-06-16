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

import SwiftPixel
import SwiftUI

public struct WhiteBalanceControlView: View
{
    public enum Mode: CaseIterable, CustomStringConvertible
    {
        case none
        case auto
        case manual

        public var description: String
        {
            switch self
            {
                case .none:   return "None"
                case .auto:   return "Auto"
                case .manual: return "Manual"
            }
        }
    }

    /// Seed for the manual white-balance gains. Identity gains leave the image
    /// unchanged when the user first switches to Manual; zero gains would blank
    /// every channel to black.
    static let defaultManualGain = 1.0

    private let adjustments: ImageAdjustments
    private let reRender:    () -> Void

    // Seeded to mirror the pipeline's default white balance ( .auto ).
    @State private var mode  = Mode.auto
    @State private var red   = WhiteBalanceControlView.defaultManualGain
    @State private var green = WhiteBalanceControlView.defaultManualGain
    @State private var blue  = WhiteBalanceControlView.defaultManualGain

    public init( adjustments: ImageAdjustments, reRender: @escaping () -> Void )
    {
        self.adjustments = adjustments
        self.reRender    = reRender
    }

    /// Maps the control's selection and slider values to a white-balance mode.
    static func mode( _ mode: Mode, red: Double, green: Double, blue: Double ) -> Processors.WhiteBalance.Mode?
    {
        switch mode
        {
            case .none:   return nil
            case .auto:   return .auto
            case .manual: return .manual( red: red, green: green, blue: blue )
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

            if self.mode == .manual
            {
                SliderGridRowView( value: $red,   minimumValue: 0, maximumValue: 255, label: "Red",   image: "r.circle.fill" )
                SliderGridRowView( value: $green, minimumValue: 0, maximumValue: 255, label: "Green", image: "g.circle.fill" )
                SliderGridRowView( value: $blue,  minimumValue: 0, maximumValue: 255, label: "Blue",  image: "b.circle.fill" )
            }
        }
        .onChange( of: self.whiteBalanceMode )
        {
            self.adjustments.whiteBalance = self.whiteBalanceMode

            self.reRender()
        }
    }

    private var whiteBalanceMode: Processors.WhiteBalance.Mode?
    {
        Self.mode( self.mode, red: self.red, green: self.green, blue: self.blue )
    }
}

#Preview
{
    WhiteBalanceControlView( adjustments: ImageAdjustments(), reRender: {} )
        .frame( maxWidth: .infinity, alignment: .leading )
        .frame( maxHeight: .infinity, alignment: .top )
        .padding()
}
