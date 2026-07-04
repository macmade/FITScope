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

/// A switch-style toggle drawn entirely in SwiftUI, matching the app's custom
/// ``Slider``: a capsule track with a sliding knob, at the same size and with the
/// same track, border, fill and knob styling — effectively a two-position slider
/// resting at its minimum when off and its maximum when on.
///
/// It exists to sidestep a known AppKit rendering bug: a `SwitchToggleStyle`
/// toggle recreated inside a scroll view (as happens when the inspector is rebuilt
/// on a selection change) can appear without its track until a layout pass — it
/// draws only after the switch is first toggled. Drawing the control ourselves
/// avoids that entirely, so it renders correctly the moment it appears.
public struct CapsuleToggleStyle: ToggleStyle
{
    /// Creates the toggle style.
    public init() {}

    /// Builds the toggle: its label, then the capsule track and sliding knob.
    ///
    /// - Parameter configuration: The toggle's label and on/off binding.
    public func makeBody( configuration: Configuration ) -> some View
    {
        CapsuleToggle( configuration: configuration )
    }
}

/// The view backing ``CapsuleToggleStyle``, split out so it can read the
/// environment's enabled state to dim like the custom ``Slider`` does.
private struct CapsuleToggle: View
{
    /// The styled toggle's label and on/off binding.
    let configuration: ToggleStyleConfiguration

    /// Whether the toggle is enabled, so it can dim when not.
    @Environment( \.isEnabled ) private var isEnabled

    /// The active appearance, so the fill and knob can be white on the dark track
    /// but a dark gray on the light one, where white would wash out.
    @Environment( \.colorScheme ) private var colorScheme

    /// The track width — a switch's proportions at the slider's height.
    private let width: CGFloat = 42

    /// The track height, matching the custom ``Slider``.
    private let height: CGFloat = 20

    /// The view's content: the label pushed apart from the trailing switch.
    var body: some View
    {
        HStack( spacing: 8 )
        {
            self.configuration.label

            self.track
                .frame( width: self.width, height: self.height )
                .opacity( self.isEnabled ? 1 : 0.5 )
        }
        // The whole row toggles, not just the track, so clicking the label works
        // too — matching a native `Toggle`. Tapping only the track left labelled
        // toggles (e.g. Curves' "Per-channel") unresponsive over their label.
        .contentShape( Rectangle() )
        .onTapGesture { self.configuration.isOn.toggle() }
    }

    /// The switch itself: the ``Slider``'s track, fill and knob, with the knob
    /// pinned to the leading edge when off and the trailing edge when on.
    ///
    /// The switch is a fixed size, so the knob's position is computed from that
    /// size rather than from a `GeometryReader` — the latter is re-measured when
    /// the surrounding layout changes (e.g. the editors reveal their channel picker
    /// on the same toggle), which made the knob jump.
    private var track: some View
    {
        let knobSize  = self.height
        let offset    = self.configuration.isOn ? self.width - knobSize : 0
        let fillWidth = offset + knobSize
        let fillColor = self.isEnabled ? CustomControlChrome.fill( for: self.colorScheme ) : Color.gray.opacity( 0.3 )
        let knobColor = self.isEnabled ? CustomControlChrome.knob : Color.gray.opacity( 0.6 )

        return ZStack( alignment: .leading )
        {
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
                .offset( x: offset )
        }
        // No animation on the switch: the editors reveal their channel picker on
        // the same toggle, which re-lays out the content-sized window. An animation
        // here interpolates the switch through the transient position that reflow
        // proposes, which reads as the switch jumping. Snapping avoids it entirely.
        .animation( nil, value: self.configuration.isOn )
    }
}

#Preview
{
    struct Demo: View
    {
        @State private var on  = true
        @State private var off = false

        var body: some View
        {
            VStack( alignment: .leading, spacing: 12 )
            {
                Toggle( "Invert", isOn: self.$on )
                    .toggleStyle( CapsuleToggleStyle() )

                Toggle( "Invert", isOn: self.$off )
                    .toggleStyle( CapsuleToggleStyle() )

                Toggle( "Disabled", isOn: self.$on )
                    .toggleStyle( CapsuleToggleStyle() )
                    .disabled( true )
            }
            .frame( width: 220 )
            .padding()
        }
    }

    return Demo()
}
