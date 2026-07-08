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

/// Tests that `FITSImageLoader` opens a multi-image `NAXIS=3` cube as one frame per
/// plane, surfaced through the frame list, without regressing the single-image path.
@Suite( "FITSImageLoader (multi-image)" )
struct FITSImageLoaderMultiImageTests
{
    /// The URL used for the synthesized in-memory files.
    private let url = URL( fileURLWithPath: "/tmp/cube.fits" )

    /// A multi-image cube loads as one ``LoadedImage`` per plane: the frame list has
    /// the plane count, the primary ``image`` is the first frame, and every frame is
    /// a raster (no graph) monochrome image.
    @Test
    @MainActor
    func loadsMultiImageCubeAsFrames() async throws
    {
        let data   = FITSTestData.multiImageCube( width: 4, height: 3, planes: 4 )
        let loader = FITSImageLoader( url: self.url, data: data )

        await loader.load()

        #expect( loader.error == nil )
        #expect( loader.frames.count == 4, "a 4-plane cube exposes four frames" )
        #expect( loader.image === loader.frames.first, "the primary image is the first frame" )

        for frame in loader.frames
        {
            #expect( frame.graph == nil, "a cube plane is a raster, not a graph" )
            #expect( frame.isColor == false, "a decoded cube plane is a monochrome image" )
        }
    }

    /// Each frame is an independent render source over its own plane: it renders at
    /// the plane dimensions, as a monochrome input, and reads back its own distinct
    /// pixel values (the builder fills plane `p` starting at `(p + 1) · 20`).
    @Test
    @MainActor
    func eachFrameRendersToItsOwnPlane() async throws
    {
        let data   = FITSTestData.multiImageCube( width: 4, height: 3, planes: 4 )
        let loader = FITSImageLoader( url: self.url, data: data )

        await loader.load()

        for ( index, frame ) in loader.frames.enumerated()
        {
            let source = try frame.renderer.renderSourceSnapshot()
            let result = try source.makeResult( settings: ImageProcessor.Settings() )

            #expect( result.image.width  == 4 )
            #expect( result.image.height == 3 )
            #expect( result.inputPixelFormat == .mono, "a cube plane is a single-channel image" )

            let values = try #require( source.pixelValues( atX: 0, y: 0 ), "a plane reports a single-channel read-out" )

            #expect( values.count == 1 )
            #expect( values[ 0 ].value == Double( ( index + 1 ) * 20 ), "each frame reads its own plane's samples" )
        }
    }

    /// The frames render independently: each plane's frame carries its own detection
    /// image, built from that plane's samples, so star detection runs per frame.
    @Test
    @MainActor
    func eachFrameCarriesItsOwnDetectionImage() async throws
    {
        let data   = FITSTestData.multiImageCube( width: 4, height: 3, planes: 4 )
        let loader = FITSImageLoader( url: self.url, data: data )

        await loader.load()

        for frame in loader.frames
        {
            let source = try frame.renderer.renderSourceSnapshot()

            #expect( source.detectionImage != nil, "each cube plane has a detection image for star detection" )
        }
    }

    /// A three-plane cube is claimed by the (relaxed) RGB rule, so it loads as a
    /// single combined colour frame rather than three monochrome frames.
    @Test
    @MainActor
    func threePlaneCubeStaysASingleColorFrame() async throws
    {
        let data   = FITSTestData.rgbCube( width: 4, height: 3, extraRecords: [] )
        let loader = FITSImageLoader( url: self.url, data: data )

        await loader.load()

        #expect( loader.error == nil )
        #expect( loader.frames.count == 1, "a 3-plane cube is one colour image, not three frames" )

        let image = try #require( loader.image )

        #expect( image.isColor, "combined RGB planes are a colour image" )
    }

    /// A `NAXIS=3` file with a physical `CTYPE3` is neither RGB nor a multi-image
    /// stack. It degrades gracefully: it loads with its metadata as a single frame
    /// and surfaces the error only at render — matching a malformed 2-D file.
    @Test
    @MainActor
    func physicalCubeLoadsWithMetadataAndErrorsAtRender() async throws
    {
        let data   = FITSTestData.multiImageCube( width: 4, height: 3, planes: 4, extraRecords: [ "CTYPE3  = 'WAVE'" ] )
        let loader = FITSImageLoader( url: self.url, data: data )

        await loader.load()

        #expect( loader.error == nil, "the file parses, so it loads with its metadata" )
        #expect( loader.frames.count == 1, "an unsupported cube is not split into frames" )

        let image = try #require( loader.image )

        #expect( image.metadata.sections.isEmpty == false, "the header metadata is available for the Info window" )

        await image.renderer.render()

        #expect( image.renderer.result == nil, "an unsupported cube cannot render" )
        #expect( image.renderer.error != nil, "the failure surfaces at render, not at load" )
    }

    /// The checked-in `MultiImage3D.fits` fixture — a real `NAXIS=3` cube of several
    /// distinct image planes — loads as one frame per plane, each rendering.
    @Test
    @MainActor
    func loadsBundledMultiImageFixtureAsFrames() async throws
    {
        let url    = TestFixtures.multiImageCube
        let loader = FITSImageLoader( url: url, data: try Data( contentsOf: url ) )

        await loader.load()

        #expect( loader.error == nil )
        #expect( loader.frames.count > 1, "the fixture holds several image planes" )

        for frame in loader.frames
        {
            #expect( frame.graph == nil )

            let result = try frame.renderer.renderSourceSnapshot().makeResult( settings: ImageProcessor.Settings() )

            #expect( result.image.width  > 0 )
            #expect( result.image.height > 0 )
        }
    }
}
