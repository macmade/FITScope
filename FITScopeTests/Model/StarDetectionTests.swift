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

/// A deterministic, seeded uniform noise source, so synthetic fixtures are
/// reproducible across runs without depending on the system RNG.
private struct DeterministicNoise
{
    /// The current state of the linear congruential generator.
    private var state: UInt64

    /// Creates a generator seeded with the given value.
    ///
    /// - Parameter seed: The initial generator state.
    init( seed: UInt64 )
    {
        self.state = seed
    }

    /// Advances the generator and returns the next value in `[-1, 1]`.
    mutating func next() -> Double
    {
        self.state = ( self.state &* 6364136223846793005 ) &+ 1442695040888963407

        return ( Double( self.state >> 11 ) * ( 1.0 / 9007199254740992.0 ) ) * 2 - 1
    }
}

/// Builds synthetic single-channel linear images of Gaussian "stars" on a flat
/// background, with reproducible noise — the same shape a decoded detection
/// buffer has, and the input the matched-filter detector expects (it rejects a
/// noiseless image as degenerate).
private struct SyntheticStarField
{
    /// The image width, in pixels.
    let width: Int

    /// The image height, in pixels.
    let height: Int

    /// The accumulated samples, in row-major order.
    private var pixels: [ Double ]

    /// Creates a field of the given size filled with the background level.
    ///
    /// - Parameters:
    ///   - width:      The image width, in pixels.
    ///   - height:     The image height, in pixels.
    ///   - background: The flat background level.
    init( width: Int, height: Int, background: Double )
    {
        self.width  = width
        self.height = height
        self.pixels = [ Double ]( repeating: background, count: width * height )
    }

    /// Returns a copy with a round Gaussian star added.
    ///
    /// - Parameters:
    ///   - cx:    The centre column, in pixels.
    ///   - cy:    The centre row, in pixels.
    ///   - peak:  The peak value above the background.
    ///   - sigma: The Gaussian standard deviation.
    /// - Returns: A copy with the star added.
    func addingStar( cx: Double, cy: Double, peak: Double, sigma: Double ) -> SyntheticStarField
    {
        var copy = self

        copy.pixels = self.pixels.indices.map
        {
            index in

            let x        = Double( index % self.width )
            let y        = Double( index / self.width )
            let dx       = x - cx
            let dy       = y - cy
            let exponent = ( ( dx * dx ) + ( dy * dy ) ) / ( 2 * sigma * sigma )

            return self.pixels[ index ] + ( peak * exp( -exponent ) )
        }

        return copy
    }

    /// Returns a copy with reproducible uniform noise of the given amplitude
    /// added, so the detector has a measurable noise floor to threshold against.
    ///
    /// - Parameters:
    ///   - seed:      The seed for the deterministic noise source.
    ///   - amplitude: The maximum magnitude of the added noise.
    /// - Returns: A copy with noise added.
    func addingNoise( seed: UInt64, amplitude: Double ) -> SyntheticStarField
    {
        var copy  = self
        var noise = DeterministicNoise( seed: seed )

        copy.pixels = self.pixels.map { $0 + ( noise.next() * amplitude ) }

        return copy
    }

    /// Builds the single-channel linear pixel buffer from the accumulated samples.
    ///
    /// - Returns: The synthetic single-channel pixel buffer.
    /// - Throws: An error if the geometry is inconsistent.
    func image() throws -> PixelBuffer
    {
        try PixelBuffer( width: self.width, height: self.height, channels: 1, pixels: self.pixels, isNormalized: false )
    }
}

/// Tests for the ``StarDetection`` coordinator, which runs a detector over a
/// detection-ready image. (The FITS-to-image decoding it consumes — including
/// one-shot-colour demosaicing — is covered by SwiftAstro's `FITSImageDecoder`
/// tests.)
@Suite( "StarDetection" )
struct StarDetectionTests
{
    /// The coordinator runs the default detector and returns the detected stars
    /// with their metrics.
    @Test
    func detectsStarsInImage() throws
    {
        let image = try SyntheticStarField( width: 120, height: 120, background: 200 )
            .addingStar( cx: 60, cy: 60, peak: 4000, sigma: 2 )
            .addingNoise( seed: 1, amplitude: 10 )
            .image()

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
