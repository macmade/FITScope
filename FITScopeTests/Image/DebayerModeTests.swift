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

import SwiftPixel
import Testing
@testable import FITScope

/// Tests that the chosen debayer algorithm is threaded into the pipeline
/// configuration, defaulting to bilinear.
@Suite( "DebayerMode" )
struct DebayerModeTests
{
    @Test
    func settingsThreadsDebayerModeIntoConfig() throws
    {
        let settings = ImageProcessor.Settings( debayer: .pattern( .rggb ), debayerMode: .vng )
        let config   = settings.config( scale: 1, offset: 0, headerPattern: nil )

        #expect( config.debayer?.mode == .vng )
    }

    @Test
    func defaultsToBilinear() throws
    {
        let settings = ImageProcessor.Settings( debayer: .pattern( .rggb ) )
        let config   = settings.config( scale: 1, offset: 0, headerPattern: nil )

        #expect( config.debayer?.mode == .bilinear )
    }
}
