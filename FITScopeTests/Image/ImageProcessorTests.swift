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

    /// `render` itself handles only a single 2-D image (or an RGB colour cube); a
    /// whole `NAXIS=3` cube passed to it directly is rejected with a diagnostic that
    /// names the offending `NAXIS` value. (A multi-image cube is split into per-plane
    /// 2-D render sources by the loader, so `render` never sees the whole cube for a
    /// supported file — see `FITSImageLoaderMultiImageTests`.)
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

        #expect( message.contains( "Unsupported image geometry" ), "expected an unsupported-geometry error, got: \"\( message )\"" )
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

    /// An RGB colour-planes image (`NAXIS=3`, third axis = 3, `CTYPE1`/`CTYPE2`
    /// present, no `CTYPE3`) renders as a genuine colour image: the display image
    /// keeps the plane dimensions and the render is tagged as an `.rgb` input.
    @Test
    func rgbColorPlanesRenderAsColor() throws
    {
        let ( data, properties ) = FITSTestData.rgbPlanes( width: 4, height: 3 )

        let result = try ImageProcessor.render( data: data, properties: properties )

        #expect( result.image.width  == 4 )
        #expect( result.image.height == 3 )
        #expect( result.inputPixelFormat  == .rgb, "RGB planes must render as a colour (rgb) input, not mono" )
        #expect( result.outputPixelFormat == .rgb )
    }

    /// The RGB-planes rule accepts any `NAXIS=3` with a third axis of exactly 3 and
    /// no `CTYPE3`. The spatial `CTYPE1`/`CTYPE2` are *not* required — many real RGB
    /// FITS files carry no WCS — so a bare 3-plane cube is still recognised as colour.
    @Test
    func rgbPlanesDetectionRule() throws
    {
        func properties( naxis3: Int64, ctype1: String? = "RA---TAN", ctype2: String? = "DEC--TAN", ctype3: String? = nil ) -> [ FITSPropertySnapshot ]
        {
            var props: [ FITSPropertySnapshot ] =
                [
                    FITSPropertySnapshot( name: "NAXIS",  value: .integer( 3 ) ),
                    FITSPropertySnapshot( name: "NAXIS3", value: .integer( naxis3 ) ),
                ]

            ctype1.map { props.append( FITSPropertySnapshot( name: "CTYPE1", value: .string( $0 ) ) ) }
            ctype2.map { props.append( FITSPropertySnapshot( name: "CTYPE2", value: .string( $0 ) ) ) }
            ctype3.map { props.append( FITSPropertySnapshot( name: "CTYPE3", value: .string( $0 ) ) ) }

            return props
        }

        #expect( ImageProcessor.isRGBPlanes( properties: properties( naxis3: 3 ) ) )
        #expect( ImageProcessor.isRGBPlanes( properties: properties( naxis3: 5 ) ) == false, "the third axis must be 3" )
        #expect( ImageProcessor.isRGBPlanes( properties: properties( naxis3: 3, ctype1: nil, ctype2: nil ) ), "a bare 3-plane cube (no WCS) is still RGB" )
        #expect( ImageProcessor.isRGBPlanes( properties: properties( naxis3: 3, ctype2: "  " ) ), "a blank CTYPE2 no longer disqualifies RGB" )
        #expect( ImageProcessor.isRGBPlanes( properties: properties( naxis3: 3, ctype3: "WAVE" ) ) == false, "a present CTYPE3 rules out the RGB-planes case" )
        #expect( ImageProcessor.isRGBPlanes( properties: FITSTestData.gradient().properties ) == false, "a 2-D image is not RGB planes" )
    }

    /// The multi-image rule accepts a `NAXIS=3` cube whose third axis is a plain
    /// frame index: `NAXIS3 ≥ 2` and `≠ 3` (a count of 3 is claimed as RGB) and no
    /// `CTYPE3` (whose presence marks a physical data cube).
    @Test
    func multiImageCubeDetectionRule() throws
    {
        func properties( naxis: Int64 = 3, naxis3: Int64, ctype3: String? = nil ) -> [ FITSPropertySnapshot ]
        {
            var props: [ FITSPropertySnapshot ] =
                [
                    FITSPropertySnapshot( name: "NAXIS",  value: .integer( naxis ) ),
                    FITSPropertySnapshot( name: "NAXIS3", value: .integer( naxis3 ) ),
                ]

            ctype3.map { props.append( FITSPropertySnapshot( name: "CTYPE3", value: .string( $0 ) ) ) }

            return props
        }

        #expect( ImageProcessor.isMultiImageCube( properties: properties( naxis3: 2 ) ), "2 planes with no physical third axis is a multi-image cube" )
        #expect( ImageProcessor.isMultiImageCube( properties: properties( naxis3: 7 ) ), "7 planes is a multi-image cube" )
        #expect( ImageProcessor.isMultiImageCube( properties: properties( naxis3: 3 ) ) == false, "a 3-plane cube is claimed by the RGB rule, not multi-image" )
        #expect( ImageProcessor.isMultiImageCube( properties: properties( naxis3: 1 ) ) == false, "a single plane is not a stack" )
        #expect( ImageProcessor.isMultiImageCube( properties: properties( naxis3: 4, ctype3: "WAVE" ) ) == false, "a physical CTYPE3 marks a data cube, not separate images" )
        #expect( ImageProcessor.isMultiImageCube( properties: properties( naxis: 2, naxis3: 0 ) ) == false, "a 2-D image is not a multi-image cube" )

        // The RGB and multi-image rules are mutually exclusive over every NAXIS=3 shape.
        #expect( ImageProcessor.isRGBPlanes( properties: properties( naxis3: 4 ) ) == false )
        #expect( ImageProcessor.isMultiImageCube( properties: properties( naxis3: 3 ) ) == false )
    }

    /// `cubePlanes` splits a multi-image cube into one 2-D HDU per plane: each plane
    /// carries a `NAXIS=2` header (no `NAXIS3`) and its own contiguous byte slice, so
    /// the existing 2-D render path renders each frame unchanged.
    @Test
    func cubePlanesSplitsIntoTwoDimensionalHDUs() throws
    {
        // Three 2×2 planes filled with distinct constants: 1, 2, 3.
        let planeBytes: [ [ UInt8 ] ] = [ [ 1, 1, 1, 1 ], [ 2, 2, 2, 2 ], [ 3, 3, 3, 3 ] ]
        let data                      = Data( planeBytes.flatMap { $0 } )
        let properties: [ FITSPropertySnapshot ] =
            [
                FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
                FITSPropertySnapshot( name: "NAXIS",  value: .integer( 3 ) ),
                FITSPropertySnapshot( name: "NAXIS1", value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS2", value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS3", value: .integer( 4 ) ),
            ]

        let planes = ImageProcessor.cubePlanes( data: data, properties: properties )

        // NAXIS3 says 4 but only 3 planes of data are present; the truncated plane is
        // dropped rather than surfaced as a broken frame.
        #expect( planes.count == 3, "one HDU per plane actually present in the data" )

        for ( index, plane ) in planes.enumerated()
        {
            #expect( plane.properties.first { $0.name == "NAXIS"  }?.value.integer == 2, "each plane is a 2-D HDU" )
            #expect( plane.properties.contains { $0.name == "NAXIS3" } == false, "the third-axis keyword is dropped from a plane" )
            #expect( Array( plane.data ) == planeBytes[ index ], "each plane carries its own contiguous slice" )
        }
    }

    /// A `NAXIS=3` file with a physical `CTYPE3` is neither RGB nor a multi-image
    /// stack; `render` rejects it with a message that names it as a data cube,
    /// distinct from the RGB / multi-image cases.
    @Test
    func physicalDataCubeIsRejected() throws
    {
        let properties: [ FITSPropertySnapshot ] =
            [
                FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
                FITSPropertySnapshot( name: "NAXIS",  value: .integer( 3 ) ),
                FITSPropertySnapshot( name: "NAXIS1", value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS2", value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS3", value: .integer( 5 ) ),
                FITSPropertySnapshot( name: "CTYPE3", value: .string( "WAVE" ) ),
            ]

        #expect( ImageProcessor.isRGBPlanes( properties: properties ) == false )
        #expect( ImageProcessor.isMultiImageCube( properties: properties ) == false )

        let error = try #require( throws: ( any Error ).self )
        {
            _ = try ImageProcessor.render( data: Data(), properties: properties )
        }

        let message = "\( error )"

        #expect( message.contains( "NAXIS = 3" ), "expected the unsupported-geometry error, got: \"\( message )\"" )
        #expect( message.contains( "cube" ), "the message must identify it as a data cube, got: \"\( message )\"" )
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
}
