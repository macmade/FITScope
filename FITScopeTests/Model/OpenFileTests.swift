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

    @Test
    func renderPhaseMapsPipelineState() throws
    {
        // Not yet parsed → loading.
        #expect( OpenFile.renderPhase( hasImage: false, hasResult: false, hasError: false, isRendering: false ) == .loading )

        // Parsed, no committed result yet → still rendering (the bug: this read
        // as "done" because it keyed off the parsed image, not the result).
        #expect( OpenFile.renderPhase( hasImage: true, hasResult: false, hasError: false, isRendering: false ) == .rendering )

        // Parsed and rendered → ready.
        #expect( OpenFile.renderPhase( hasImage: true, hasResult: true, hasError: false, isRendering: false ) == .ready )

        // A failure wins, whether it came from loading (no image) or rendering.
        #expect( OpenFile.renderPhase( hasImage: false, hasResult: false, hasError: true, isRendering: false ) == .failed )
        #expect( OpenFile.renderPhase( hasImage: true,  hasResult: false, hasError: true, isRendering: false ) == .failed )
    }

    @Test
    func renderPhaseReportsRenderingWhileAReRenderIsInFlight() throws
    {
        // A re-render keeps the last good result committed, so without the
        // in-flight signal this would read as `.ready` and the sidebar spinner /
        // processing affordances would never show during a re-render.
        #expect( OpenFile.renderPhase( hasImage: true, hasResult: true, hasError: false, isRendering: true ) == .rendering )

        // Re-rendering away from a prior failed parameter is work in progress,
        // not a failure — the retained error must not win over the live render.
        #expect( OpenFile.renderPhase( hasImage: true, hasResult: true, hasError: true, isRendering: true ) == .rendering )
    }

    @Test
    func renderPhaseInProgressCoversLoadingAndRendering() throws
    {
        #expect( OpenFile.RenderPhase.loading.isInProgress )
        #expect( OpenFile.RenderPhase.rendering.isInProgress )
        #expect( OpenFile.RenderPhase.ready.isInProgress  == false )
        #expect( OpenFile.RenderPhase.failed.isInProgress == false )
    }

    @Test
    @MainActor
    func renderPhaseTracksLoadThenRender() async throws
    {
        let url  = FITSCorpus.url( "NASA/FOSy19g0309t_c2f.fits" )
        let file = OpenFile( url: url )

        #expect( file.renderPhase == .loading, "a freshly opened file is loading" )

        await file.load()
        await file.image?.renderer.render()

        #expect( file.renderPhase == .ready, "after loading and rendering the file is ready" )
    }

    @Test
    @MainActor
    func prepareLoadsRendersAndThumbnails() async throws
    {
        let file     = OpenFile( url: FITSCorpus.url( "NASA/FOSy19g0309t_c2f.fits" ) )
        let throttle = RenderThrottle( limit: 2 )

        file.prepare( throttle: throttle )

        await file.preparation?.value

        #expect( file.renderPhase == .ready, "prepare loads and renders the file without it being displayed" )
        #expect( file.thumbnail != nil, "prepare also produces the sidebar thumbnail" )
    }

    @Test
    @MainActor
    func prepareIsIdempotent() async throws
    {
        let file     = OpenFile( url: FITSCorpus.url( "NASA/FOSy19g0309t_c2f.fits" ) )
        let throttle = RenderThrottle( limit: 2 )

        file.prepare( throttle: throttle )

        let started = try #require( file.preparation )

        // A second prepare while one is in flight must not start another.
        file.prepare( throttle: throttle )

        await started.value
        await file.preparation?.value

        #expect( file.renderPhase == .ready )
    }
}
