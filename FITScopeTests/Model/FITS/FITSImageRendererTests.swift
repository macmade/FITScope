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
import SwiftPixel
import Testing

/// Behavioural tests for `FITSImageRenderer`: HDU selection error paths, the
/// Sendable render boundary, debounced re-rendering, and the non-destructive
/// handling of render failures.
@Suite( "FITSImageRenderer" )
struct FITSImageRendererTests
{
    /// A minimal header-only FITS file (`NAXIS=0`, single section) must surface
    /// a clean, typed error and never trap: with a single section there is no
    /// data section to render, and the selection must not index a fixed
    /// position.
    @Test
    @MainActor
    func headerOnlyFileErrorsCleanly() async throws
    {
        let data = FITSTestData.headerOnly()
        let file = try FITSFile( data: data, options: .lenient )

        // A single header section, no data section.
        try #require( file.sections.count == 1 )

        let renderer = FITSImageRenderer( file: file )

        await renderer.render()

        #expect( renderer.result == nil, "header-only input should not render" )

        let message = renderer.error.map { "\( $0 )" } ?? ""

        #expect( message.contains( "no image HDU" ), "expected a typed no-image-HDU error, got: \"\( message )\"" )
    }

    /// A valid `BITPIX = 64` image is a format the pixel pipeline does not
    /// support; it must surface a clear, typed error naming the limitation.
    @Test
    @MainActor
    func unsupportedBitpixProducesClearError() async throws
    {
        let file     = try FITSFile( data: FITSTestData.bitpix64(), options: .lenient )
        let renderer = FITSImageRenderer( file: file )

        await renderer.render()

        #expect( renderer.result == nil, "an unsupported BITPIX should not render" )

        let message = renderer.error.map { "\( $0 )" } ?? ""

        #expect( message.contains( "BITPIX 64 is not supported" ), "expected a clear unsupported-BITPIX error, got: \"\( message )\"" )
    }

    /// The render boundary accepts only Sendable values: a `RenderInput` built
    /// off the main actor renders the same histogram as a direct render of the
    /// same input. Pins behaviour across the Sendable-boundary refactor.
    @Test
    @MainActor
    func renderInputCrossesTheConcurrencyBoundary() async throws
    {
        let url = TestFixtures.monoImage

        // Resolve the Sendable render input off the main actor; only the input
        // (never the non-Sendable FITSFile) crosses back to the renderer.
        let input = try await Task.detached
        {
            let file = try FITSFile( data: Data( contentsOf: url ), options: .lenient )

            return try FITSImageRenderer.renderInput( from: file.sections )
        }
        .value

        let renderer = FITSImageRenderer( input: input )

        await renderer.render()

        let result = try #require( renderer.result )
        let direct = try ImageProcessor.render( data: input.data, properties: input.properties )

        // The histogram is the observable product of the rendered bytes: equal
        // histograms confirm the off-actor input rendered identically.
        #expect( result.histogram.rgb       == SwiftPixel.Histogram( bytes: direct.bytes, channels: 3, mode: .rgb ) )
        #expect( result.histogram.luminance == SwiftPixel.Histogram( bytes: direct.bytes, channels: 3, mode: .luminance ) )
    }

    /// The committed result records the orientation it was rendered with, so a
    /// source-space overlay can reorient in lock-step with the image — and only
    /// once the new render commits, never while a rotation is still in flight.
    @Test
    @MainActor
    func resultCarriesTheRenderedOrientation() async throws
    {
        let url   = TestFixtures.monoImage
        let input = try await Task.detached
        {
            let file = try FITSFile( data: Data( contentsOf: url ), options: .lenient )

            return try FITSImageRenderer.renderInput( from: file.sections )
        }
        .value

        let renderer = FITSImageRenderer( input: input )

        await renderer.render()

        #expect( renderer.result?.orientation == .identity, "a default render is unrotated" )

        renderer.adjustments.orientation = .init( rotation: .clockwise90, mirroredHorizontally: false )

        await renderer.render()

        #expect( renderer.result?.orientation == .init( rotation: .clockwise90, mirroredHorizontally: false ), "the result records the orientation it was rendered with" )
    }

