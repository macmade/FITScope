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

/// A custom horizontal slider with an optional knob glyph, tick marks and
/// magnetic snapping.
///
/// Dragging reports both the value and whether a drag is in progress through
/// ``onChange``, letting callers distinguish a live drag from its end. When
/// ticks and a friction radius are supplied, values near a tick snap to it.
public struct Slider: View
{
    /// The bound value, kept within ``minimumValue``…``maximumValue``.
    @Binding public var value: Double

    /// The lower bound of the value range.
    public let minimumValue: Double

    /// The upper bound of the value range.
    public let maximumValue: Double

    /// An optional SF Symbol drawn inside the knob.
    public let image: String?

    /// Whether the slider is disabled (dimmed and non-interactive).
    public let disabled: Bool

    /// The number of evenly spaced tick marks, or `nil` for none.
    public let tickCount: Int?

    /// The snapping radius around each tick, or `nil` for no snapping.
    public let friction: Double?

    /// Called with the new value and the drag state on every change.
    public let onChange: ( ( Double, Bool ) -> Void )?

    /// Whether a drag is currently in progress, used for the knob's press
    /// styling.
    @State private var isDragging = false

    /// The active appearance, so the fill and knob can be white on the dark track
    /// but a dark gray on the light one, where white would wash out.
    @Environment( \.colorScheme ) private var colorScheme

    /// Whether the surrounding context is enabled, so the slider also dims and stops
    /// responding when a parent applies `.disabled(…)` — matching the capsule toggle,
    /// which reacts to the same environment rather than only an explicit flag.
    @Environment( \.isEnabled ) private var isEnabled

    /// Creates a slider.
    ///
    /// - Parameters:
    ///   - value:        A binding to the value.
    ///   - minimumValue: The lower bound.
    ///   - maximumValue: The upper bound.
    ///   - image:        An optional SF Symbol for the knob.
    ///   - disabled:     Whether the slider is disabled.
    ///   - tickCount:    The number of tick marks, or `nil`.
    ///   - friction:     The snapping radius around ticks, or `nil`.
    ///   - onChange:     A closure run with the value and drag state on change.
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

    /// The knob's normalized position in `0...1` for `value` within the bounds.
    ///
    /// Equal bounds give a zero range; the position pins to `0` rather than
    /// dividing into `NaN`, which would leave the knob unplaceable.
    static func normalizedPosition( value: Double, minimumValue: Double, maximumValue: Double ) -> Double
    {
        let range = maximumValue - minimumValue

        guard range > 0
        else
        {
            return 0
        }

        let clamped = min( max( value, minimumValue ), maximumValue )

        return ( clamped - minimumValue ) / range
    }

    /// The view's content.
    public var body: some View
    {
        GeometryReader
        {
            geometry in

            let totalWidth   = geometry.size.width
            let knobSize     = geometry.size.height
            let range        = self.maximumValue - self.minimumValue
            let normalized   = Self.normalizedPosition( value: self.value, minimumValue: self.minimumValue, maximumValue: self.maximumValue )
            let offset       = normalized * ( totalWidth - knobSize )
            let fillWidth    = offset + knobSize
            // Disabled either explicitly or by a `.disabled(…)` ancestor.
            let isDisabled   = self.disabled || self.isEnabled == false
            let fillColor    = isDisabled ? Color.gray.opacity( 0.3 ) : CustomControlChrome.fill( for: self.colorScheme )
            let knobColor    = isDisabled ? Color.gray.opacity( 0.6 ) : CustomControlChrome.knob
            let imageColor   = isDisabled ? Color.gray                : Color.black

            ZStack( alignment: .leading )
            {
                if let tickCount, tickCount > 1
                {
                    let spacing = ( totalWidth - knobSize ) / CGFloat( tickCount - 1 )

                    ForEach( 0 ..< tickCount, id: \.self )
                    {
                        index in

                        Rectangle()
                            .fill( isDisabled ? Color.gray.opacity( 0.5 ) : Color.secondary )
                            .frame( width: 1, height: knobSize / 3 )
                            .position(
                                x: knobSize / 2 + CGFloat( index ) * spacing,
                                y: knobSize / 2
                            )
                    }
                }

                Capsule()
                    .fill( CustomControlChrome.trackFill )
                    .clipShape( RoundedRectangle( cornerRadius: 10 ) )
                    .overlay(
                        Capsule()
                            .strokeBorder( CustomControlChrome.border, lineWidth: CustomControlChrome.borderWidth )
                    )

                Capsule()
                    .fill( fillColor )
                    .frame( width: fillWidth )

                Circle()
                    .frame( width: knobSize, height: knobSize )
                    .foregroundStyle( knobColor )
                    .shadow( radius: 2 )
                    .brightness( self.isDragging && isDisabled == false ? -0.1 : 0 )
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
                isDisabled ? nil : DragGesture( minimumDistance: 0 ).onChanged
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
            .opacity( isDisabled ? 0.5 : 1.0 )
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
