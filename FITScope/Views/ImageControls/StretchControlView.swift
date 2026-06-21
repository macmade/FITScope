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

import SwiftFITS
import SwiftPixel
import SwiftUI

/// The stretch section of the controls panel: a mode picker plus the sliders
/// each stretch algorithm needs to bring out faint detail.
public struct StretchControlView: View
{
    /// The stretch algorithms offered by the picker.
    public enum Mode: CaseIterable, CustomStringConvertible
    {
        /// No stretch; the image stays linear.
        case none

        /// Logarithmic stretch.
        case log

        /// Inverse hyperbolic sine (arcsinh) stretch.
        case arcsinh

        /// Sigmoid (S-curve) stretch.
        case sigmoid

        /// The picker label for the mode.
        public var description: String
        {
            switch self
            {
                case .none:    return "None"
                case .log:     return "Logarithmic"
                case .arcsinh: return "Inverse Hyperbolic Sine"
                case .sigmoid: return "Sigmoid"
            }
        }
    }

    /// The seed for the logarithmic intensity slider, applied the first time the
    /// user switches to the logarithmic stretch.
    ///
    /// The seeds for all stretch sliders are chosen so each mode's first
    /// interaction yields a valid, non-degenerate render: the arcsinh factor is
    /// non-zero (zero throws), and the sigmoid constants produce a centred
    /// S-curve on normalized data rather than a flat 50% grey.
    static let defaultLogIntensity  = 50.0

    /// The seed for the arcsinh factor slider. Non-zero, since a factor of zero
    /// makes the algorithm throw.
    static let defaultArcsinhFactor = 50.0

    /// The seed for the sigmoid midpoint slider.
    static let defaultSigmoidN1     = 10.0

    /// The seed for the sigmoid contrast slider.
    static let defaultSigmoidN2     = 0.5

    /// The shared adjustment values this control writes to.
    private let adjustments: ImageAdjustments

    /// Requests a debounced re-render after a change.
    private let reRender:    () -> Void

    /// The selected stretch mode. Seeded from the image's adjustments so the
    /// control reflects the file it belongs to.
    @State private var mode:      Mode

    /// The logarithmic intensity slider value.
    @State private var logN1:     Double

    /// The arcsinh factor slider value.
    @State private var arcsinhN1: Double

    /// The sigmoid midpoint slider value.
    @State private var sigmoidN1: Double

    /// The sigmoid contrast slider value.
    @State private var sigmoidN2: Double

    /// Creates the stretch control.
    ///
    /// Each slider is seeded from the image's current algorithm when that mode is
    /// active, and from its default otherwise — so an inactive mode still offers a
    /// sensible starting value.
    ///
    /// - Parameters:
    ///   - adjustments: The shared adjustment values to write to.
    ///   - reRender:    The closure to call after a change.
    public init( adjustments: ImageAdjustments, reRender: @escaping () -> Void )
    {
        self.adjustments = adjustments
        self.reRender    = reRender

        var logN1     = Self.defaultLogIntensity
        var arcsinhN1 = Self.defaultArcsinhFactor
        var sigmoidN1 = Self.defaultSigmoidN1
        var sigmoidN2 = Self.defaultSigmoidN2

        if let stretch = adjustments.stretch
        {
            switch stretch
            {
                case .log( let n ):            logN1 = n
                case .arcsinh( let n ):        arcsinhN1 = n
                case .sigmoid( let a, let b ): sigmoidN1 = a
                    sigmoidN2 = b
                @unknown default:              break
            }
        }

        self.mode      = Self.mode( adjustments.stretch )
        self.logN1     = logN1
        self.arcsinhN1 = arcsinhN1
        self.sigmoidN1 = sigmoidN1
        self.sigmoidN2 = sigmoidN2
    }

    /// Maps a stretch algorithm back to the control's mode, used to seed the
    /// control from an image's adjustments.
    ///
    /// - Parameter algorithm: The stretch algorithm, or `nil` for a linear image.
    /// - Returns: The corresponding mode.
    static func mode( _ algorithm: Processors.Stretch.Algorithm? ) -> Mode
    {
        guard let algorithm
        else
        {
            return .none
        }

        switch algorithm
        {
            case .log:        return .log
            case .arcsinh:    return .arcsinh
            case .sigmoid:    return .sigmoid
            @unknown default: return .none
        }
    }

    /// Maps the control's selection and slider values to a stretch algorithm.
    ///
    /// - Parameters:
    ///   - mode:            The selected stretch mode.
    ///   - logIntensity:    The logarithmic intensity value.
    ///   - arcsinhFactor:   The arcsinh factor value.
    ///   - sigmoidMidpoint: The sigmoid midpoint value.
    ///   - sigmoidContrast: The sigmoid contrast value.
    /// - Returns: The corresponding algorithm, or `nil` for `.none`.
    static func algorithm( mode: Mode, logIntensity: Double, arcsinhFactor: Double, sigmoidMidpoint: Double, sigmoidContrast: Double ) -> Processors.Stretch.Algorithm?
    {
        switch mode
        {
            case .none:    return nil
            case .log:     return .log( logIntensity )
            case .arcsinh: return .arcsinh( arcsinhFactor )
            case .sigmoid: return .sigmoid( sigmoidMidpoint, sigmoidContrast )
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
                .accessibilityIdentifier( AccessibilityIdentifier.StretchControlView.modePicker )
            }

            if self.mode == .log
            {
                SliderGridRowView( value: $logN1, minimumValue: 0, maximumValue: 255, label: "Intensity", image: "n.circle.fill" )
                    .accessibilityIdentifier( AccessibilityIdentifier.StretchControlView.intensitySlider )
            }

            if self.mode == .arcsinh
            {
                SliderGridRowView( value: $arcsinhN1, minimumValue: 0, maximumValue: 255, label: "Factor", image: "n.circle.fill" )
                    .accessibilityIdentifier( AccessibilityIdentifier.StretchControlView.factorSlider )
            }

            if self.mode == .sigmoid
            {
                SliderGridRowView( value: $sigmoidN1, minimumValue: 0, maximumValue: 255, label: "Midpoint", image: "n.circle.fill" )
                    .accessibilityIdentifier( AccessibilityIdentifier.StretchControlView.midpointSlider )
                SliderGridRowView( value: $sigmoidN2, minimumValue: 0, maximumValue: 255, label: "Contrast", image: "n.circle.fill" )
                    .accessibilityIdentifier( AccessibilityIdentifier.StretchControlView.contrastSlider )
            }
        }
        .onChange( of: self.stretchAlgorithm )
        {
            self.adjustments.stretch = self.stretchAlgorithm

            self.reRender()
        }
    }

    /// The stretch algorithm derived from the current mode and slider values.
    private var stretchAlgorithm: Processors.Stretch.Algorithm?
    {
        Self.algorithm(
            mode:            self.mode,
            logIntensity:    self.logN1,
            arcsinhFactor:   self.arcsinhN1,
            sigmoidMidpoint: self.sigmoidN1,
            sigmoidContrast: self.sigmoidN2
        )
    }
}

#Preview
{
    StretchControlView( adjustments: ImageAdjustments(), reRender: {} )
        .frame( maxWidth: .infinity, alignment: .leading )
        .frame( maxHeight: .infinity, alignment: .top )
        .padding()
}
