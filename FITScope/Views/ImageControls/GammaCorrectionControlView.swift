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

public struct GammaCorrectionControlView: View
{
    /// Gamma slider bounds and seed. The minimum stays above zero because a
    /// gamma of zero (or less) is a degenerate exponent the pipeline rejects by
    /// throwing, so the control can never emit such a value.
    static let minimumGamma = 0.1
    static let maximumGamma = 5.0
    static let defaultGamma = 1.8

    private let adjustments: ImageAdjustments
    private let reRender:    () -> Void

    // Seeded to mirror the pipeline's default gamma ( 1.8, enabled ).
    @State private var enabled = true
    @State private var gamma   = GammaCorrectionControlView.defaultGamma

    public init( adjustments: ImageAdjustments, reRender: @escaping () -> Void )
    {
        self.adjustments = adjustments
        self.reRender    = reRender
    }

    /// Maps the toggle and slider value to a gamma exponent ( `nil` when off ).
    static func gamma( enabled: Bool, value: Double ) -> Double?
    {
        enabled ? value : nil
    }

    public var body: some View
    {
        Grid( alignment: .leading )
        {
            GridRow
            {
                Text( "Enabled" )
                Toggle( "Enable", isOn: $enabled )
                    .toggleStyle( SwitchToggleStyle() )
                    .labelsHidden()
            }

            if self.enabled
            {
                SliderGridRowView( value: $gamma, minimumValue: Self.minimumGamma, maximumValue: Self.maximumGamma, label: "Gamma", image: "eye.fill" )
            }
        }
        .onChange( of: self.gammaValue )
        {
            self.adjustments.gamma = self.gammaValue

            self.reRender()
        }
    }

    private var gammaValue: Double?
    {
        Self.gamma( enabled: self.enabled, value: self.gamma )
    }
}

#Preview
{
    GammaCorrectionControlView( adjustments: ImageAdjustments(), reRender: {} )
        .frame( maxWidth: .infinity, alignment: .leading )
        .frame( maxHeight: .infinity, alignment: .top )
        .padding()
}
