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

/// The gamma-correction section of the controls panel: a toggle plus, when
/// enabled, a slider for the gamma exponent.
public struct GammaCorrectionControlView: View
{
    /// The slider's lower bound. Stays above zero because a gamma of zero (or
    /// less) is a degenerate exponent the pipeline rejects by throwing, so the
    /// control can never emit such a value.
    static let minimumGamma = 0.1

    /// The slider's upper bound.
    static let maximumGamma = 5.0

    /// The seed value, mirroring the pipeline's default gamma.
    static let defaultGamma = 1.8

    /// The shared adjustment values this control writes to.
    private let adjustments: ImageAdjustments

    /// Requests a debounced re-render after a change.
    private let reRender:    () -> Void

    /// Whether gamma correction is enabled. Seeded from the image's adjustments
    /// so the control reflects the file it belongs to.
    @State private var enabled: Bool

    /// The current gamma exponent. Seeded from the image's adjustments, falling
    /// back to the pipeline's default of `1.8` when gamma is off.
    @State private var gamma:   Double

    /// Creates the gamma control.
    ///
    /// - Parameters:
    ///   - adjustments: The shared adjustment values to write to.
    ///   - reRender:    The closure to call after a change.
    public init( adjustments: ImageAdjustments, reRender: @escaping () -> Void )
    {
        self.adjustments = adjustments
        self.reRender    = reRender
        self.enabled     = adjustments.gamma != nil
        self.gamma       = adjustments.gamma ?? Self.defaultGamma
    }

    /// Maps the toggle and slider value to a gamma exponent.
    ///
    /// - Parameters:
    ///   - enabled: Whether gamma correction is on.
    ///   - value:   The slider's gamma value.
    /// - Returns: The exponent, or `nil` when correction is off.
    static func gamma( enabled: Bool, value: Double ) -> Double?
    {
        enabled ? value : nil
    }

    /// The view's content.
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
                    .accessibilityIdentifier( AccessibilityIdentifier.GammaCorrectionControlView.toggle )
                    .help( "Apply Gamma Correction" )
            }

            if self.enabled
            {
                SliderGridRowView( value: $gamma, minimumValue: Self.minimumGamma, maximumValue: Self.maximumGamma, label: "Gamma", image: "eye.fill" )
                    .accessibilityIdentifier( AccessibilityIdentifier.GammaCorrectionControlView.slider )
                    .help( "Gamma Exponent" )
            }
        }
        .onChange( of: self.gammaValue )
        {
            self.adjustments.gamma = self.gammaValue

            self.reRender()
        }
    }

    /// The current gamma exponent derived from the toggle and slider, or `nil`
    /// when correction is off.
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