    /// Changing an adjustment and triggering the debounced re-render entry point
    /// produces a render distinct from the default one.
    @Test
    @MainActor
    func reRenderWithChangedAdjustmentsProducesNewResult() async throws
    {
        let file     = try FITSFile( data: Data( contentsOf: TestFixtures.monoImage ), options: .lenient )
        let input    = try FITSImageRenderer.renderInput( from: file.sections )
        let renderer = FITSImageRenderer( input: input )

        await renderer.render()

        let original = try #require( renderer.result?.histogram.rgb )

        renderer.adjustments.stretch = .log( 10 )
        renderer.scheduleReRender()
        await renderer.pendingRender?.value

        let updated = try #require( renderer.result?.histogram.rgb )

        #expect( updated != original )
    }

    /// Rapid re-render requests coalesce: scheduling a newer one cancels the
    /// prior pending task, so a burst of changes (e.g. a slider drag) does not
    /// spawn a render for every intermediate value.
    @Test
    @MainActor
    func rapidReRendersCancelThePriorPending() async throws
    {
        let file     = try FITSFile( data: Data( contentsOf: TestFixtures.monoImage ), options: .lenient )
        let input    = try FITSImageRenderer.renderInput( from: file.sections )
        let renderer = FITSImageRenderer( input: input )

        renderer.scheduleReRender()
        let first = try #require( renderer.pendingRender )

        renderer.scheduleReRender()
        let latest = try #require( renderer.pendingRender )

        #expect( first.isCancelled, "scheduling a newer re-render must cancel the prior pending one" )
        #expect( latest.isCancelled == false, "the latest scheduled re-render stays live" )

        // Don't leave the debounced render running past the test.
        latest.cancel()
    }

    /// A burst of changes renders only the final state: after rapid re-render
    /// requests the committed result reflects the last adjustment, never an
    /// intermediate one that was superseded (no dropped or stale final render).
    @Test
    @MainActor
    func rapidChangesRenderOnlyTheFinalState() async throws
    {
        let file     = try FITSFile( data: Data( contentsOf: TestFixtures.monoImage ), options: .lenient )
        let input    = try FITSImageRenderer.renderInput( from: file.sections )
        let renderer = FITSImageRenderer( input: input )

        // An intermediate change, immediately superseded by the final one before
        // the debounce elapses.
        renderer.adjustments.orientation = .init( rotation: .clockwise90, mirroredHorizontally: false )
        renderer.scheduleReRender()
        let superseded = renderer.pendingRender

        renderer.adjustments.orientation = .init( rotation: .clockwise90, mirroredHorizontally: true )
        renderer.scheduleReRender()

        await renderer.pendingRender?.value

        #expect( superseded?.isCancelled == true, "the intermediate re-render must be coalesced away" )
        #expect( renderer.result?.orientation == .init( rotation: .clockwise90, mirroredHorizontally: true ), "the debounced render must reflect the final adjustment, not an intermediate one" )
    }

    /// A render failure must not strand the user: the thrown error surfaces but
    /// the last good render is retained, so the image and its controls survive.
    @Test
    @MainActor
    func failedRenderRetainsLastGoodResult() async throws
    {
        let file     = try FITSFile( data: Data( contentsOf: TestFixtures.monoImage ), options: .lenient )
        let input    = try FITSImageRenderer.renderInput( from: file.sections )
        let renderer = FITSImageRenderer( input: input )

        await renderer.render()

        let good = try #require( renderer.result )

        #expect( renderer.error == nil )

        // An arcsinh factor of zero is a mathematically invalid parameter the
        // pipeline rejects by throwing.
        renderer.adjustments.stretch = .arcsinh( 0 )

        await renderer.render()

        #expect( renderer.error  != nil )
        #expect( renderer.result != nil )
        #expect( renderer.result?.image === good.image, "the last good render must be retained on failure" )
    }

    /// A valid render after a failure clears the error and commits the new
    /// result, proving the failure state is recoverable.
    @Test
    @MainActor
    func validRenderAfterFailureRecovers() async throws
    {
        let file     = try FITSFile( data: Data( contentsOf: TestFixtures.monoImage ), options: .lenient )
        let input    = try FITSImageRenderer.renderInput( from: file.sections )
        let renderer = FITSImageRenderer( input: input )

        renderer.adjustments.stretch = .arcsinh( 0 )

        await renderer.render()

        #expect( renderer.error != nil )

        renderer.adjustments.stretch = .log( 50 )

        await renderer.render()

        #expect( renderer.error  == nil )
        #expect( renderer.result != nil )
    }

