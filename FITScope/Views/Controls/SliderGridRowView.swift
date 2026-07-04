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

/// A `GridRow` laying out an optional leading label, a ``Slider`` and a
/// trailing value readout, for use inside a `Grid` of adjustment sliders.
public struct SliderGridRowView: View
{
    /// The bound value passed through to the slider.
    @Binding public var value: Double

    /// The lower bound of the value range.
    public let minimumValue: Double

    /// The upper bound of the value range.
    public let maximumValue: Double

    /// The leading label, or `nil` to omit the label column.
    public let label: String?

    /// An optional SF Symbol drawn inside the knob.
    public let image: String?

    /// The height of the embedded slider.
    public let sliderHeight: Double

    /// Whether the row is disabled.
    public let disabled: Bool

    /// The number of tick marks, or `nil` for none.
    public let tickCount: Int?

    /// The snapping radius around ticks, or `nil` for no snapping.
    public let friction: Double?

    /// Called with the new value and drag state on every change.
    public let onChange: ( ( Double, Bool ) -> Void )?

    /// The value the reset affordance restores, or `nil` to omit the affordance.
    /// When set, a reset button appears beside the readout while ``value`` differs
    /// from it, and pressing it writes this value back through ``value``.
    public let defaultValue: Double?

    /// The accessibility identifier for the reset button, or `nil` to leave it
    /// unidentified.
    public let resetIdentifier: String?

    /// Whether a drag is currently in progress.
    @State public private( set ) var isDragging = false

    /// Creates a slider row.
    ///
    /// - Parameters:
    ///   - value:           A binding to the value.
    ///   - minimumValue:    The lower bound.
    ///   - maximumValue:    The upper bound.
    ///   - label:           The leading label, or `nil` to omit it.
    ///   - image:           An optional SF Symbol for the knob.
    ///   - sliderHeight:    The slider's height; defaults to `20`.
    ///   - disabled:        Whether the row is disabled.
    ///   - tickCount:       The number of tick marks, or `nil`.
    ///   - friction:        The snapping radius around ticks, or `nil`.
    ///   - defaultValue:    The value the reset affordance restores, or `nil` to
    ///                      omit it.
    ///   - resetIdentifier: The reset button's accessibility identifier, or `nil`.
    ///   - onChange:        A closure run with the value and drag state on change.
    public init( value: Binding< Double >, minimumValue: Double, maximumValue: Double, label: String?, image: String? = nil, sliderHeight: Double = 20, disabled: Bool = false, tickCount: Int? = nil, friction: Double? = nil, defaultValue: Double? = nil, resetIdentifier: String? = nil, onChange: (( Double, Bool ) -> Void )? = nil )
    {
        self._value          = value
        self.minimumValue    = minimumValue
        self.maximumValue    = maximumValue
        self.label           = label
        self.image           = image
        self.sliderHeight    = sliderHeight
        self.disabled        = disabled
        self.tickCount       = tickCount
        self.friction        = friction
        self.defaultValue    = defaultValue
        self.resetIdentifier = resetIdentifier
        self.onChange        = onChange
    }

    /// The view's content.
    public var body: some View
    {
        GridRow
        {
            if let label = label
            {
                Text( label )
            }

            Slider( value: $value, minimumValue: self.minimumValue, maximumValue: self.maximumValue, image: self.image, disabled: self.disabled, tickCount: self.tickCount, friction: self.friction, onChange: self.onChange )
                .frame( height: self.sliderHeight )

            self.readout
        }
    }

    /// The trailing value readout, with a reset button beside it when the row has
    /// a ``defaultValue`` and the current value differs from it.
    @ViewBuilder private var readout: some View
    {
        if let defaultValue = self.defaultValue
        {
            HStack( spacing: 6 )
            {
                Text( String( format: "%.2f", self.value ) )
                    .frame( minWidth: 50 )

                // Reserve the reset button's width whether or not it is shown, so
                // the row does not shift sideways as the value crosses its default.
                ZStack
                {
                    if self.value != defaultValue
                    {
                        self.resetButton( defaultValue: defaultValue )
                    }
                }
                .frame( width: 18 )
            }
        }
        else
        {
            Text( String( format: "%.2f", self.value ) )
                .frame( minWidth: 50 )
        }
    }

    /// The reset button restoring ``value`` to `defaultValue`, carrying the
    /// row's ``resetIdentifier`` when one was supplied.
    @ViewBuilder
    private func resetButton( defaultValue: Double ) -> some View
    {
        let button = ResetButton { self.value = defaultValue }

        if let resetIdentifier = self.resetIdentifier
        {
            button.accessibilityIdentifier( resetIdentifier )
        }
        else
        {
            button
        }
    }
}

#Preview
{
    struct Preview: View
    {
        @State private var plain     = 50.0
        @State private var modified  = 70.0
        @State private var atDefault = 50.0

        var body: some View
        {
            Grid( alignment: .leading )
            {
                // No reset affordance.
                SliderGridRowView( value: $plain, minimumValue: 0, maximumValue: 100, label: "No Reset" )

                // A reset button shows because the value differs from its default.
                SliderGridRowView( value: $modified, minimumValue: 0, maximumValue: 100, label: "Modified", defaultValue: 50 )

                // The reset space is reserved but the button is hidden at default.
                SliderGridRowView( value: $atDefault, minimumValue: 0, maximumValue: 100, label: "At Default", defaultValue: 50 )
            }
            .padding()
        }
    }

    return Preview()
}
