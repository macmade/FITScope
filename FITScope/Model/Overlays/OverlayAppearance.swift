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
import SwiftUI

/// The user-configurable appearance of a canvas annotation overlay: a base colour
/// plus one or two opacity tiers.
///
/// The colour is kept as sRGB components in `0...1` rather than a `Color`, so an
/// appearance round-trips cleanly through `UserDefaults` and is directly testable.
/// Most overlays draw a single tier at ``opacity``; the equatorial grid — the only
/// one with ``OverlayKind/hasSecondaryTier`` — draws its faint lines at
/// ``secondaryOpacity`` beneath its brighter labels (at ``opacity``).
/// ``secondaryOpacity`` is ignored by overlays without a secondary tier.
public struct OverlayAppearance: Equatable, Sendable
{
    /// The base colour's red component, in `0...1` (sRGB).
    public var red: Double

    /// The base colour's green component, in `0...1` (sRGB).
    public var green: Double

    /// The base colour's blue component, in `0...1` (sRGB).
    public var blue: Double

    /// The primary opacity, in `0...1` — the stroke opacity for most overlays, and
    /// the label opacity for the equatorial grid.
    public var opacity: Double

    /// The secondary opacity, in `0...1` — the line opacity for the equatorial
    /// grid. Ignored by overlays without a secondary tier.
    public var secondaryOpacity: Double

    /// Creates an appearance from raw sRGB components and opacities. Every value is
    /// clamped into `0...1`, so a stale or corrupt stored value can never produce
    /// an invalid colour.
    ///
    /// - Parameters:
    ///   - red:              The red component.
    ///   - green:            The green component.
    ///   - blue:             The blue component.
    ///   - opacity:          The primary opacity.
    ///   - secondaryOpacity: The secondary opacity.
    public init( red: Double, green: Double, blue: Double, opacity: Double, secondaryOpacity: Double )
    {
        self.red              = Self.clamped( red )
        self.green            = Self.clamped( green )
        self.blue             = Self.clamped( blue )
        self.opacity          = Self.clamped( opacity )
        self.secondaryOpacity = Self.clamped( secondaryOpacity )
    }

    /// Creates an appearance from a `Color`, extracting its sRGB components so the
    /// colour is stored as persistable numbers.
    ///
    /// - Parameters:
    ///   - color:            The base colour.
    ///   - opacity:          The primary opacity.
    ///   - secondaryOpacity: The secondary opacity.
    public init( color: Color, opacity: Double, secondaryOpacity: Double )
    {
        self.init( red: 0, green: 0, blue: 0, opacity: opacity, secondaryOpacity: secondaryOpacity )

        self.color = color
    }

    /// The opaque base colour. Getting it rebuilds the colour from the stored sRGB
    /// components; setting it extracts and stores the new colour's components (a
    /// no-op if the colour cannot be resolved in sRGB), so a colour picker can bind
    /// straight to it.
    public var color: Color
    {
        get
        {
            Color( .sRGB, red: self.red, green: self.green, blue: self.blue, opacity: 1 )
        }
        set
        {
            guard let native = NSColor( newValue ).usingColorSpace( .sRGB )
            else
            {
                return
            }

            self.red   = Self.clamped( Double( native.redComponent ) )
            self.green = Self.clamped( Double( native.greenComponent ) )
            self.blue  = Self.clamped( Double( native.blueComponent ) )
        }
    }

    /// The base colour at the primary opacity — the stroke colour for most
    /// overlays, and the label colour for the equatorial grid.
    public var primaryColor: Color
    {
        self.color.opacity( self.opacity )
    }

    /// The base colour at the secondary opacity — the equatorial grid's line
    /// colour.
    public var secondaryColor: Color
    {
        self.color.opacity( self.secondaryOpacity )
    }

    /// A value clamped into the unit range `0...1`.
    ///
    /// - Parameter value: The value to clamp.
    /// - Returns: The clamped value.
    private static func clamped( _ value: Double ) -> Double
    {
        min( max( value, 0 ), 1 )
    }
}
