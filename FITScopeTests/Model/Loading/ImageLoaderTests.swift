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
/// the FITS loader, everything else to a failing unsupported loader.
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

    /// A non-FITS type resolves to the unsupported loader rather than being
    /// attempted as FITS.
    @Test
    @MainActor
    func routesUnsupportedFileToUnsupportedLoader() throws
    {
        let loader = ImageLoader.loader( for: URL( fileURLWithPath: "/tmp/photo.png" ) )

        #expect( loader is UnsupportedImageLoader, "a non-FITS file must be routed to the unsupported loader" )
    }

    /// The unsupported loader produces no image and surfaces a clear error, so the
    /// failure shows per file rather than as a misleading FITS parse error.
    @Test
    @MainActor
    func unsupportedLoaderSurfacesAnErrorAndNoImage() async throws
    {
        let loader = ImageLoader.loader( for: URL( fileURLWithPath: "/tmp/photo.png" ) )

        await loader.load()

        #expect( loader.image == nil, "an unsupported file must not produce an image" )
        #expect( loader.error != nil, "an unsupported file must surface an error" )
    }
}
