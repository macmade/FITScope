/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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

import Foundation
import SwiftFITS

/// Synthesised, minimal FITS payloads for tests that need a precisely shaped
/// file rather than a bundled corpus sample.
enum FITSTestData
{
    /// A minimal, valid header-only FITS file
    /// (`SIMPLE=T / BITPIX=8 / NAXIS=0 / END`) as a single space-padded block.
    static func headerOnly() -> Data
    {
        let records =
        [
            "SIMPLE  = T",
            "BITPIX  = 8",
            "NAXIS   = 0",
            "END",
        ]
        let header = records.map { $0.padding( toLength: 80, withPad: " ", startingAt: 0 ) }.joined()

        return Data( header.padding( toLength: FITSFile.blockSize, withPad: " ", startingAt: 0 ).utf8 )
    }

    /// A minimal, valid `BITPIX = 64` image ( 1 × 1 ) — a format the pixel
    /// pipeline does not support — as a header block plus one zero-filled data
    /// block.
    static func bitpix64() -> Data
    {
        let records =
        [
            "SIMPLE  = T",
            "BITPIX  = 64",
            "NAXIS   = 2",
            "NAXIS1  = 1",
            "NAXIS2  = 1",
            "END",
        ]
        let header = records.map { $0.padding( toLength: 80, withPad: " ", startingAt: 0 ) }.joined()

        var data = Data( header.padding( toLength: FITSFile.blockSize, withPad: " ", startingAt: 0 ).utf8 )

        data.append( Data( count: FITSFile.blockSize ) )

        return data
    }
}
