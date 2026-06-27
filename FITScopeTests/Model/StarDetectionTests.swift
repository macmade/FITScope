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
import SwiftPixel
import Testing

/// Tests for the ``StarDetection`` coordinator, which runs a detector over a
/// detection-ready image. (The FITS-to-image decoding it consumes — including
/// one-shot-colour demosaicing — is covered by SwiftAstro's `FITSImageDecoder`
/// tests.)
@Suite( "StarDetection" )
struct StarDetectionTests
{
    /// A synthetic single-channel linear image: a flat background with a single
    /// bright square, the same shape a decoded detection buffer has.
    private static func starImage( width: Int = 32, height: Int = 32, background: Double = 10, peak: Double = 200 ) throws -> PixelBuffer
    {
        let pixels = ( 0 ..< ( width * height ) ).map
        {
            index -> Double in

            let x      = index % width
            let y      = index / width
            let inStar = abs( x - ( width / 2 ) ) <= 2 && abs( y - ( height / 2 ) ) <= 2

            return inStar ? peak : background
        }

        return try PixelBuffer( width: width, height: height, channels: 1, pixels: pixels, isNormalized: false )
    }

    /// The coordinator runs the detector and returns the detected stars with
    /// their metrics.
    @Test
    func detectsStarsInImage() throws
    {
        let image = try Self.starImage()

        let field = try #require( StarDetection.detectStars( in: image ) )
        let star  = try #require( field.stars.first )

        #expect( field.count == 1 )
        #expect( star.flux > 0 )
        #expect( star.hfr  > 0 )
        #expect( star.fwhm > 0 )
    }

    /// The coordinator returns `nil` when no detection image is available.
    @Test
    func returnsNilForMissingImage() throws
    {
        #expect( StarDetection.detectStars( in: nil ) == nil )
    }
}
