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

/// The white-balance section of the controls panel: a mode picker plus, in
/// manual mode, per-channel gain sliders.
public struct WhiteBalanceControlView: View
{
    /// The white-balance choices offered by the picker.
    public enum Mode: CaseIterable, CustomStringConvertible
    {
        /// No white balancing.
        case none

        /// Automatic, channel-equalizing white balance.
        case auto

        /// Manual per-channel gains.
        case manual

        /// The picker label for the mode.
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

    /// The shared adjustment values this control writes to.
    private let adjustments: ImageAdjustments

    /// Requests a debounced re-render after a change.
    private let reRender:    () -> Void

    /// The selected white-balance mode. `.none` by default, so the channels
    /// open untouched.
    @State private var mode  = Mode.none

    /// The manual red-channel gain.
    @State private var red   = WhiteBalanceControlView.defaultManualGain

    /// The manual green-channel gain.
    @State private var green = WhiteBalanceControlView.defaultManualGain

    /// The manual blue-channel gain.
    @State private var blue  = WhiteBalanceControlView.defaultManualGain

    /// Creates the white-balance control.
    ///
    /// - Parameters:
    ///   - adjustments: The shared adjustment values to write to.
    ///   - reRender:    The closure to call after a change.
    public init( adjustments: ImageAdjustments, reRender: @escaping () -> Void )
    {
        self.adjustments = adjustments
        self.reRender    = reRender
    }

    /// Maps the control's selection and slider values to a white-balance mode.
    ///
    /// - Parameters:
    ///   - mode:  The selected white-balance mode.
    ///   - red:   The manual red gain.
    ///   - green: The manual green gain.
    ///   - blue:  The manual blue gain.
    /// - Returns: The corresponding mode, or `nil` for `.none`.
    static func mode( _ mode: Mode, red: Double, green: Double, blue: Double ) -> Processors.WhiteBalance.Mode?
    {
        switch mode
        {
            case .none:   return nil
            case .auto:   return .auto
            case .manual: return .manual( red: red, green: green, blue: blue )
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
                .accessibilityIdentifier( AccessibilityIdentifier.WhiteBalanceControlView.modePicker )
            }

            if self.mode == .manual
            {
                SliderGridRowView( value: $red,   minimumValue: 0, maximumValue: 255, label: "Red",   image: "r.circle.fill" )
                    .accessibilityIdentifier( AccessibilityIdentifier.WhiteBalanceControlView.redSlider )
                SliderGridRowView( value: $green, minimumValue: 0, maximumValue: 255, label: "Green", image: "g.circle.fill" )
                    .accessibilityIdentifier( AccessibilityIdentifier.WhiteBalanceControlView.greenSlider )
                SliderGridRowView( value: $blue,  minimumValue: 0, maximumValue: 255, label: "Blue",  image: "b.circle.fill" )
                    .accessibilityIdentifier( AccessibilityIdentifier.WhiteBalanceControlView.blueSlider )
            }
        }
        .onChange( of: self.whiteBalanceMode )
        {
            self.adjustments.whiteBalance = self.whiteBalanceMode

            self.reRender()
        }
    }

    /// The white-balance mode derived from the current selection and gains.
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
