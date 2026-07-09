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
import SwiftPixel
import Testing

/// Tests the ImageIO decode/render core of `ImageProcessor`: decoding canonically
/// laid-out photographic samples into channel planes, the per-pixel read-out, the
/// detection luminance, and — crucially — the *as-authored* display the identity
/// normalization produces versus a min/max stretch.
@Suite( "ImageProcessor+ImageIO" )
struct ImageProcessorImageIOTests
{
    /// 8-bit RGB samples, stored `RGBX` (four components per pixel), decode and
    /// render as a colour image, and the per-pixel read-out returns the three
    /// channels with their fractions.
    @Test
    func rendersRGBAndReadsBackChannels() throws
    {
        // Two pixels: (200, 10, 20) and (20, 200, 10), each with a trailing padding
        // byte.
        let data       = Data( [ 200, 10, 20, 255, 20, 200, 10, 255 ] )
        let properties = ImageIOImageProperties( width: 2, height: 1, channelCount: 3, componentsPerPixel: 4, bytesPerComponent: 1 )
        let result     = try ImageProcessor.render( data: data, imageIO: properties, settings: ImageProcessor.Settings( normalize: .identity ) )

        #expect( result.inputPixelFormat == .rgb )
        #expect( result.image.width == 2 )
        #expect( result.image.height == 1 )

        let first = try #require( ImageProcessor.imageIOPixelValues( data: data, properties: properties, x: 0, y: 0 ) )

        #expect( first.map { $0.value } == [ 200, 10, 20 ] )
        #expect( first[ 0 ].fraction == 200.0 / 255.0 )

        let second = try #require( ImageProcessor.imageIOPixelValues( data: data, properties: properties, x: 1, y: 0 ) )

        #expect( second.map { $0.value } == [ 20, 200, 10 ] )
    }

    /// A single grayscale channel decodes and renders as a monochrome image.
    @Test
    func rendersGrayscaleAsMono() throws
    {
        let data       = Data( [ 50, 150 ] )
        let properties = ImageIOImageProperties( width: 2, height: 1, channelCount: 1, componentsPerPixel: 1, bytesPerComponent: 1 )
        let result     = try ImageProcessor.render( data: data, imageIO: properties, settings: ImageProcessor.Settings( normalize: .identity ) )

        #expect( result.inputPixelFormat == .mono )

        let value = try #require( ImageProcessor.imageIOPixelValues( data: data, properties: properties, x: 0, y: 0 ) )

        #expect( value.map { $0.value } == [ 50 ] )
        #expect( value[ 0 ].fraction == 50.0 / 255.0 )
    }

    /// A 16-bit grayscale sample is decoded at full precision (host/little-endian),
    /// and the read-out fraction is against the 16-bit full scale.
    @Test
    func decodes16BitSamples() throws
    {
        // 1000 = 0x03E8 and 40000 = 0x9C40, little-endian.
        let data       = Data( [ 0xE8, 0x03, 0x40, 0x9C ] )
        let properties = ImageIOImageProperties( width: 2, height: 1, channelCount: 1, componentsPerPixel: 1, bytesPerComponent: 2 )

        let first = try #require( ImageProcessor.imageIOPixelValues( data: data, properties: properties, x: 0, y: 0 ) )

        #expect( first.map { $0.value } == [ 1000 ] )
        #expect( first[ 0 ].fraction == 1000.0 / 65535.0 )

        let second = try #require( ImageProcessor.imageIOPixelValues( data: data, properties: properties, x: 1, y: 0 ) )

        #expect( second.map { $0.value } == [ 40000 ] )
    }

    /// The identity normalization shows the samples exactly as authored: a
    /// monochrome ramp that does not span the full range is reproduced unchanged
    /// (replicated across the three output channels).
    @Test
    func identityNormalizationShowsSamplesAsAuthored() throws
    {
        let data       = Data( [ 100, 125, 150 ] )
        let properties = ImageIOImageProperties( width: 3, height: 1, channelCount: 1, componentsPerPixel: 1, bytesPerComponent: 1 )
        let result     = try ImageProcessor.render( data: data, imageIO: properties, settings: ImageProcessor.Settings( normalize: .identity ) )

        #expect( Array( result.bytes ) == [ 100, 100, 100, 125, 125, 125, 150, 150, 150 ] )
    }

    /// A min/max normalization would instead stretch the same ramp to the full
    /// display range — the behaviour the as-authored baseline deliberately avoids
    /// for photographic images.
    @Test
    func minMaxNormalizationStretchesTheSameSamples() throws
    {
        let data       = Data( [ 100, 125, 150 ] )
        let properties = ImageIOImageProperties( width: 3, height: 1, channelCount: 1, componentsPerPixel: 1, bytesPerComponent: 1 )
        let result     = try ImageProcessor.render( data: data, imageIO: properties, settings: ImageProcessor.Settings( normalize: .minMax ) )

        // 100 → 0, the midpoint 125 → ~127, 150 → 255: the range is stretched, unlike
        // the as-authored identity render above.
        #expect( Array( result.bytes ) == [ 0, 0, 0, 127, 127, 127, 255, 255, 255 ] )
    }

    /// The luminance detection image is the per-pixel mean of the channels.
    @Test
    func luminanceIsTheChannelMean() throws
    {
        // Pixel 0 mean 0, pixel 1 mean (60 + 120 + 180) / 3 = 120.
        let data       = Data( [ 0, 0, 0, 255, 60, 120, 180, 255 ] )
        let properties = ImageIOImageProperties( width: 2, height: 1, channelCount: 3, componentsPerPixel: 4, bytesPerComponent: 1 )
        let luminance  = try #require( ImageProcessor.imageIOLinearLuminance( data: data, properties: properties ) )

        #expect( luminance.width == 2 )
        #expect( luminance.height == 1 )
        #expect( luminance.samples == [ 0, 120 ] )
    }

    /// An out-of-bounds read-out coordinate returns `nil`.
    @Test
    func outOfBoundsReadoutIsNil() throws
    {
        let data       = Data( [ 10, 20 ] )
        let properties = ImageIOImageProperties( width: 2, height: 1, channelCount: 1, componentsPerPixel: 1, bytesPerComponent: 1 )

        #expect( ImageProcessor.imageIOPixelValues( data: data, properties: properties, x: 2, y: 0 ) == nil )
        #expect( ImageProcessor.imageIOPixelValues( data: data, properties: properties, x: 0, y: 1 ) == nil )
    }

    /// Truncated pixel data is rejected at render.
    @Test
    func truncatedDataThrows() throws
    {
        let data       = Data( [ 1, 2, 3, 4 ] ) // one RGBX pixel, but two are required
        let properties = ImageIOImageProperties( width: 2, height: 1, channelCount: 3, componentsPerPixel: 4, bytesPerComponent: 1 )

        #expect( throws: ( any Error ).self )
        {
            try ImageProcessor.render( data: data, imageIO: properties, settings: ImageProcessor.Settings( normalize: .identity ) )
        }
    }

    /// An unsupported channel count is rejected at render.
    @Test
    func unsupportedChannelCountThrows() throws
    {
        let data       = Data( [ 1, 2, 3, 4 ] )
        let properties = ImageIOImageProperties( width: 2, height: 1, channelCount: 2, componentsPerPixel: 2, bytesPerComponent: 1 )

        #expect( throws: ( any Error ).self )
        {
            try ImageProcessor.render( data: data, imageIO: properties, settings: ImageProcessor.Settings( normalize: .identity ) )
        }
    }
}
