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

import AppKit

/// The accent-derived colours for placeholder pills, shared by the palette pills
/// and the inline editor pills.
///
/// In light mode the colours are the plain control accent. In dark mode the
/// accent is **desaturated**, because the fully-saturated accent reads as too
/// vivid/bright there. The colours are dynamic `NSColor`s, so they resolve to the
/// right variant for whatever appearance draws them.
enum PillTint
{
    /// The pill text / keyword foreground colour.
    static let foreground = NSColor( name: nil )
    {
        appearance in Self.tint( for: appearance )
    }

    /// The pill background colour: the tint at a low opacity.
    static let background = NSColor( name: nil )
    {
        appearance in Self.tint( for: appearance ).withAlphaComponent( 0.18 )
    }

    /// The accent tint for an appearance — plain in light mode, desaturated in
    /// dark mode.
    ///
    /// - Parameter appearance: The appearance being drawn.
    /// - Returns: The tint colour.
    private static func tint( for appearance: NSAppearance ) -> NSColor
    {
        let isDark = appearance.bestMatch( from: [ .aqua, .darkAqua ] ) == .darkAqua
        let accent = NSColor.controlAccentColor

        guard isDark, let rgb = accent.usingColorSpace( .deviceRGB )
        else
        {
            return accent
        }

        var hue        = CGFloat( 0 )
        var saturation = CGFloat( 0 )
        var brightness = CGFloat( 0 )
        var alpha      = CGFloat( 0 )

        rgb.getHue( &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha )

        return NSColor( hue: hue, saturation: saturation * 0.55, brightness: brightness, alpha: alpha )
    }
}
