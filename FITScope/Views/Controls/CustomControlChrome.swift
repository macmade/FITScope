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

/// The shared colors and chrome for the app's custom controls — the segmented
/// control, the ``Slider`` and the capsule toggle — so they present one
/// consistent, soft look and cannot drift apart. It is the single home for these
/// custom control colors.
///
/// Fixed, low-opacity `Color.primary` fills and borders are used rather than the
/// hierarchical `.quinary` / `.quaternary` styles: those are translucent and take
/// on their backdrop, so the same chrome looked soft over the vibrant sidebar but
/// hardened into a darker border in the non-vibrant inspector. Concrete opacities
/// keep the soft hairline identical wherever the control is placed, while still
/// adapting to light / dark through `Color.primary`.
public struct CustomControlChrome: ViewModifier
{
    /// The corner radius shared by the track fill and its border, so they align.
    private static let cornerRadius: CGFloat = 7

    /// The track fill opacity.
    private static let trackOpacity = 0.04

    /// The border opacity.
    private static let borderOpacity = 0.08

    /// The border width — a hairline, shared with the other custom controls.
    public static let borderWidth: CGFloat = 0.5

    /// The soft track fill shared by all custom controls.
    public static let trackFill = Color.primary.opacity( trackOpacity )

    /// The soft, backdrop-independent hairline border shared by all custom controls.
    public static let border = Color.primary.opacity( borderOpacity )

    /// The filled/active indicator of a custom control — a slider's fill up to the
    /// knob, or the capsule toggle's on-track: white on the dark appearance, a soft
    /// gray on the light one, where white would wash out.
    ///
    /// - Parameter colorScheme: The active appearance.
    /// - Returns: The indicator color.
    public static func fill( for colorScheme: ColorScheme ) -> Color
    {
        colorScheme == .dark ? Color( white: 0.90 ) : Color( white: 0.55 )
    }

    /// The knob of a custom control — white in both appearances, so it reads the
    /// same everywhere and stands out against the fill.
    public static let knob = Color.white

    /// Wraps the content in the shared track and border.
    public func body( content: Content ) -> some View
    {
        content
            .background( Self.trackFill, in: RoundedRectangle( cornerRadius: Self.cornerRadius ) )
            .overlay( RoundedRectangle( cornerRadius: Self.cornerRadius ).strokeBorder( Self.border, lineWidth: Self.borderWidth ) )
    }
}

public extension View
{
    /// Applies the shared custom-control chrome — a rounded track with a soft,
    /// backdrop-independent hairline border — so a control matches the segmented
    /// control it sits with.
    func customControlChrome() -> some View
    {
        self.modifier( CustomControlChrome() )
    }
}
