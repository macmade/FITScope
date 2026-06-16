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
import SwiftPixel
import Testing
@testable import FITScope

/// Tests for `ImageProcessor.rawPixelValue`: byte-offset math, big-endian
/// decoding, BSCALE/BZERO application and full-scale fraction.
@Suite( "PixelValue" )
struct PixelValueTests
{
    /// Builds 8-bit header snapshots for a width × height image.
    private func headers( width: Int, height: Int ) -> [ FITSPropertySnapshot ]
    {
        [
            FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
            FITSPropertySnapshot( name: "NAXIS",  value: .integer( 2 ) ),
            FITSPropertySnapshot( name: "NAXIS1", value: .integer( Int64( width ) ) ),
            FITSPropertySnapshot( name: "NAXIS2", value: .integer( Int64( height ) ) ),
        ]
    }

    @Test
    func decodesUInt8RowMajorWithoutFlip() throws
    {
        // 3 × 2 image, row-major: row 0 = [10, 20, 30], row 1 = [40, 50, 60].
        let data    = Data( [ 10, 20, 30, 40, 50, 60 ] )
        let headers = self.headers( width: 3, height: 2 )

        let topLeft = try #require( ImageProcessor.rawPixelValue( data: data, properties: headers, x: 0, y: 0 ) )
        let mid     = try #require( ImageProcessor.rawPixelValue( data: data, properties: headers, x: 1, y: 1 ) )

        let fraction = try #require( mid.fraction )

        #expect( topLeft.value == 10 )
        #expect( mid.value == 50 )
        #expect( abs( fraction - ( 50.0 / 255.0 ) ) < 1e-9, "fraction is value / 8-bit full scale" )
    }

    @Test
    func appliesBScaleAndBZero() throws
    {
        let data     = Data( [ 0, 100, 0, 0, 0, 0 ] )
        var headers  = self.headers( width: 3, height: 2 )

        headers.append( FITSPropertySnapshot( name: "BSCALE", value: .integer( 2 ) ) )
        headers.append( FITSPropertySnapshot( name: "BZERO",  value: .integer( 5 ) ) )

        let value = try #require( ImageProcessor.rawPixelValue( data: data, properties: headers, x: 1, y: 0 ) )

        #expect( value.value == 100.0 * 2.0 + 5.0 )
    }

    @Test
    func returnsNilForOutOfBounds() throws
    {
        let data    = Data( [ 10, 20, 30, 40, 50, 60 ] )
        let headers = self.headers( width: 3, height: 2 )

        #expect( ImageProcessor.rawPixelValue( data: data, properties: headers, x: 3, y: 0 ) == nil )
        #expect( ImageProcessor.rawPixelValue( data: data, properties: headers, x: 0, y: 2 ) == nil )
        #expect( ImageProcessor.rawPixelValue( data: data, properties: headers, x: -1, y: 0 ) == nil )
    }
}
