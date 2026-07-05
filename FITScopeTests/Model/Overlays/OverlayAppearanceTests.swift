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

@testable import FITScope
import SwiftUI
import Testing

/// Tests for ``OverlayAppearance``: the user-configurable colour and opacity of a
/// canvas overlay. The colour is stored as sRGB components so it round-trips
/// through `UserDefaults`; the tests pin that round-trip, the `Color` bridge, and
/// the derived tier colours.
@Suite( "OverlayAppearance" )
struct OverlayAppearanceTests
{
    /// The tolerance for a colour-component comparison, since the `Color` ⇄ sRGB
    /// bridge is not bit-exact.
    private static let tolerance = 1e-3

    /// The stored components are surfaced back through ``OverlayAppearance/color``
    /// unchanged, so an appearance persisted as numbers rebuilds the same colour.
    @Test
    func exposesItsStoredComponentsAsAnOpaqueColor() throws
    {
        let appearance = OverlayAppearance( red: 0.2, green: 0.4, blue: 0.6, opacity: 0.5, secondaryOpacity: 0.25 )
        let components = try Self.components( of: appearance.color )

        #expect( abs( components.red   - 0.2 ) < Self.tolerance )
        #expect( abs( components.green - 0.4 ) < Self.tolerance )
        #expect( abs( components.blue  - 0.6 ) < Self.tolerance )
    }

    /// Building an appearance from a `Color` extracts its sRGB components, so a
    /// colour picked in the UI is stored as persistable numbers.
    @Test
    func extractsComponentsWhenBuiltFromAColor()
    {
        let appearance = OverlayAppearance( color: Color( .sRGB, red: 0.1, green: 0.7, blue: 0.3 ), opacity: 0.7, secondaryOpacity: 0.7 )

        #expect( abs( appearance.red   - 0.1 ) < Self.tolerance )
        #expect( abs( appearance.green - 0.7 ) < Self.tolerance )
        #expect( abs( appearance.blue  - 0.3 ) < Self.tolerance )
    }

    /// Assigning a new colour updates the stored components, so binding the UI's
    /// colour picker to ``OverlayAppearance/color`` persists the change.
    @Test
    func updatesComponentsWhenTheColorIsAssigned()
    {
        var appearance = OverlayAppearance( red: 0, green: 0, blue: 0, opacity: 0.7, secondaryOpacity: 0.7 )

        appearance.color = Color( .sRGB, red: 0.8, green: 0.2, blue: 0.5 )

        #expect( abs( appearance.red   - 0.8 ) < Self.tolerance )
        #expect( abs( appearance.green - 0.2 ) < Self.tolerance )
        #expect( abs( appearance.blue  - 0.5 ) < Self.tolerance )
    }

    /// Out-of-range components and opacities are clamped to `0...1`, so a stale or
    /// corrupt stored value can never produce an invalid colour.
    @Test
    func clampsComponentsAndOpacitiesIntoTheUnitRange()
    {
        let appearance = OverlayAppearance( red: -1, green: 2, blue: 0.5, opacity: 1.5, secondaryOpacity: -0.2 )

        #expect( appearance.red              == 0 )
        #expect( appearance.green            == 1 )
        #expect( appearance.blue             == 0.5 )
        #expect( appearance.opacity          == 1 )
        #expect( appearance.secondaryOpacity == 0 )
    }

    /// Two appearances with the same components and opacities are equal, which the
    /// Preferences UI relies on to decide whether an overlay differs from its
    /// default.
    @Test
    func isEquatableByComponentsAndOpacities()
    {
        let a = OverlayAppearance( red: 0.2, green: 0.4, blue: 0.6, opacity: 0.7, secondaryOpacity: 0.3 )
        let b = OverlayAppearance( red: 0.2, green: 0.4, blue: 0.6, opacity: 0.7, secondaryOpacity: 0.3 )
        let c = OverlayAppearance( red: 0.2, green: 0.4, blue: 0.6, opacity: 0.5, secondaryOpacity: 0.3 )

        #expect( a == b )
        #expect( a != c )
    }

    /// Extracts the sRGB components of a `Color` for a test assertion, failing the
    /// test if the conversion is unavailable.
    ///
    /// - Parameter color: The colour to inspect.
    /// - Returns: Its red, green, and blue components in `0...1`.
    private static func components( of color: Color ) throws -> ( red: Double, green: Double, blue: Double )
    {
        let native = try #require( NSColor( color ).usingColorSpace( .sRGB ) )

        return ( Double( native.redComponent ), Double( native.greenComponent ), Double( native.blueComponent ) )
    }
}
