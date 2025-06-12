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

import SwiftFITS
import SwiftUI

public struct StretchControlView: View
{
    public enum Mode: CaseIterable, CustomStringConvertible
    {
        case none
        case log
        case arcsinh
        case sigmood

        public var description: String
        {
            switch self
            {
                case .none:    return "None"
                case .log:     return "Logarithmic"
                case .arcsinh: return "Inverse Hyperbolic Sine"
                case .sigmood: return "Sigmoid"
            }
        }
    }

    @State private var mode               = Mode.none
    @State private var showLogSliders     = false
    @State private var showArcSinHSliders = false
    @State private var showSigmoidSliders = false
    @State private var logN1              = 0.0
    @State private var arcsinhN1          = 0.0
    @State private var sigmoidN1          = 0.0
    @State private var sigmoidN2          = 0.0

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

            if self.showLogSliders
            {
                SliderGridRowView( value: $logN1, minimumValue: 0, maximumValue: 255, label: "Intensity", image: "n.circle.fill" )
            }

            if self.showArcSinHSliders
            {
                SliderGridRowView( value: $arcsinhN1, minimumValue: 0, maximumValue: 255, label: "Factor", image: "n.circle.fill" )
            }

            if self.showSigmoidSliders
            {
                SliderGridRowView( value: $sigmoidN1, minimumValue: 0, maximumValue: 255, label: "Midpoint", image: "n.circle.fill" )
                SliderGridRowView( value: $sigmoidN2, minimumValue: 0, maximumValue: 255, label: "Contrast", image: "n.circle.fill" )
            }
        }
        .onChange( of: self.mode )
        {
            switch mode
            {
                case .none:

                    self.showLogSliders     = false
                    self.showArcSinHSliders = false
                    self.showSigmoidSliders = false

                case .log:

                    self.showLogSliders     = true
                    self.showArcSinHSliders = false
                    self.showSigmoidSliders = false

                case .arcsinh:

                    self.showLogSliders     = false
                    self.showArcSinHSliders = true
                    self.showSigmoidSliders = false

                case .sigmood:

                    self.showLogSliders     = false
                    self.showArcSinHSliders = false
                    self.showSigmoidSliders = true
            }
        }
    }
}

#Preview
{
    StretchControlView()
        .frame( maxWidth: .infinity, alignment: .leading )
        .frame( maxHeight: .infinity, alignment: .top )
        .padding()
}
