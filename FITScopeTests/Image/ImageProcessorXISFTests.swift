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
import SwiftXISF
import Testing

/// Tests for `ImageProcessor`'s XISF entry point: sample decoding (format, byte
/// order, planar/interleaved storage), the mono / RGB / CFA input layouts, the
/// per-pixel read-out and the detection luminance.
@Suite( "ImageProcessor (XISF)" )
struct ImageProcessorXISFTests
{
    /// A grayscale image renders as a monochrome result at its geometry.
    @Test
    func rendersGrayscaleAsMono() throws
    {
        let properties = XISFImageProperties( width: 2, height: 2, channelCount: 1, sampleFormat: .uInt16, byteOrder: .little, pixelStorage: .planar, colorSpace: .gray, colorFilterArrayPattern: nil )
        let data       = Data( XISFTestData.uInt16LE( [ 10, 20, 30, 40 ] ) )
        let result     = try ImageProcessor.render( data: data, xisf: properties )

        #expect( result.image.width == 2 )
        #expect( result.image.height == 2 )
        #expect( result.inputPixelFormat == .mono )
    }

    /// A three-channel RGB image renders as a colour result.
    @Test
    func rendersRGBAsColor() throws
    {
        let properties = XISFImageProperties( width: 2, height: 2, channelCount: 3, sampleFormat: .uInt16, byteOrder: .little, pixelStorage: .planar, colorSpace: .rgb, colorFilterArrayPattern: nil )
        let planes     = XISFTestData.uInt16LE( [ 1, 2, 3, 4 ] + [ 10, 20, 30, 40 ] + [ 100, 200, 300, 400 ] )
        let result     = try ImageProcessor.render( data: Data( planes ), xisf: properties )

        #expect( result.image.width == 2 )
        #expect( result.image.height == 2 )
        #expect( result.inputPixelFormat == .rgb )
    }

    /// A colour-filter-array grayscale image is debayered to colour.
    @Test
    func debayersColorFilterArray() throws
    {
        let properties = XISFImageProperties( width: 4, height: 4, channelCount: 1, sampleFormat: .uInt16, byteOrder: .little, pixelStorage: .planar, colorSpace: .gray, colorFilterArrayPattern: "RGGB" )
        let data       = Data( XISFTestData.uInt16LE( Array( 0 ..< 16 ).map { $0 * 100 } ) )
        let result     = try ImageProcessor.render( data: data, xisf: properties )

        #expect( result.image.width == 4 )
        #expect( result.inputPixelFormat == .cfa )
    }

    /// The little-endian `UInt16` samples decode to the exact stored values, in
    /// row-major order (x fastest), for the cursor read-out.
    @Test
    func decodesLittleEndianUInt16Samples() throws
    {
        let properties = XISFImageProperties( width: 2, height: 2, channelCount: 1, sampleFormat: .uInt16, byteOrder: .little, pixelStorage: .planar, colorSpace: .gray, colorFilterArrayPattern: nil )
        let data       = Data( XISFTestData.uInt16LE( [ 10, 20, 30, 40 ] ) )

        #expect( ImageProcessor.xisfPixelValues( data: data, properties: properties, x: 0, y: 0 )?.first?.value == 10 )
        #expect( ImageProcessor.xisfPixelValues( data: data, properties: properties, x: 1, y: 0 )?.first?.value == 20 )
        #expect( ImageProcessor.xisfPixelValues( data: data, properties: properties, x: 0, y: 1 )?.first?.value == 30 )
        #expect( ImageProcessor.xisfPixelValues( data: data, properties: properties, x: 1, y: 1 )?.first?.value == 40 )
        #expect( ImageProcessor.xisfPixelValues( data: data, properties: properties, x: 2, y: 0 ) == nil )
    }

    /// A big-endian image decodes the same values as its little-endian twin, so the
    /// byte order is honoured.
    @Test
    func honoursByteOrder() throws
    {
        let value      = 0x1234
        let bigEndian  = withUnsafeBytes( of: UInt16( value ).bigEndian ) { Array( $0 ) }
        let properties = XISFImageProperties( width: 1, height: 1, channelCount: 1, sampleFormat: .uInt16, byteOrder: .big, pixelStorage: .planar, colorSpace: .gray, colorFilterArrayPattern: nil )

        #expect( ImageProcessor.xisfPixelValues( data: Data( bigEndian ), properties: properties, x: 0, y: 0 )?.first?.value == Double( value ) )
    }

