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

public struct SliderGridRowView: View
{
    @Binding public var value: Double

    public let minimumValue: Double
    public let maximumValue: Double
    public let label:        String?
    public let image:        String?
    public let sliderHeight: Double
    public let disabled:     Bool
    public let tickCount:    Int?
    public let friction:     Double?

    public let onChange: ( ( Double, Bool ) -> Void )?

    @State public private( set ) var isDragging = false

    public init( value: Binding< Double >, minimumValue: Double, maximumValue: Double, label: String?, image: String? = nil, sliderHeight: Double = 20, disabled: Bool = false, tickCount: Int? = nil, friction: Double? = nil, onChange: (( Double, Bool ) -> Void )? = nil )
    {
        self._value       = value
        self.minimumValue = minimumValue
        self.maximumValue = maximumValue
        self.label        = label
        self.image        = image
        self.sliderHeight = sliderHeight
        self.disabled     = disabled
        self.tickCount    = tickCount
        self.friction     = friction
        self.onChange     = onChange
    }

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

            Text( String( format: "%.2f", self.value ) )
                .frame( minWidth: 50 )
        }
        .onChange( of: self.value )
        {
            _, _ in
        }
    }
}

#Preview
{
    struct Preview: View
    {
        @State private var value = 50.0

        var body: some View
        {
            Grid( alignment: .leading )
            {
                SliderGridRowView( value: $value, minimumValue: 0, maximumValue: 100, label: "Lorem Ipsum" )
                SliderGridRowView( value: $value, minimumValue: 0, maximumValue: 100, label: "Dolor Sit Amet" )
            }
            .padding()
        }
    }

    return Preview()
}
