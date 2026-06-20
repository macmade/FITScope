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

/// Tests for `OpenFile`: identity, URL exposure and load delegation.
@Suite( "OpenFile" )
struct OpenFileTests
{
    @Test
    @MainActor
    func exposesURLAndDisplayName() throws
    {
        let url  = FITSCorpus.url( "NASA/FOSy19g0309t_c2f.fits" )
        let file = OpenFile( url: url )

        #expect( file.url == url )
        #expect( file.displayName == "FOSy19g0309t_c2f.fits" )
    }

    @Test
    @MainActor
    func loadPopulatesImage() async throws
    {
        let url  = FITSCorpus.url( "NASA/FOSy19g0309t_c2f.fits" )
        let file = OpenFile( url: url )

        await file.load()

        #expect( file.image != nil, "a successful load must expose the image" )
        #expect( file.error == nil )
    }

    @Test
    @MainActor
    func distinctInstancesHaveDistinctIdentity() throws
    {
        let url = FITSCorpus.url( "NASA/FOSy19g0309t_c2f.fits" )

        #expect( OpenFile( url: url ).id != OpenFile( url: url ).id, "each open file is a distinct entry even for the same URL" )
    }

    @Test
    @MainActor
    func loadAndRenderProducesThumbnail() async throws
    {
        let url  = FITSCorpus.url( "NASA/FOSy19g0309t_c2f.fits" )
        let file = OpenFile( url: url )

        await file.load()
        await file.image?.renderer.render()
        await file.makeThumbnail( maxDimension: 64 )

        let thumbnail = try #require( file.thumbnail )

        #expect( thumbnail.width <= 64 && thumbnail.height <= 64, "thumbnail is bounded by the requested max dimension" )
        #expect( thumbnail.width >= 1 && thumbnail.height >= 1 )
    }
}
