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

/// Tests that `FITSImageLoader` opens an RGB `NAXIS=3` colour-planes file as a
/// single colour image, without regressing the monochrome / 2-D path.
@Suite( "FITSImageLoader (RGB)" )
struct FITSImageLoaderRGBTests
{
    /// The URL used for the synthesized in-memory files.
    private let url = URL( fileURLWithPath: "/tmp/rgb.fits" )

    /// A synthesized RGB `NAXIS=3` file loads as a colour image: it is `isColor`
    /// but not `isColorFilterArray`, carries no graph, and produces a detection
    /// image (built from the combined luminance).
    @Test
    @MainActor
    func loadsRGBPlanesAsColorImage() async throws
    {
        let data   = FITSTestData.rgbCube( width: 4, height: 3 )
        let loader = FITSImageLoader( url: self.url, data: data )

        await loader.load()

        #expect( loader.error == nil )

        let image = try #require( loader.image, "an RGB cube loads as a LoadedImage" )

        #expect( image.graph == nil, "an RGB image is a raster, not a graph" )
        #expect( image.isColor, "combined RGB planes are a colour image" )
        #expect( image.isColorFilterArray == false, "RGB planes are colour without being a colour-filter array" )

        let source = try image.renderer.renderSourceSnapshot()

        #expect( source.detectionImage != nil, "the RGB luminance detection image must be built for star detection" )
    }

    /// The RGB image renders through the colour pipeline: the result is tagged as
    /// an `.rgb` input (so it is shown as colour, not mono) at the plane dimensions.
    @Test
    @MainActor
    func rendersRGBPlanesAsColor() async throws
    {
        let data   = FITSTestData.rgbCube( width: 4, height: 3 )
        let loader = FITSImageLoader( url: self.url, data: data )

        await loader.load()

        let image  = try #require( loader.image )
        let result = try image.renderer.renderSourceSnapshot().makeResult( settings: ImageProcessor.Settings() )

        #expect( result.inputPixelFormat == .rgb )
        #expect( result.image.width  == 4 )
        #expect( result.image.height == 3 )
    }

    /// The checked-in `RGBImage.fits` fixture — a real `BITPIX = 16`, `NAXIS = 3`
    /// colour image with a TAN WCS — loads as a colour raster carrying its WCS.
    @Test
    @MainActor
    func loadsBundledRGBFixtureAsColor() async throws
    {
        let url    = TestFixtures.rgbImage
        let loader = FITSImageLoader( url: url, data: try Data( contentsOf: url ) )

        await loader.load()

        #expect( loader.error == nil )

        let image = try #require( loader.image, "the fixture loads as a LoadedImage" )

        #expect( image.graph == nil )
        #expect( image.isColor )
        #expect( image.isColorFilterArray == false )
        #expect( image.wcs != nil, "the fixture carries a TAN WCS the overlays can use" )

        let result = try image.renderer.renderSourceSnapshot().makeResult( settings: ImageProcessor.Settings() )

        #expect( result.inputPixelFormat == .rgb )
        #expect( result.image.width  == 24 )
        #expect( result.image.height == 16 )
    }

    /// The per-channel cursor read-out of the loaded RGB image returns three values.
    @Test
    @MainActor
    func rgbImageReportsThreeChannelReadout() async throws
    {
        let data   = FITSTestData.rgbCube( width: 2, height: 2 )
        let loader = FITSImageLoader( url: self.url, data: data )

        await loader.load()

        let image  = try #require( loader.image )
        let values = try #require( image.renderer.renderSourceSnapshot().pixelValues( atX: 0, y: 0 ) )

        #expect( values.count == 3, "an RGB image reports a value per channel" )
    }
}
