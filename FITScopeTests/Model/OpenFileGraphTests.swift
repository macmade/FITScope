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
import Testing

/// Tests that an ``OpenFile`` backed by a one-dimensional (graph) FITS file loads
/// as a graph image and reaches a ready state without a render pipeline.
@Suite( "OpenFile (graph)" )
struct OpenFileGraphTests
{
    /// The URL used for the synthesized in-memory file.
    private let url = URL( fileURLWithPath: "/tmp/spectrum.fits" )

    /// Builds an open file backed by a loader for a synthesized 1-D FITS file, and
    /// loads it.
    ///
    /// - Returns: The loaded open file.
    @MainActor
    private func loadedGraphFile() async -> OpenFile
    {
        let data   = FITSTestData.oneDimensional( samples: [ 10, 20, 30, 40 ], extraRecords: [ "CTYPE1  = 'WAVE'", "CDELT1  = 2.0", "CRVAL1  = 400.0" ] )
        let loader = FITSImageLoader( url: self.url, data: data )
        let file   = OpenFile( url: self.url, loader: loader )

        await file.load()

        return file
    }

    /// A graph file loads as a `LoadedImage` carrying the decoded series and its
    /// header metadata, and is a single (non-carouselled) frame.
    @Test
    @MainActor
    func loadsGraphImage() async throws
    {
        let file  = await self.loadedGraphFile()
        let image = try #require( file.image, "a 1-D file still loads as a LoadedImage" )

        #expect( image.graph != nil, "the loaded image must carry a decoded graph series" )
        #expect( image.metadata.sections.isEmpty == false, "the header metadata feeds the Info window" )
        #expect( file.frames.count == 1, "a graph file is a single, non-carouselled frame" )
    }

    /// A decoded graph is ready — it has no render pipeline to wait on — with no
    /// warning and no adjustments.
    @Test
    @MainActor
    func reachesReadyWithoutRendering() async throws
    {
        let file = await self.loadedGraphFile()

        #expect( file.renderPhase == .ready, "a decoded graph is immediately ready" )
        #expect( file.warning == nil, "a successfully loaded graph raises no warning" )
        #expect( file.hasAdjustments == false, "a graph has no adjustments" )
        #expect( file.weight == nil, "a graph carries no weighting metrics" )
    }
}
