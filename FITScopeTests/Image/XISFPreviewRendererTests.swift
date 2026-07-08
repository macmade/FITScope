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

import CoreGraphics
@testable import FITScope
import Foundation
import Testing

/// Tests for `XISFPreviewRenderer` and the `PreviewRenderer` dispatcher — the
/// default-settings renderers the QuickLook thumbnail and preview extensions use to
/// turn an XISF file into a display-ready `CGImage`.
@Suite( "XISFPreviewRenderer" )
struct XISFPreviewRendererTests
{
    /// A valid XISF file renders to an image at its geometry, from a URL.
    @Test
    func rendersAValidXISFFileToAnImage() throws
    {
        let image = try XISFPreviewRenderer.render( contentsOf: TestFixtures.xisfImage )

        #expect( image.width == 8 )
        #expect( image.height == 8 )
    }

    /// It renders from raw bytes too.
    @Test
    func rendersFromRawXISFData() throws
    {
        let data  = try Data( contentsOf: TestFixtures.xisfImage )
        let image = try XISFPreviewRenderer.render( data: data )

        #expect( image.width == 8 )
        #expect( image.height == 8 )
    }

    /// A multi-image file previews its first image.
    @Test
    func previewsFirstImageOfAMultiImageFile() throws
    {
        let image = try XISFPreviewRenderer.render( contentsOf: TestFixtures.xisfMultiImage )

        #expect( image.width == 6 )
        #expect( image.height == 4 )
    }

    /// A malformed file surfaces as a thrown error.
    @Test
    func throwsForAMalformedXISFFile()
    {
        #expect( throws: ( any Error ).self )
        {
            try XISFPreviewRenderer.render( data: Data( "not an xisf file".utf8 ) )
        }
    }

    /// The shared dispatcher routes an XISF file to the XISF renderer and a FITS
    /// file to the FITS renderer, so a single extension handles both.
    @Test
    func dispatcherRoutesByFormat() throws
    {
        let xisf = try PreviewRenderer.render( contentsOf: TestFixtures.xisfImage )
        let fits = try PreviewRenderer.render( contentsOf: TestFixtures.monoImage )

        #expect( xisf.width == 8 && xisf.height == 8 )
        #expect( fits.width > 0 && fits.height > 0 )
    }
}
