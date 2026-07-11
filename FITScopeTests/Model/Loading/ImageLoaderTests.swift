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
import Foundation
import Testing

/// Tests that ``ImageLoader/loader(for:)`` dispatches by the file's type: FITS to
/// the FITS loader, the photographic formats to the ImageIO loader, and everything
/// else to a failing unsupported loader.
@Suite( "ImageLoader" )
struct ImageLoaderTests
{
    /// A FITS file resolves to the FITS loader.
    @Test
    @MainActor
    func routesFITSFileToFITSLoader() throws
    {
        let loader = ImageLoader.loader( for: TestFixtures.monoImage )

        #expect( loader is FITSImageLoader, "a FITS file must be routed to the FITS loader" )
    }

    /// An unsupported type resolves to the unsupported loader rather than being
    /// attempted as another format.
    @Test
    @MainActor
    func routesUnsupportedFileToUnsupportedLoader() throws
    {
        let loader = ImageLoader.loader( for: URL( fileURLWithPath: "/tmp/document.txt" ) )

        #expect( loader is UnsupportedImageLoader, "an unsupported file must be routed to the unsupported loader" )
    }

    /// The unsupported loader produces no image and surfaces a clear error, so the
    /// failure shows per file rather than as a misleading parse error.
    @Test
    @MainActor
    func unsupportedLoaderSurfacesAnErrorAndNoImage() async throws
    {
        let loader = ImageLoader.loader( for: URL( fileURLWithPath: "/tmp/document.txt" ) )

        await loader.load()

        #expect( loader.image == nil, "an unsupported file must not produce an image" )
        #expect( loader.error != nil, "an unsupported file must surface an error" )
    }

    /// The factory resolves the per-format auto-stretch-on-open preference and hands
    /// it to the loader: with the FITS preference on, the file opens with an auto
    /// Screen Transfer baseline; with it off, it opens linear.
    @Test
    @MainActor
    func factoryResolvesAutoStretchPreference() async throws
    {
        let suiteName    = "FITScopeTests.ImageLoader.\( UUID().uuidString )"
        let defaults     = try #require( UserDefaults( suiteName: suiteName ) )
        let sharedName   = "FITScopeTests.ImageLoader.\( UUID().uuidString )"
        let shared       = try #require( UserDefaults( suiteName: sharedName ) )

        defer
        {
            defaults.removePersistentDomain( forName: suiteName )
            shared.removePersistentDomain( forName: sharedName )
        }

        let preferences = Preferences( defaults: defaults, sharedDefaults: shared )

        preferences.autoStretchOnOpenFITS = true

        let onLoader = ImageLoader.loader( for: TestFixtures.colorImage, preferences: preferences )

        await onLoader.load()

        #expect( try #require( onLoader.image ).renderer.adjustments.stretch != nil, "with the preference on, the file must open with an auto Screen Transfer" )

        preferences.autoStretchOnOpenFITS = false

        let offLoader = ImageLoader.loader( for: TestFixtures.colorImage, preferences: preferences )

        await offLoader.load()

        #expect( try #require( offLoader.image ).renderer.adjustments.stretch == nil, "with the preference off, the file must open linear" )
    }
}
