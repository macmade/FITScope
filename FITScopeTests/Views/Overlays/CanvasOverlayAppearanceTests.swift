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
import Testing

/// Tests for the overlays' self-declared appearance metadata and the
/// ``CanvasOverlayCatalog`` that lists them. Each overlay owns its default
/// appearance and opacity channels; these tests pin those declarations and the
/// "matches today's look" defaults, replacing the old central-enum approach.
@Suite( "CanvasOverlay appearance" )
@MainActor
struct CanvasOverlayAppearanceTests
{
    /// The catalog lists exactly the six annotation overlays, with unique
    /// identifiers.
    @Test
    func catalogCoversEveryOverlayWithUniqueIdentifiers()
    {
        let ids = CanvasOverlayCatalog.all.map { $0.id }

        #expect( ids.count == 6 )
        #expect( Set( ids ).count == 6 )
    }

    /// Each overlay's instance identifier matches the static one used to key its
    /// stored appearance, guarding the two from drifting apart.
    @Test
    func instanceAndStaticIdentifiersAgree()
    {
        #expect( ReticleOverlay().id         == ReticleOverlay.identifier )
        #expect( StarsOverlay( stars: [] ).id == StarsOverlay.identifier )
        #expect( ObjectsOverlay( annotations: [] ).id == ObjectsOverlay.identifier )
        #expect( ScaleBarOverlay( pixelScale: nil ).id == ScaleBarOverlay.identifier )
        #expect( NorthOverlay( wcs: nil ).id  == NorthOverlay.identifier )
        #expect( EquatorialGridOverlay( wcs: nil ).id == EquatorialGridOverlay.identifier )
    }

    /// Every overlay defaults its primary opacity to the shared alpha, so
    /// customisation starts from exactly today's look.
    @Test
    func everyOverlayDefaultsToTheSharedPrimaryAlpha()
    {
        #expect( CanvasOverlayCatalog.all.allSatisfy { type( of: $0 ).defaultAppearance.opacity == CanvasOverlayStyle.alpha } )
    }

    /// A single-tier overlay exposes exactly one opacity channel — its stroke
    /// opacity.
    @Test
    func singleTierOverlayExposesOneOpacityChannel()
    {
        let channels = ReticleOverlay.opacityChannels

        #expect( channels.count == 1 )
        #expect( channels.first?.label == "Opacity" )
        #expect( channels.first?.keyPath == \OverlayAppearance.opacity )
    }

    /// The equatorial grid declares its own two opacity channels — its labels and
    /// its fainter lines — mapping to the primary and secondary opacities, so its
    /// two-tier nature lives on the overlay rather than in any generic catalog.
    @Test
    func gridDeclaresTwoOpacityChannels()
    {
        let channels = EquatorialGridOverlay.opacityChannels

        #expect( channels.count == 2 )
        #expect( channels.map { $0.label } == [ "Labels", "Lines" ] )
        #expect( channels[ 0 ].keyPath == \OverlayAppearance.opacity )
        #expect( channels[ 1 ].keyPath == \OverlayAppearance.secondaryOpacity )
    }

    /// The grid's default line opacity is the shared secondary alpha, keeping its
    /// lines fainter than its labels exactly as before.
    @Test
    func gridDefaultsItsLineOpacityToTheSecondaryAlpha()
    {
        #expect( EquatorialGridOverlay.defaultAppearance.secondaryOpacity == CanvasOverlayStyle.secondaryAlpha )
    }
}