    /// A first-load failure with no prior result keeps `result` nil so the
    /// full-screen error path is preserved for the genuine no-image case.
    @Test
    @MainActor
    func firstLoadFailureHasNoResult() async throws
    {
        let renderer = FITSImageRenderer( input: FITSImageRenderer.RenderInput( data: Data(), properties: [] ) )

        await renderer.render()

        #expect( renderer.result == nil )
        #expect( renderer.error  != nil )
    }

    /// When two renders are in flight, the later-started one wins regardless of
    /// which commits last: a stale (superseded) success must not overwrite the
    /// newer result.
    @Test
    @MainActor
    func laterStartedRenderWinsRegardlessOfCommitOrder() async throws
    {
        let file     = try FITSFile( data: Data( contentsOf: TestFixtures.monoImage ), options: .lenient )
        let input    = try FITSImageRenderer.renderInput( from: file.sections )
        let renderer = FITSImageRenderer( input: input )

        await renderer.render()

        let older = try #require( renderer.result )

        renderer.adjustments.stretch = .log( 10 )

        await renderer.render()

        let newer = try #require( renderer.result )

        // Replay two in-flight renders finishing out of order: the newer
        // generation commits first, then the older (now stale) one commits.
        let olderGeneration = renderer.nextRenderGeneration()
        let newerGeneration = renderer.nextRenderGeneration()

        renderer.commit( .success( newer ), generation: newerGeneration )
        renderer.commit( .success( older ), generation: olderGeneration )

        #expect( renderer.result?.image === newer.image, "the later-started render must win" )
    }

    /// A stale render completing after a newer one has started must neither
    /// overwrite the newer result nor resurrect a cleared error.
    @Test
    @MainActor
    func staleRenderDoesNotClobberNewerResult() async throws
    {
        let file     = try FITSFile( data: Data( contentsOf: TestFixtures.monoImage ), options: .lenient )
        let input    = try FITSImageRenderer.renderInput( from: file.sections )
        let renderer = FITSImageRenderer( input: input )

        await renderer.render()

        let good = try #require( renderer.result )

        #expect( renderer.error == nil )

        // A newer render starts, superseding the one that produced `good` ...
        let newerGeneration = renderer.nextRenderGeneration()

        // ... so that earlier render failing late must be dropped.
        renderer.commit( .failure( StaleError() ), generation: newerGeneration - 1 )

        #expect( renderer.result?.image === good.image, "a stale failure must not drop the result" )
        #expect( renderer.error == nil,                 "a stale failure must not resurrect an error" )
    }

    /// The histogram is built with the rendered buffer's real channel count, so
    /// the per-channel stride can never silently mis-read a non-3-channel image.
    @Test
    @MainActor
    func histogramChannelCountMatchesRenderedBuffer() async throws
    {
        let ( data, properties ) = FITSTestData.gradient()
        let renderer             = FITSImageRenderer( input: FITSImageRenderer.RenderInput( data: data, properties: properties ) )

        await renderer.render()

        let result = try #require( renderer.result )
        let direct = try ImageProcessor.render( data: data, properties: properties )

        #expect( result.histogram.rgb.data.count == direct.channels, "the histogram must use the rendered buffer's channel count" )
    }

    /// A non-debayered image is flagged monochrome and carries a single-channel
    /// histogram matching a direct mono histogram of its bytes, so the inspector
    /// can present one histogram rather than a redundant RGB triple. (The pipeline
    /// still emits 3 replicated channels, so this is driven by the debayer state,
    /// not the channel count.)
    @Test
    @MainActor
    func nonDebayeredImageIsFlaggedMono() async throws
    {
        let ( data, properties ) = FITSTestData.gradient()
        let renderer             = FITSImageRenderer( input: FITSImageRenderer.RenderInput( data: data, properties: properties ) )

        await renderer.render()

        let result = try #require( renderer.result )
        let direct = try ImageProcessor.render( data: data, properties: properties )

        #expect( direct.isMonochrome, "an image with no Bayer pattern must render as monochrome" )
        #expect( result.histogram.isMono, "a non-debayered render must be flagged mono" )
        #expect( result.histogram.mono == SwiftPixel.Histogram( bytes: direct.bytes, channels: direct.channels, mode: .mono ) )
        #expect( result.histogram.mono.data.count == 1 )
        #expect( result.statistics.mono.count == result.statistics.luminance.count )
    }

