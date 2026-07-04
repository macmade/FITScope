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

/// The colour-balance section of the controls panel: a segmented Shadows /
/// Midtones / Highlights picker over three complementary-pair sliders that
/// shift the channels toward cyan/red, magenta/green and yellow/blue. Only the
/// selected range's sliders are shown, to stay compact; the other ranges keep
/// their values. Shown only for colour images (see ``InspectorView``).
public struct ColorBalanceControlView: View
{
    /// The slider bounds: neutral at `0`, `−1` fully toward the complement
    /// (cyan/magenta/yellow) and `+1` fully toward the primary (red/green/blue).
    static let minimumShift = -1.0
    static let maximumShift =  1.0

    /// A tonal range, selected by the segmented control.
    private enum TonalRange: String, CaseIterable
    {
        case shadows    = "Shadows"
        case midtones   = "Midtones"
        case highlights = "Highlights"
    }

    /// The shared adjustment values this control observes and writes to.
    @ObservedObject private var adjustments: ImageAdjustments

    /// Requests a debounced re-render after a change.
    private let reRender: () -> Void

    /// The tonal range whose sliders are shown; the other ranges keep their
    /// values while hidden. Defaults to the midtones, the most commonly graded.
    @State private var range: TonalRange = .midtones

    /// Creates the colour-balance control.
    ///
    /// - Parameters:
    ///   - adjustments: The shared adjustment values to observe and write to.
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
            SegmentedControlView( selection: self.$range, values: TonalRange.allCases, title: { $0.rawValue } )
                .accessibilityIdentifier( AccessibilityIdentifier.ColorBalanceControlView.rangePicker )

            Grid( alignment: .leading )
            {
                SliderGridRowView( value: self.shift.red,   minimumValue: Self.minimumShift, maximumValue: Self.maximumShift, label: "Cyan\u{2013}Red",      defaultValue: 0 )
                SliderGridRowView( value: self.shift.green, minimumValue: Self.minimumShift, maximumValue: Self.maximumShift, label: "Magenta\u{2013}Green", defaultValue: 0 )
                SliderGridRowView( value: self.shift.blue,  minimumValue: Self.minimumShift, maximumValue: Self.maximumShift, label: "Yellow\u{2013}Blue",   defaultValue: 0 )
            }
        }
        // The sliders write nested components of the observed balance, so
        // re-render on any change to it — from a slider or from a Reset.
        .onChange( of: self.adjustments.colorBalance )
        {
            self.reRender()
        }
    }

    /// A binding to the currently-selected range's per-channel shift, so the
    /// three sliders drive whichever range the picker has chosen.
    private var shift: Binding< Processors.ColorBalance.Shift >
    {
        switch self.range
        {
            case .shadows:    self.$adjustments.colorBalance.shadows
            case .midtones:   self.$adjustments.colorBalance.midtones
            case .highlights: self.$adjustments.colorBalance.highlights
        }
    }
}

#Preview( "Default" )
{
    ColorBalanceControlView( adjustments: ImageAdjustments(), reRender: {} )
        .frame( maxWidth: .infinity, alignment: .leading )
        .frame( maxHeight: .infinity, alignment: .top )
        .padding()
}

#Preview( "Modified" )
{
    let adjustments = ImageAdjustments()

    adjustments.colorBalance = .init( shadows: .init( red: 0.3 ), midtones: .init( green: -0.2 ), highlights: .init( blue: 0.4 ) )

    return ColorBalanceControlView( adjustments: adjustments, reRender: {} )
        .frame( maxWidth: .infinity, alignment: .leading )
        .frame( maxHeight: .infinity, alignment: .top )
        .padding()
}
