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

public struct Slider: View
{
    @Binding public var value: Double

    public let minimumValue: Double
    public let maximumValue: Double
    public let image:        String?
    public let disabled:     Bool
    public let tickCount:    Int?
    public let friction:     Double?
    public let onChange:     ( ( Double, Bool ) -> Void )?

    @State private var isDragging = false

    public init( value: Binding< Double >, minimumValue: Double, maximumValue: Double, image: String? = nil, disabled: Bool = false, tickCount: Int? = nil, friction: Double? = nil, onChange: ( ( Double, Bool ) -> Void )? = nil )
    {
        self._value       = value
        self.minimumValue = minimumValue
        self.maximumValue = maximumValue
        self.image        = image
        self.disabled     = disabled
        self.tickCount    = tickCount
        self.friction     = friction
        self.onChange     = onChange
    }

    public var body: some View
    {
        GeometryReader
        {
            geometry in

            let clampedValue = min( max( self.value, self.minimumValue ), self.maximumValue )
            let totalWidth   = geometry.size.width
            let knobSize     = geometry.size.height
            let range        = self.maximumValue - self.minimumValue
            let normalized   = ( clampedValue - self.minimumValue ) / range
            let offset       = normalized * ( totalWidth - knobSize )
            let fillWidth    = offset + knobSize
            let fillColor    = self.disabled ? Color.gray.opacity( 0.3 ) : Color.white
            let knobColor    = self.disabled ? Color.gray.opacity( 0.6 ) : Color.white
            let imageColor   = self.disabled ? Color.gray                : Color.black

            ZStack( alignment: .leading )
            {
                if let tickCount, tickCount > 1
                {
                    let spacing = ( totalWidth - knobSize ) / CGFloat( tickCount - 1 )

                    ForEach( 0 ..< tickCount, id: \.self )
                    {
                        index in

                        Rectangle()
                            .fill( self.disabled ? Color.gray.opacity( 0.5 ) : Color.secondary )
                            .frame( width: 1, height: knobSize / 3 )
                            .position(
                                x: knobSize / 2 + CGFloat( index ) * spacing,
                                y: knobSize / 2
                            )
                    }
                }

                Capsule()
                    .fill( .quinary )
                    .clipShape( RoundedRectangle( cornerRadius: 10 ) )
                    .overlay(
                        Capsule()
                            .stroke( .quaternary, lineWidth: 1 )
                    )

                Capsule()
                    .fill( fillColor )
                    .frame( width: fillWidth )

                Circle()
                    .frame( width: knobSize, height: knobSize )
                    .foregroundStyle( knobColor )
                    .shadow( radius: 2 )
                    .brightness( self.isDragging && self.disabled == false ? -0.1 : 0 )
                    .overlay
                    {
                        if let image = self.image
                        {
                            Image( systemName: image )
                                .font( .system( size: knobSize / 2 ) )
                                .foregroundStyle( imageColor )
                        }
                    }
                    .offset( x: offset )
            }
            .gesture(
                self.disabled ? nil : DragGesture( minimumDistance: 0 ).onChanged
                {
                    gesture in

                    self.isDragging = true
                    let locationX   = gesture.location.x - knobSize / 2
                    let percentage  = min( max( locationX / ( totalWidth - knobSize ), 0 ), 1 )
                    var newValue    = self.minimumValue + percentage * range

                    if let friction, let tickCount, tickCount > 1
                    {
                        let stepSize = range / Double( tickCount - 1 )

                        let nearestTick = ( round(( newValue - self.minimumValue ) / stepSize ) * stepSize ) + self.minimumValue
                        let distance = abs( newValue - nearestTick )

                        if distance < friction
                        {
                            newValue = nearestTick
                        }
                    }

                    self.value = newValue

                    self.onChange?( self.value, self.isDragging )
                }
                .onEnded
                {
                    _ in

                    self.isDragging = false

                    self.onChange?( self.value, self.isDragging )
                }
            )
            .opacity( self.disabled ? 0.5 : 1.0 )
        }
    }
}

#Preview
{
    struct Preview: View
    {
        @State public var value = 50.0

        var body: some View
        {
            VStack
            {
                Slider( value: $value, minimumValue: 0, maximumValue: 100 )
                {
                    print( "Slider value changed to \(  $0 ) - isDragging: \(  $1  )" )
                }
                .frame( width: 200, height: 20 )

                Slider( value: $value, minimumValue: 0, maximumValue: 100, image: "circle.lefthalf.filled", tickCount: 11, friction: 1.5 )
                    .frame( width: 200, height: 20 )

                Slider( value: $value, minimumValue: 0, maximumValue: 100, image: "circle.lefthalf.filled", disabled: true, tickCount: 11, friction: 1.5 )
                    .frame( width: 200, height: 20 )
            }
            .padding()
        }
    }

    return Preview()
}
