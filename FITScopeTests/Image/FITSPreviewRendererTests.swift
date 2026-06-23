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

/// Tests for `FITSPreviewRenderer`: the shared default-settings renderer used by
/// both the app's first render and the QuickLook extensions. It turns a FITS
/// file (by URL or raw bytes) into a display-ready `CGImage`, and surfaces a
/// malformed file as a thrown error.
@Suite( "FITSPreviewRenderer" )
struct FITSPreviewRendererTests
{
    @Test
    func rendersAValidFITSFileToAnImage() throws
    {
        let image = try FITSPreviewRenderer.render( contentsOf: TestFixtures.monoImage )

        #expect( image.width > 0 && image.height > 0 )
    }

    @Test
    func rendersFromRawFITSData() throws
    {
        let data  = try Data( contentsOf: TestFixtures.monoImage )
        let image = try FITSPreviewRenderer.render( data: data )

        #expect( image.width > 0 && image.height > 0 )
    }

    @Test
    func throwsForAMalformedFITSFile()
    {
        #expect( throws: ( any Error ).self )
        {
            try FITSPreviewRenderer.render( contentsOf: TestFixtures.invalidImage )
        }
    }
}