    /// A debayered (colour-filter-array) image is not monochrome, so the inspector
    /// keeps the RGB/luminance presentation rather than the single mono histogram.
    @Test
    @MainActor
    func debayeredImageIsNotFlaggedMono() async throws
    {
        let ( data, baseProperties ) = FITSTestData.gradient()

        // A Bayer pattern makes the default `.auto` debayer demosaic to true RGB.
        let properties = baseProperties + [ FITSPropertySnapshot( name: "BAYERPAT", value: .string( "RGGB" ) ) ]

        let renderer = FITSImageRenderer( input: FITSImageRenderer.RenderInput( data: data, properties: properties ) )

        await renderer.render()

        let result = try #require( renderer.result )
        let direct = try ImageProcessor.render( data: data, properties: properties )

        #expect( direct.isMonochrome == false, "an image with a Bayer pattern must render as colour" )
        #expect( result.histogram.isMono == false, "a debayered render must not be flagged mono" )
    }

    /// The colour fixture used by the UI suite is a valid Bayer image that
    /// demosaics to true RGB, so it is not flagged monochrome. Guards against a
    /// broken fixture far faster than the UI test that depends on it.
    @Test
    @MainActor
    func colorFixtureRendersAsColor() async throws
    {
        let file     = try FITSFile( data: Data( contentsOf: TestFixtures.colorImage ), options: .lenient )
        let input    = try FITSImageRenderer.renderInput( from: file.sections )
        let renderer = FITSImageRenderer( input: input )

        await renderer.render()

        let result = try #require( renderer.result, "the colour fixture must render" )

        #expect( result.histogram.isMono == false, "the colour fixture must render as colour, not mono" )
    }

    /// The rendered histogram is compared by identity, not by its (large) bin
    /// arrays, so SwiftUI's view-graph diffing never deep-compares the bins on
    /// the main thread — the cause of a beachball when switching between
    /// already-rendered images.
    @Test
    @MainActor
    func histogramComparesByIdentityNotContents() async throws
    {
        let file     = try FITSFile( data: Data( contentsOf: TestFixtures.monoImage ), options: .lenient )
        let input    = try FITSImageRenderer.renderInput( from: file.sections )
        let renderer = FITSImageRenderer( input: input )

        await renderer.render()

        let histogram = try #require( renderer.result?.histogram )
        let sameData  = FITSImageRenderer.Histogram( rgb: histogram.rgb, luminance: histogram.luminance, mono: histogram.mono, isMono: histogram.isMono )

        #expect( histogram == histogram, "the same histogram instance is equal to itself" )
        #expect( histogram != sameData,  "a distinct histogram with identical bins is not equal — compared by identity, so SwiftUI never deep-compares the bins" )
    }

    /// A freshly created renderer is not rendering until one is started.
    @Test
    @MainActor
    func isRenderingStartsFalse() throws
    {
        let renderer = FITSImageRenderer( input: FITSImageRenderer.RenderInput( data: Data(), properties: [] ) )

        #expect( renderer.isRendering == false )
    }

    /// A completed render leaves the in-flight flag clear, whichever way it
    /// finished, so the processing affordances return to the ready state.
    @Test
    @MainActor
    func renderClearsIsRenderingWhenComplete() async throws
    {
        let file     = try FITSFile( data: Data( contentsOf: TestFixtures.monoImage ), options: .lenient )
        let input    = try FITSImageRenderer.renderInput( from: file.sections )
        let renderer = FITSImageRenderer( input: input )

        await renderer.render()

        #expect( renderer.isRendering == false, "a finished render must clear the in-flight flag" )
    }