    /// Float samples decode from their bit pattern.
    @Test
    func decodesFloat32Samples() throws
    {
        let properties = XISFImageProperties( width: 2, height: 1, channelCount: 1, sampleFormat: .float32, byteOrder: .little, pixelStorage: .planar, colorSpace: .gray, colorFilterArrayPattern: nil )
        let data       = Data( XISFTestData.float32LE( [ 0.25, 0.75 ] ) )

        #expect( ImageProcessor.xisfPixelValues( data: data, properties: properties, x: 0, y: 0 )?.first?.value == 0.25 )
        #expect( ImageProcessor.xisfPixelValues( data: data, properties: properties, x: 1, y: 0 )?.first?.value == 0.75 )
        // A floating-point format has no fixed full scale, so no fraction.
        #expect( ImageProcessor.xisfPixelValues( data: data, properties: properties, x: 0, y: 0 )?.first?.fraction == nil )
    }

    /// Planar RGB storage reads each channel from its own contiguous block.
    @Test
    func readsPlanarRGBPerChannel() throws
    {
        let properties = XISFImageProperties( width: 2, height: 2, channelCount: 3, sampleFormat: .uInt16, byteOrder: .little, pixelStorage: .planar, colorSpace: .rgb, colorFilterArrayPattern: nil )
        let planes     = XISFTestData.uInt16LE( [ 1, 2, 3, 4 ] + [ 10, 20, 30, 40 ] + [ 100, 200, 300, 400 ] )
        let values     = ImageProcessor.xisfPixelValues( data: Data( planes ), properties: properties, x: 0, y: 0 )

        #expect( values?.map { $0.value } == [ 1, 10, 100 ] )
    }

    /// Interleaved (normal) RGB storage reads adjacent per-pixel channels.
    @Test
    func readsInterleavedRGBPerChannel() throws
    {
        let properties = XISFImageProperties( width: 2, height: 2, channelCount: 3, sampleFormat: .uInt16, byteOrder: .little, pixelStorage: .normal, colorSpace: .rgb, colorFilterArrayPattern: nil )
        let pixels     = XISFTestData.uInt16LE( [ 1, 10, 100, 2, 20, 200, 3, 30, 300, 4, 40, 400 ] )
        let values     = ImageProcessor.xisfPixelValues( data: Data( pixels ), properties: properties, x: 1, y: 1 )

        #expect( values?.map { $0.value } == [ 4, 40, 400 ] )
    }

    /// The detection luminance is the per-pixel mean of the channels.
    @Test
    func luminanceIsChannelMean() throws
    {
        let properties = XISFImageProperties( width: 1, height: 1, channelCount: 3, sampleFormat: .uInt16, byteOrder: .little, pixelStorage: .planar, colorSpace: .rgb, colorFilterArrayPattern: nil )
        let planes     = XISFTestData.uInt16LE( [ 30 ] + [ 60 ] + [ 90 ] )
        let luminance  = ImageProcessor.xisfLinearLuminance( data: Data( planes ), properties: properties )

        #expect( luminance?.samples == [ 60 ] )
    }

    /// An unsupported colour space is rejected at render, so the file still loads
    /// with its metadata but surfaces the error only when rendered.
    @Test
    func rejectsCIELabColorSpace() throws
    {
        let properties = XISFImageProperties( width: 1, height: 1, channelCount: 3, sampleFormat: .uInt16, byteOrder: .little, pixelStorage: .planar, colorSpace: .cieLab, colorFilterArrayPattern: nil )
        let data       = Data( XISFTestData.uInt16LE( [ 1, 2, 3 ] ) )

        #expect( throws: ( any Error ).self ) { try ImageProcessor.render( data: data, xisf: properties ) }
    }

    /// A complex sample format is rejected at render.
    @Test
    func rejectsComplexSampleFormat() throws
    {
        let properties = XISFImageProperties( width: 1, height: 1, channelCount: 1, sampleFormat: .complex32, byteOrder: .little, pixelStorage: .planar, colorSpace: .gray, colorFilterArrayPattern: nil )
        let data       = Data( count: 8 )

        #expect( throws: ( any Error ).self ) { try ImageProcessor.render( data: data, xisf: properties ) }
    }

    /// Truncated pixel data is rejected at render.
    @Test
    func rejectsTruncatedData() throws
    {
        let properties = XISFImageProperties( width: 4, height: 4, channelCount: 1, sampleFormat: .uInt16, byteOrder: .little, pixelStorage: .planar, colorSpace: .gray, colorFilterArrayPattern: nil )
        let data       = Data( XISFTestData.uInt16LE( [ 1, 2, 3 ] ) )

        #expect( throws: ( any Error ).self ) { try ImageProcessor.render( data: data, xisf: properties ) }
    }
}
