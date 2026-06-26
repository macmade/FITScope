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
import SwiftAstro
import Testing

/// Tests for the ``StarDetection`` coordinator, which decodes the linear mono
/// buffer from raw FITS data and runs a detector over it.
@Suite( "StarDetection" )
struct StarDetectionTests
{
    /// A synthetic 8-bit HDU: a flat background with a single bright square,
    /// returned as raw bytes plus the header property snapshots — the same shape
    /// the renderer hands the coordinator.
    private static func starFieldHDU( width: Int = 32, height: Int = 32, background: UInt8 = 10, peak: UInt8 = 200 ) -> ( data: Data, properties: [ FITSPropertySnapshot ] )
    {
        let bytes = ( 0 ..< ( width * height ) ).map
        {
            index -> UInt8 in

            let x      = index % width
            let y      = index / width
            let inStar = abs( x - ( width / 2 ) ) <= 2 && abs( y - ( height / 2 ) ) <= 2

            return inStar ? peak : background
        }

        let properties =
            [
                FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
                FITSPropertySnapshot( name: "NAXIS",  value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS1", value: .integer( Int64( width ) ) ),
                FITSPropertySnapshot( name: "NAXIS2", value: .integer( Int64( height ) ) ),
            ]

        return ( Data( bytes ), properties )
    }

    /// The coordinator decodes the raw data and returns the detected stars with
    /// their metrics.
    @Test
    func detectsStarsFromRawFITSData() throws
    {
        let ( data, properties ) = Self.starFieldHDU()

        let field = try #require( StarDetection.detectStars( data: data, properties: properties ) )
        let star  = try #require( field.stars.first )

        #expect( field.count == 1 )
        #expect( star.flux > 0 )
        #expect( star.hfr  > 0 )
        #expect( star.fwhm > 0 )
    }

    /// The coordinator returns `nil` when the data cannot be decoded (no geometry).
    @Test
    func returnsNilForUndecodableData() throws
    {
        #expect( StarDetection.detectStars( data: Data(), properties: [] ) == nil )
    }
}