    /// Claiming a render generation marks the renderer as in flight; committing
    /// that latest generation clears it. This is the signal the sidebar spinner,
    /// status pill, disabled controls and canvas overlay all bind to.
    @Test
    @MainActor
    func committingTheLatestGenerationClearsIsRendering() async throws
    {
        let file     = try FITSFile( data: Data( contentsOf: TestFixtures.monoImage ), options: .lenient )
        let input    = try FITSImageRenderer.renderInput( from: file.sections )
        let renderer = FITSImageRenderer( input: input )

        await renderer.render()

        let good       = try #require( renderer.result )
        let generation = renderer.nextRenderGeneration()

        #expect( renderer.isRendering, "claiming a generation marks a render in flight" )

        renderer.commit( .success( good ), generation: generation )

        #expect( renderer.isRendering == false, "committing the latest render clears the flag" )
    }

    /// A stale render finishing after a newer one has started must not clear the
    /// in-flight flag — the newer render is still running, so the processing
    /// affordances must stay shown until it commits.
    @Test
    @MainActor
    func staleCommitLeavesIsRenderingForTheInFlightRender() async throws
    {
        let file     = try FITSFile( data: Data( contentsOf: TestFixtures.monoImage ), options: .lenient )
        let input    = try FITSImageRenderer.renderInput( from: file.sections )
        let renderer = FITSImageRenderer( input: input )

        await renderer.render()

        let good       = try #require( renderer.result )
        let generation = renderer.nextRenderGeneration()

        renderer.commit( .success( good ), generation: generation - 1 )

        #expect( renderer.isRendering, "a stale commit must not clear the flag while a newer render is in flight" )
    }

    /// The before/after comparison "before" image is produced lazily: a normal
    /// render never computes it, so a file that is never compared pays nothing.
    @Test
    @MainActor
    func comparisonImageIsNilUntilPrepared() async throws
    {
        let file     = try FITSFile( data: Data( contentsOf: TestFixtures.monoImage ), options: .lenient )
        let input    = try FITSImageRenderer.renderInput( from: file.sections )
        let renderer = FITSImageRenderer( input: input )

        await renderer.render()

        #expect( renderer.originalImage == nil, "the before image is not computed until requested" )
    }

    /// Preparing the "before" image renders the captured view and caches it, so a
    /// second request at the same orientation reuses it — toggling the comparison
    /// on and off does no extra work.
    @Test
    @MainActor
    func preparingTheComparisonImageCachesAndReusesIt() async throws
    {
        let file     = try FITSFile( data: Data( contentsOf: TestFixtures.monoImage ), options: .lenient )
        let input    = try FITSImageRenderer.renderInput( from: file.sections )
        let renderer = FITSImageRenderer( input: input )

        await renderer.render()
        await renderer.prepareOriginalImage()

        let first = try #require( renderer.originalImage, "preparing the before image must produce it" )

        await renderer.prepareOriginalImage()

        #expect( renderer.originalImage === first, "the before image is cached and reused at the same orientation" )
    }

    /// The "before" image follows the current orientation so it stays registered
    /// pixel-for-pixel with the processed result: a 90° rotation re-renders it and
    /// swaps its dimensions, invalidating the earlier cache.
    @Test
    @MainActor
    func theComparisonImageReRendersWhenOrientationChanges() async throws
    {
        // A non-square image so a 90° rotation is observable as swapped dimensions.
        let ( data, properties ) = FITSTestData.gradient( width: 16, height: 8 )
        let renderer             = FITSImageRenderer( input: FITSImageRenderer.RenderInput( data: data, properties: properties ) )

        await renderer.render()
        await renderer.prepareOriginalImage()

        let identity = try #require( renderer.originalImage )

        #expect( identity.width  == 16 )
        #expect( identity.height == 8 )

        renderer.adjustments.orientation = .init( rotation: .clockwise90, mirroredHorizontally: false )

        await renderer.prepareOriginalImage()

        let rotated = try #require( renderer.originalImage )

        #expect( rotated !== identity,  "a changed orientation re-renders the before image" )
        #expect( rotated.width  == 8,   "a 90° rotation swaps the dimensions" )
        #expect( rotated.height == 16 )
    }

    private struct StaleError: Error {}
}
