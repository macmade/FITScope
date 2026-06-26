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
import SwiftFITS
import Testing

/// Tests for `ImageProcessor`'s header interpretation, in particular the linear
/// pixel-scaling keywords `BSCALE` / `BZERO`.
@Suite( "ImageProcessor" )
struct ImageProcessorTests
{
    /// A `BSCALE` carrying a floating-point value must be honoured as that
    /// float, rather than falling back to the integer default of 1.
    @Test
    func floatScalingKeywordsAreHonoured() throws
    {
        let properties =
            [
                FITSPropertySnapshot( name: "BSCALE", value: .float( 1.5 ) ),
                FITSPropertySnapshot( name: "BZERO",  value: .float( 0 ) ),
            ]

        let scaling = ImageProcessor.scaling( from: properties )

        #expect( scaling.scale == 1.5 )
        #expect( scaling.scale != 1, "a float BSCALE must not fall back to the default scale" )
    }

    /// Integer-formatted scaling keywords keep working: a `BZERO` of the
    /// integer `32768` (the usual unsigned-16-bit offset) is read as `32768`.
    @Test
    func integerScalingKeywordsAreHonoured() throws
    {
        let properties =
            [
                FITSPropertySnapshot( name: "BZERO",  value: .integer( 32768 ) ),
                FITSPropertySnapshot( name: "BSCALE", value: .integer( 1 ) ),
            ]

        let scaling = ImageProcessor.scaling( from: properties )

        #expect( scaling.offset == 32768 )
    }

    /// A non-2-D geometry (a 3-D cube / multi-plane image) is rejected with a
    /// diagnostic that names the offending `NAXIS` value, rather than rendering.
    @Test
    func nonTwoDimensionalGeometryIsRejected() throws
    {
        let properties: [ FITSPropertySnapshot ] =
            [
                FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
                FITSPropertySnapshot( name: "NAXIS",  value: .integer( 3 ) ),
                FITSPropertySnapshot( name: "NAXIS1", value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS2", value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS3", value: .integer( 2 ) ),
            ]

        let error = try #require( throws: ( any Error ).self )
        {
            _ = try ImageProcessor.render( data: Data(), properties: properties )
        }

        let message = "\( error )"

        #expect( message.contains( "only 2-dimensional images are supported" ), "expected an unsupported-geometry error, got: \"\( message )\"" )
        #expect( message.contains( "NAXIS = 3" ), "the error must report the offending NAXIS value, got: \"\( message )\"" )
    }

    /// A 90° rotation swaps the rendered image's width and height; without an
    /// orientation the dimensions are unchanged.
    @Test
    func rotationSwapsRenderedDimensions() throws
    {
        let properties: [ FITSPropertySnapshot ] =
            [
                FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
                FITSPropertySnapshot( name: "NAXIS",  value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS1", value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS2", value: .integer( 1 ) ),
            ]

        let data = Data( [ 10, 200 ] )

        let unrotated = try ImageProcessor.render( data: data, properties: properties )

        #expect( unrotated.image.width  == 2 )
        #expect( unrotated.image.height == 1 )

        var settings = ImageProcessor.Settings()

        settings.orientation = .init( rotation: .clockwise90, mirroredHorizontally: false )

        let rotated = try ImageProcessor.render( data: data, properties: properties, settings: settings )

        #expect( rotated.image.width  == 1 )
        #expect( rotated.image.height == 2 )
    }

    /// A non-positive `NAXIS2` is rejected with a diagnostic that names the
    /// offending axis and value — NAXIS2, not NAXIS1.
    @Test
    func nonPositiveNAXIS2IsRejectedNamingTheAxis() throws
    {
        let properties: [ FITSPropertySnapshot ] =
            [
                FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
                FITSPropertySnapshot( name: "NAXIS",  value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS1", value: .integer( 1 ) ),
                FITSPropertySnapshot( name: "NAXIS2", value: .integer( 0 ) ),
            ]

        let error = try #require( throws: ( any Error ).self )
        {
            _ = try ImageProcessor.render( data: Data(), properties: properties )
        }

        let message = "\( error )"

        #expect( message.contains( "NAXIS2" ), "the error must name NAXIS2, got: \"\( message )\"" )
        #expect( message.contains( "0" ),      "the error must report the offending value, got: \"\( message )\"" )
    }

    /// `linearMonoSamples` decodes the whole HDU into a row-major array of linear
    /// (`BSCALE`/`BZERO`-applied) values, consistent with per-pixel
    /// `rawPixelValue`.
    @Test
    func decodesLinearMonoSamples() throws
    {
        let ( data, properties ) = FITSTestData.gradient( width: 4, height: 4 )

        let samples = try #require( ImageProcessor.linearMonoSamples( data: data, properties: properties ) )

        #expect( samples.count == 16 )
        #expect( samples.first == 0 )
        #expect( samples.last  == 255 )
        #expect( samples[ 5 ] == ImageProcessor.rawPixelValue( data: data, properties: properties, x: 1, y: 1 )?.value )
    }

    /// `linearMonoSamples` returns `nil` when the geometry keywords are missing.
    @Test
    func linearMonoSamplesReturnsNilWithoutGeometry() throws
    {
        #expect( ImageProcessor.linearMonoSamples( data: Data(), properties: [] ) == nil )
    }
}
