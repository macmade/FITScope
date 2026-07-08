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

/// Tests that `FITSImageLoader` routes a one-dimensional (`NAXIS=1`) file to a
/// graph rather than an image, without regressing the raster path.
@Suite( "FITSImageLoader (graph)" )
struct FITSImageLoaderGraphTests
{
    /// The URL used for the synthesized in-memory files.
    private let url = URL( fileURLWithPath: "/tmp/spectrum.fits" )

    /// A `NAXIS=1` file loads as a graph: the loaded image carries a decoded series
    /// (with the WCS axis) and the parsed header metadata, but no rendered pixels.
    @Test
    @MainActor
    func loadsOneDimensionalFileAsGraph() async throws
    {
        let data   = FITSTestData.oneDimensional( samples: [ 10, 20, 30, 40 ], extraRecords: [ "CTYPE1  = 'WAVE'", "CDELT1  = 2.0", "CRVAL1  = 400.0" ] )
        let loader = FITSImageLoader( url: self.url, data: data )

        await loader.load()

        #expect( loader.error == nil )

        let image = try #require( loader.image, "a 1-D file still loads as a LoadedImage" )
        let graph = try #require( image.graph, "a 1-D file must carry a decoded graph series" )

        #expect( graph.points.count == 4 )
        #expect( graph.xAxisLabel == "WAVE" )
        #expect( image.information != nil, "the graph must carry a display summary for the sidebar" )
        #expect( image.metadata.sections.isEmpty == false, "the graph must carry the parsed header metadata" )
    }

    /// The checked-in `Spectrum1D.fits` fixture — a real `BITPIX = -32`, `NAXIS = 1`
    /// spectrum with a `WAVE` world-coordinate axis — loads as a graph with the
    /// physical wavelength axis and flux unit read from its header.
    @Test
    @MainActor
    func loadsBundledSpectrumFixtureAsGraph() async throws
    {
        let url    = TestFixtures.spectrum1D
        let loader = FITSImageLoader( url: url, data: try Data( contentsOf: url ) )

        await loader.load()

        #expect( loader.error == nil )

        let image = try #require( loader.image, "the fixture loads as a LoadedImage" )
        let graph = try #require( image.graph, "the fixture is one-dimensional, so it is a graph" )

        #expect( graph.points.count == 512 )
        #expect( graph.xAxisLabel == "WAVE (Angstrom)" )
        #expect( graph.yAxisLabel == "erg/s/cm2/A" )

        // The WCS axis: CRVAL1 = 4000, CRPIX1 = 1, CDELT1 = 2 → first two samples at
        // 4000 and 4002 Angstrom.
        #expect( graph.points.first?.x == 4000.0 )
        #expect( graph.points.dropFirst().first?.x == 4002.0 )
    }

    /// A malformed 1-D file (unsupported `BITPIX`) degrades gracefully like a
    /// malformed 2-D file: it still loads with its header metadata (no graph), and
    /// the error surfaces at render rather than failing the whole load — so the Info
    /// window stays available.
    @Test
    @MainActor
    func malformedOneDimensionalFileDegradesGracefully() async throws
    {
        let url    = TestFixtures.invalidSpectrum1D
        let loader = FITSImageLoader( url: url, data: try Data( contentsOf: url ) )

        await loader.load()

        #expect( loader.error == nil, "an undecodable 1-D file must still load (not fail the whole load)" )

        let image = try #require( loader.image, "the file loads so its metadata stays available" )

        #expect( image.graph == nil, "an undecodable 1-D HDU falls through to the raster path" )
        #expect( image.metadata.sections.isEmpty == false, "the header metadata is available for the Info window" )

        await image.renderer.render()

        #expect( image.renderer.result == nil, "the unsupported pixel format cannot render" )
        #expect( image.renderer.error != nil, "the error surfaces at render, matching a malformed 2-D file" )
    }

    /// A two-dimensional file still loads as a normal image with no graph — the graph
    /// branch must not regress the raster path.
    @Test
    @MainActor
    func loadsTwoDimensionalFileAsImage() async throws
    {
        let url    = TestFixtures.monoImage
        let loader = FITSImageLoader( url: url, data: try Data( contentsOf: url ) )

        await loader.load()

        let image = try #require( loader.image, "a 2-D file must produce a raster image" )

        #expect( image.graph == nil, "a 2-D file must not carry a graph series" )
    }

    /// A successful graph load is idempotent: a second `load()` keeps the same image
    /// instance rather than reparsing.
    @Test
    @MainActor
    func graphLoadIsIdempotent() async throws
    {
        let data   = FITSTestData.oneDimensional( samples: [ 1, 2, 3 ] )
        let loader = FITSImageLoader( url: self.url, data: data )

        await loader.load()

        let first = try #require( loader.image )

        await loader.load()

        let second = try #require( loader.image )

        #expect( first === second, "a successful graph load must not be repeated" )
        #expect( first.graph != nil )
    }
}
