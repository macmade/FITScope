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
        let url  = TestFixtures.monoImage
        let file = OpenFile( url: url )

        #expect( file.url == url )
        #expect( file.displayName == "MonoImage.fits" )
    }

    @Test
    @MainActor
    func loadPopulatesImage() async throws
    {
        let url  = TestFixtures.monoImage
        let file = OpenFile( url: url )

        await file.load()

        #expect( file.image != nil, "a successful load must expose the image" )
        #expect( file.error == nil )
    }

    @Test
    @MainActor
    func distinctInstancesHaveDistinctIdentity() throws
    {
        let url = TestFixtures.monoImage

        #expect( OpenFile( url: url ).id != OpenFile( url: url ).id, "each open file is a distinct entry even for the same URL" )
    }

    @Test
    @MainActor
    func loadAndRenderProducesThumbnail() async throws
    {
        let url  = TestFixtures.monoImage
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
        let url  = TestFixtures.monoImage
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
        let file     = OpenFile( url: TestFixtures.monoImage )
        let throttle = RenderThrottle( limit: 2 )

        file.prepare( throttle: throttle )

        await file.preparation?.value

        #expect( file.renderPhase == .ready, "prepare loads and renders the file without it being displayed" )
        #expect( file.thumbnail != nil, "prepare also produces the sidebar thumbnail" )
    }

    @Test
    @MainActor
    func thumbnailIsRegeneratedWhenTheRenderResultChanges() async throws
    {
        let file     = OpenFile( url: TestFixtures.monoImage )
        let throttle = RenderThrottle( limit: 2 )

        file.prepare( throttle: throttle )

        await file.preparation?.value
        await file.thumbnailTask?.value

        let initial = try #require( file.thumbnail, "prepare must produce an initial thumbnail" )

        // Change an adjustment that alters the rendered pixels, then re-render:
        // the thumbnail must be regenerated to reflect the new processing rather
        // than staying at the originally rendered version.
        let renderer = try #require( file.image?.renderer )

        renderer.adjustments.invert = true

        await renderer.render()
        await file.thumbnailTask?.value

        let updated = try #require( file.thumbnail )

        #expect( updated !== initial, "a new render result must regenerate the sidebar thumbnail" )
    }

    @Test
    @MainActor
    func prepareIsIdempotent() async throws
    {
        let file     = OpenFile( url: TestFixtures.monoImage )
        let throttle = RenderThrottle( limit: 2 )

        file.prepare( throttle: throttle )

        let started = try #require( file.preparation )

        // A second prepare while one is in flight must not start another.
        file.prepare( throttle: throttle )

        await started.value
        await file.preparation?.value

        #expect( file.renderPhase == .ready )
    }

    @Test
    @MainActor
    func warningFlagsAFileThatCannotBeDisplayed() async throws
    {
        let file = OpenFile( url: TestFixtures.invalidImage )

        await file.load()
        await file.image?.renderer.render()

        #expect( file.warning != nil, "a file that fails to load must surface a warning for the attention icon" )
    }

    @Test
    @MainActor
    func noWarningForAHealthyFile() async throws
    {
        let file = OpenFile( url: TestFixtures.monoImage )

        await file.load()
        await file.image?.renderer.render()

        #expect( file.warning == nil, "a file that loads and renders has nothing to flag" )
    }

    @Test
    @MainActor
    func noWarningWhileStillLoading() throws
    {
        let file = OpenFile( url: TestFixtures.monoImage )

        #expect( file.warning == nil, "a file still loading has no failure to flag yet" )
    }

    @Test
    @MainActor
    func noWarningWhenABadAdjustmentRetainsTheLastGoodResult() async throws
    {
        let file = OpenFile( url: TestFixtures.monoImage )

        await file.load()
        await file.image?.renderer.render()

        let renderer = try #require( file.image?.renderer )

        #expect( file.warning == nil )

        // A mathematically invalid parameter fails the re-render, but the last
        // good result is retained and still displayed — so the row, which still
        // shows a usable image, must not be flagged.
        renderer.adjustments.stretch = .arcsinh( 0 )

        await renderer.render()

        #expect( renderer.error != nil, "the bad adjustment must have failed the render" )
        #expect( file.warning == nil, "a retained good result must not raise a warning" )
    }

    @Test
    @MainActor
    func copyingOriginalFileProducesAByteIdenticalCopy() throws
    {
        let bytes       = Data( ( 0 ..< 4096 ).map { UInt8( $0 % 256 ) } )
        let source      = Self.temporaryURL()
        let destination = Self.temporaryURL()

        try bytes.write( to: source )

        defer
        {
            try? FileManager.default.removeItem( at: source )
            try? FileManager.default.removeItem( at: destination )
        }

        let file = OpenFile( url: source )

        try file.copyOriginalFile( to: destination )

        #expect( try Data( contentsOf: destination ) == bytes, "the saved copy must be byte-identical to the original" )
    }

    @Test
    @MainActor
    func copyingOriginalFileOverwritesAnExistingDestination() throws
    {
        let original    = Data( ( 0 ..< 2048 ).map { UInt8( $0 % 256 ) } )
        let source      = Self.temporaryURL()
        let destination = Self.temporaryURL()

        try original.write( to: source )
        try Data( "stale contents".utf8 ).write( to: destination )

        defer
        {
            try? FileManager.default.removeItem( at: source )
            try? FileManager.default.removeItem( at: destination )
        }

        let file = OpenFile( url: source )

        try file.copyOriginalFile( to: destination )

        #expect( try Data( contentsOf: destination ) == original, "saving over an existing file replaces it with a byte-identical copy of the original" )
    }

    @Test
    @MainActor
    func copyingOriginalFileToItsOwnURLLeavesItIntact() throws
    {
        let original = Data( ( 0 ..< 1024 ).map { UInt8( $0 % 256 ) } )
        let source   = Self.temporaryURL()

        try original.write( to: source )

        defer { try? FileManager.default.removeItem( at: source ) }

        let file = OpenFile( url: source )

        // Saving a file onto itself must not delete-then-fail and lose the data.
        try file.copyOriginalFile( to: source )

        #expect( try Data( contentsOf: source ) == original, "saving a file onto itself must leave it intact" )
    }

    /// A unique temporary `.fits` URL for the file-copy tests.
    private static func temporaryURL() -> URL
    {
        URL( fileURLWithPath: NSTemporaryDirectory() ).appendingPathComponent( "FITScopeSaveAsTest-\( UUID().uuidString ).fits" )
    }
}
