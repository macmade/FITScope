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
import SwiftAstro
import SwiftFITS
import SwiftPixel
import Testing

/// Behavioural tests for `ImageRenderer`: HDU selection error paths, the
/// Sendable render boundary, debounced re-rendering, and the non-destructive
/// handling of render failures.
@Suite( "ImageRenderer" )
struct ImageRendererTests
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

        let renderer = ImageRenderer( file: file )

        await renderer.render()

        #expect( renderer.result == nil, "header-only input should not render" )

        let message = renderer.error.map { "\( $0 )" } ?? ""

        #expect( message.contains( "no image HDU" ), "expected a typed no-image-HDU error, got: \"\( message )\"" )
    }

    /// A source that cannot decode ahead — an RGB colour-plane FITS frame, whose
    /// ``ImageRenderSource/decoded()`` returns `nil` — still renders: the render pass
    /// falls back to the source (decoding on each call, as before) and commits a
    /// result with its before/after original. This exercises the `?? source` fallback
    /// the decode-once render path relies on for the frames it cannot decode ahead.
    @Test
    @MainActor
    func aColourPlaneFrameRendersThroughTheByteFallback() async throws
    {
        let ( data, properties ) = FITSTestData.rgbPlanes( width: 4, height: 3 )
        let source               = FITSRenderSource( data: data, properties: properties )

        // The fallback precondition: this frame cannot decode ahead.
        #expect( try source.decoded() == nil )

        let renderer = ImageRenderer( source: source )

        await renderer.render()

        #expect( renderer.error == nil )
        #expect( renderer.result != nil )
        #expect( renderer.original != nil )
        #expect( renderer.originalImage != nil )
    }

    /// A monochrome 4×4 ramp FITS render source, whose ``ImageRenderSource/decoded()``
    /// is non-nil (a directly-decodable 2-D frame).
    private static func monoSource() -> FITSRenderSource
    {
        let properties =
            [
                FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
                FITSPropertySnapshot( name: "NAXIS",  value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS1", value: .integer( 4 ) ),
                FITSPropertySnapshot( name: "NAXIS2", value: .integer( 4 ) ),
            ]

        return FITSRenderSource( data: Data( ( 0 ..< 16 ).map { UInt8( $0 * 10 ) } ), properties: properties )
    }

    /// A thread-safe tally of how often a source is asked to decode ahead and to
    /// render through its byte path, for asserting the render pass's decode count.
    private final class DecodeCallCounter: @unchecked
    Sendable
    {
        private let lock            = NSLock()
        private var decodedCount    = 0
        private var byteRenderCount = 0

        func countDecoded()
        { self.lock.lock()
            self.decodedCount    += 1
            self.lock.unlock()
        }

        func countByteRender()
        { self.lock.lock()
            self.byteRenderCount += 1
            self.lock.unlock()
        }

        var decoded: Int
        { self.lock.lock()
            defer { self.lock.unlock() }
            return self.decodedCount
        }

        var byteRenders: Int
        { self.lock.lock()
            defer { self.lock.unlock() }
            return self.byteRenderCount
        }
    }

    /// A render source wrapping a real one, counting how often the renderer decodes
    /// ahead (``decoded()``) versus renders through the byte path (``makeResult(settings:)``).
    /// When `decodesAhead` is `false` it reports it cannot decode ahead, forcing the
    /// fallback — so the two paths' decode counts can be compared.
    private struct CountingRenderSource: ImageRenderSource
    {
        let wrapped:      FITSRenderSource
        let counter:      DecodeCallCounter
        let decodesAhead: Bool

        var detectionImage:         PixelBuffer?                        { self.wrapped.detectionImage }
        var fullScale:              Double?                             { self.wrapped.fullScale }
        var dimensions:             ( width: Int, height: Int )?        { self.wrapped.dimensions }
        var autoStretchColorSource: ImageProcessor.AutoStretchColorSource? { self.wrapped.autoStretchColorSource }

        func makeResult( settings: ImageProcessor.Settings ) throws -> ImageProcessor.RenderResult
        {
            self.counter.countByteRender()

            return try self.wrapped.makeResult( settings: settings )
        }

        func pixelValues( atX x: Int, y: Int ) -> [ ImageProcessor.PixelValue ]?
        {
            self.wrapped.pixelValues( atX: x, y: y )
        }

        func decoded() throws -> ( any DecodedRenderSource )?
        {
            self.counter.countDecoded()

            return self.decodesAhead ? try self.wrapped.decoded() : nil
        }
    }

    /// A decodable source is decoded once per pass, and both the displayed result and
    /// the before/after original are rendered from that one decode — never through the
    /// byte path. This is the decode-once payoff: one decode where there were two.
    @Test
    @MainActor
    func aDecodableSourceDecodesOncePerPassAndRendersBothFromIt() async throws
    {
        let counter  = DecodeCallCounter()
        let source   = CountingRenderSource( wrapped: Self.monoSource(), counter: counter, decodesAhead: true )
        let renderer = ImageRenderer( source: source )

        await renderer.render()

        #expect( renderer.error == nil )
        #expect( renderer.result != nil )
        #expect( renderer.originalImage != nil )
        #expect( counter.decoded == 1, "the frame must be decoded exactly once" )
        #expect( counter.byteRenders == 0, "neither the result nor the original may decode through the byte path" )
    }

    /// A source that cannot decode ahead renders the result and the original through
    /// the byte path — two decodes — exactly as before the decode-once change, with no
    /// behavioural difference beyond the decode count.
    @Test
    @MainActor
    func aSourceThatCannotDecodeAheadRendersBothThroughTheBytePath() async throws
    {
        let counter  = DecodeCallCounter()
        let source   = CountingRenderSource( wrapped: Self.monoSource(), counter: counter, decodesAhead: false )
        let renderer = ImageRenderer( source: source )

        await renderer.render()

        #expect( renderer.error == nil )
        #expect( renderer.result != nil )
        #expect( renderer.originalImage != nil )
        #expect( counter.decoded == 1, "decode-ahead is attempted once" )
        #expect( counter.byteRenders == 2, "the result and the original each render through the byte path" )
    }

    /// A source without a known full scale (no integer `BITPIX`) derives its auto
    /// Screen Transfer over the min/max domain: the settings carry a uniform STF and
    /// `.minMax` normalization, and the cheap `canAutoScreenTransfer` flag agrees.
    @Test
    @MainActor
    func autoScreenTransferDerivesOverMinMaxWithoutAFullScale() async throws
    {
        let detection = try PixelBuffer( width: 8, height: 8, channels: 1, pixels: ( 0 ..< 64 ).map { Double( $0 ) / 64.0 }, isNormalized: true )
        let source    = FITSRenderSource( data: Data(), properties: [], detectionImage: detection )
        let renderer  = ImageRenderer( source: source )

        #expect( renderer.canAutoScreenTransfer )
        #expect( source.fullScale == nil )

        let settings = try #require( await renderer.autoScreenTransferSettings() )

        #expect( settings.normalize == .minMax )

        if case .uniform = settings.stretch
        {
            // A single-channel detection image derives a uniform STF, as expected.
        }
        else
        {
            Issue.record( "expected a uniform STF from a single-channel detection image, got \( String( describing: settings.stretch ) )" )
        }
    }

    /// A source *with* a known full scale (an integer `BITPIX`) derives its auto
    /// Screen Transfer in the full-scale `[0, 1]` domain over `.identity` — the same
    /// derivation the auto-stretch-on-open path uses — so clicking Auto reproduces
    /// how the image opened rather than the brighter min/max-domain result.
    @Test
    @MainActor
    func autoScreenTransferUsesTheFullScaleDomainWhenAvailable() async throws
    {
        let detection  = try PixelBuffer( width: 8, height: 8, channels: 1, pixels: ( 0 ..< 64 ).map { Double( $0 ) * 4 }, isNormalized: false )
        let properties = [ FITSPropertySnapshot( name: "BITPIX", value: .integer( 16 ) ) ]
        let source     = FITSRenderSource( data: Data(), properties: properties, detectionImage: detection )
        let renderer   = ImageRenderer( source: source )
        let fullScale  = try #require( source.fullScale )

        let settings = try #require( await renderer.autoScreenTransferSettings() )
        let onOpen   = try #require( ImageProcessor.autoStretchSettings( detectionImage: detection, fullScale: fullScale ) )

        // Identical domain and parameters to the on-open path.
        #expect( settings.normalize == .identity )
        #expect( settings.stretch == onOpen.stretch )
    }

    /// Without a usable source (an extraction failure), no auto Screen Transfer can
    /// be derived: both the cheap flag and the derivation report unavailable.
    @Test
    @MainActor
    func autoScreenTransferIsUnavailableWithoutASource() async throws
    {
        let renderer = ImageRenderer( source: .failure( NSError( domain: "test", code: 1 ) ) )

        #expect( renderer.canAutoScreenTransfer == false )

        let settings = await renderer.autoScreenTransferSettings()

        #expect( settings == nil )
    }

    /// By default a source's colour input is its single-channel detection image, so
    /// the shared derivation keeps deriving a uniform STF until a colour source
    /// overrides it. The full-scale source method then matches the on-open path.
    @Test
    func sourceAutoStretchColorSourceDefaultsToMonoAndMatchesTheOnOpenPath() throws
    {
        let detection  = try PixelBuffer( width: 8, height: 8, channels: 1, pixels: ( 0 ..< 64 ).map { Double( $0 ) * 4 }, isNormalized: false )
        let properties = [ FITSPropertySnapshot( name: "BITPIX", value: .integer( 16 ) ) ]
        let source     = FITSRenderSource( data: Data(), properties: properties, detectionImage: detection )
        let fullScale  = try #require( source.fullScale )

        guard case .mono( let buffer ) = try #require( source.autoStretchColorSource )
        else
        {
            Issue.record( "a source's default colour input must be the mono detection image" )

            return
        }

        #expect( buffer.pixels == detection.pixels )

        let fromSource = try #require( source.autoStretchSettings() )
        let onOpen     = try #require( ImageProcessor.autoStretchSettings( detectionImage: detection, fullScale: fullScale ) )

        #expect( fromSource == onOpen )
    }

    /// A source without a fixed full scale (a floating-point one) still derives an auto
    /// Screen Transfer — over the min/max domain rather than full-scale — so a float
    /// image is not left unstretched. A mono source's is uniform.
    @Test
    func sourceAutoStretchSettingsAreMinMaxWithoutAFullScale() throws
    {
        let detection = try PixelBuffer( width: 8, height: 8, channels: 1, pixels: ( 0 ..< 64 ).map { Double( $0 ) / 64.0 }, isNormalized: true )
        let source    = FITSRenderSource( data: Data(), properties: [], detectionImage: detection )

        #expect( source.fullScale == nil )

        let settings = try #require( source.autoStretchSettings() )

        #expect( settings.normalize == .minMax )

        guard case .uniform = try #require( settings.stretch )
        else
        {
            Issue.record( "a mono source's auto Screen Transfer must be uniform" )

            return
        }
    }

    /// The inspector's Auto (the default `.automatic` linking) derives a per-channel
    /// STF for a colour source, reproducing exactly what opening the image did — so
    /// open and click-Auto agree.
    @Test
    @MainActor
    func autoScreenTransferIsPerChannelForAColourSourceMatchingOnOpen() async throws
    {
        let ( data, properties ) = FITSTestData.rgbPlanes( width: 4, height: 3 )
        let detection            = try PixelBuffer( width: 4, height: 3, channels: 1, pixels: ( 0 ..< 12 ).map { Double( $0 ) * 10 }, isNormalized: false )
        let source               = FITSRenderSource( data: data, properties: properties, detectionImage: detection )
        let renderer             = ImageRenderer( source: source )

        let settings = try #require( await renderer.autoScreenTransferSettings() )

        guard case .perChannel = try #require( settings.stretch )
        else
        {
            Issue.record( "a colour source's Auto must derive a per-channel Screen Transfer" )

            return
        }

        let onOpen = try #require( source.autoStretchSettings() )

        #expect( settings.stretch   == onOpen.stretch )
        #expect( settings.normalize == onOpen.normalize )
    }

    /// The editor's uniform mode (`.uniform` linking) derives a single uniform STF
    /// even for a colour source — the colour-preserving "uniform Auto" a power user
    /// can ask for.
    @Test
    @MainActor
    func autoScreenTransferUniformLinkingIsUniformEvenForAColourSource() async throws
    {
        let ( data, properties ) = FITSTestData.rgbPlanes( width: 4, height: 3 )
        let detection            = try PixelBuffer( width: 4, height: 3, channels: 1, pixels: ( 0 ..< 12 ).map { Double( $0 ) * 10 }, isNormalized: false )
        let source               = FITSRenderSource( data: data, properties: properties, detectionImage: detection )
        let renderer             = ImageRenderer( source: source )

        let settings = try #require( await renderer.autoScreenTransferSettings( linking: .uniform ) )

        // Derived in the full-scale [0, 1] domain (over identity), like the on-open
        // and inspector paths — not the brighter min/max domain.
        #expect( settings.normalize == .identity )

        guard case .uniform = try #require( settings.stretch )
        else
        {
            Issue.record( "uniform linking must derive a uniform Screen Transfer even for a colour source" )

            return
        }

        // And it genuinely differs from the per-channel (automatic) derivation of the
        // same colour source.
        let automatic = try #require( await renderer.autoScreenTransferSettings( linking: .automatic ) )

        #expect( settings.stretch != automatic.stretch )
    }

    /// A mono source stays uniform in both linking modes — there is no per-channel
    /// result to produce, and the two modes agree.
    @Test
    @MainActor
    func autoScreenTransferIsUniformForAMonoSourceInBothModes() async throws
    {
        let detection  = try PixelBuffer( width: 8, height: 8, channels: 1, pixels: ( 0 ..< 64 ).map { Double( $0 ) * 4 }, isNormalized: false )
        let properties = [ FITSPropertySnapshot( name: "BITPIX", value: .integer( 16 ) ) ]
        let source     = FITSRenderSource( data: Data(), properties: properties, detectionImage: detection )
        let renderer   = ImageRenderer( source: source )

        let automatic = try #require( await renderer.autoScreenTransferSettings( linking: .automatic ) )
        let uniform   = try #require( await renderer.autoScreenTransferSettings( linking: .uniform ) )

        guard case .uniform = try #require( automatic.stretch ), case .uniform = try #require( uniform.stretch )
        else
        {
            Issue.record( "a mono source must derive a uniform Screen Transfer in both modes" )

            return
        }

        #expect( automatic.stretch == uniform.stretch )
    }

    /// A valid `BITPIX = 64` image is a format the pixel pipeline does not
    /// support; it must surface a clear, typed error naming the limitation.
    @Test
    @MainActor
    func unsupportedBitpixProducesClearError() async throws
    {
        let file     = try FITSFile( data: FITSTestData.bitpix64(), options: .lenient )
        let renderer = ImageRenderer( file: file )

        await renderer.render()

        #expect( renderer.result == nil, "an unsupported BITPIX should not render" )

        let message = renderer.error.map { "\( $0 )" } ?? ""

        #expect( message.contains( "BITPIX 64 is not supported" ), "expected a clear unsupported-BITPIX error, got: \"\( message )\"" )
    }

    /// The render boundary accepts only Sendable values: a render source built
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

            return try FITSRenderSource( sections: file.sections )
        }
        .value

        let renderer = ImageRenderer( source: input )

        await renderer.render()

        let result = try #require( renderer.result )
        let direct = try ImageProcessor.render( data: input.data, properties: input.properties )

        // The histogram is the observable product of the rendered bytes: equal
        // histograms confirm the off-actor input rendered identically.
        #expect( result.histogram.rgb       == SwiftPixel.Histogram( bytes: direct.bytes, channels: 3, mode: .rgb ) )
        #expect( result.histogram.luma == SwiftPixel.Histogram( bytes: direct.bytes, channels: 3, mode: .luma ) )
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

            return try FITSRenderSource( sections: file.sections )
        }
        .value

        let renderer = ImageRenderer( source: input )

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
        let input    = try FITSRenderSource( sections: file.sections )
        let renderer = ImageRenderer( source: input )

        await renderer.render()

        let original = try #require( renderer.result?.histogram.rgb )

        renderer.adjustments.stretch = .uniform( .init( midtones: 0.3 ) )
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
        let input    = try FITSRenderSource( sections: file.sections )
        let renderer = ImageRenderer( source: input )

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
        let input    = try FITSRenderSource( sections: file.sections )
        let renderer = ImageRenderer( source: input )

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
        let input    = try FITSRenderSource( sections: file.sections )
        let renderer = ImageRenderer( source: input )

        await renderer.render()

        let good = try #require( renderer.result )

        #expect( renderer.error == nil )

        // An empty clip window (highlights ≤ shadows) is a mathematically invalid
        // parameter the pipeline rejects by throwing.
        renderer.adjustments.stretch = .uniform( .init( shadows: 1, highlights: 0 ) )

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
        let input    = try FITSRenderSource( sections: file.sections )
        let renderer = ImageRenderer( source: input )

        renderer.adjustments.stretch = .uniform( .init( shadows: 1, highlights: 0 ) )

        await renderer.render()

        #expect( renderer.error != nil )

        renderer.adjustments.stretch = .uniform( .init( midtones: 0.3 ) )

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
        let renderer = ImageRenderer( source: FITSRenderSource( data: Data(), properties: [] ) )

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
        let input    = try FITSRenderSource( sections: file.sections )
        let renderer = ImageRenderer( source: input )

        await renderer.render()

        let older = try #require( renderer.result )

        renderer.adjustments.stretch = .uniform( .init( midtones: 0.3 ) )

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
        let input    = try FITSRenderSource( sections: file.sections )
        let renderer = ImageRenderer( source: input )

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
        let renderer             = ImageRenderer( source: FITSRenderSource( data: data, properties: properties ) )

        await renderer.render()

        let result = try #require( renderer.result )
        let direct = try ImageProcessor.render( data: data, properties: properties )

        #expect( result.histogram.rgb.data.count == direct.outputPixelFormat.channels, "the histogram must use the rendered buffer's channel count" )
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
        let renderer             = ImageRenderer( source: FITSRenderSource( data: data, properties: properties ) )

        await renderer.render()

        let result = try #require( renderer.result )
        let direct = try ImageProcessor.render( data: data, properties: properties )

        #expect( direct.inputPixelFormat == .mono, "an image with no Bayer pattern must render as monochrome" )
        #expect( result.histogram.isMono, "a non-debayered render must be flagged mono" )
        #expect( result.histogram.mono == SwiftPixel.Histogram( bytes: direct.bytes, channels: direct.outputPixelFormat.channels, mode: .mono ) )
        #expect( result.histogram.mono.data.count == 1 )
        #expect( result.statistics.mono.count == result.statistics.luma.count )
    }

    /// A debayered (colour-filter-array) image is not monochrome, so the inspector
    /// keeps the RGB/luma presentation rather than the single mono histogram.
    @Test
    @MainActor
    func debayeredImageIsNotFlaggedMono() async throws
    {
        let ( data, baseProperties ) = FITSTestData.gradient()

        // A Bayer pattern makes the default `.auto` debayer demosaic to true RGB.
        let properties = baseProperties + [ FITSPropertySnapshot( name: "BAYERPAT", value: .string( "RGGB" ) ) ]

        let renderer = ImageRenderer( source: FITSRenderSource( data: data, properties: properties ) )

        await renderer.render()

        let result = try #require( renderer.result )
        let direct = try ImageProcessor.render( data: data, properties: properties )

        #expect( direct.inputPixelFormat == .cfa, "an image with a Bayer pattern must render as colour" )
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
        let input    = try FITSRenderSource( sections: file.sections )
        let renderer = ImageRenderer( source: input )

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
        let input    = try FITSRenderSource( sections: file.sections )
        let renderer = ImageRenderer( source: input )

        await renderer.render()

        let histogram = try #require( renderer.result?.histogram )
        let sameData  = ImageRenderer.Histogram( rgb: histogram.rgb, luma: histogram.luma, mono: histogram.mono, isMono: histogram.isMono )

        #expect( histogram == histogram, "the same histogram instance is equal to itself" )
        #expect( histogram != sameData,  "a distinct histogram with identical bins is not equal — compared by identity, so SwiftUI never deep-compares the bins" )
    }

    /// A freshly created renderer is not rendering until one is started.
    @Test
    @MainActor
    func isRenderingStartsFalse() throws
    {
        let renderer = ImageRenderer( source: FITSRenderSource( data: Data(), properties: [] ) )

        #expect( renderer.isRendering == false )
    }

    /// A completed render leaves the in-flight flag clear, whichever way it
    /// finished, so the processing affordances return to the ready state.
    @Test
    @MainActor
    func renderClearsIsRenderingWhenComplete() async throws
    {
        let file     = try FITSFile( data: Data( contentsOf: TestFixtures.monoImage ), options: .lenient )
        let input    = try FITSRenderSource( sections: file.sections )
        let renderer = ImageRenderer( source: input )

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
        let input    = try FITSRenderSource( sections: file.sections )
        let renderer = ImageRenderer( source: input )

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
        let input    = try FITSRenderSource( sections: file.sections )
        let renderer = ImageRenderer( source: input )

        await renderer.render()

        let good       = try #require( renderer.result )
        let generation = renderer.nextRenderGeneration()

        renderer.commit( .success( good ), generation: generation - 1 )

        #expect( renderer.isRendering, "a stale commit must not clear the flag while a newer render is in flight" )
    }

    /// The before/after comparison "before" image is produced eagerly, as part of
    /// the normal render, so it is ready the moment the image displays and
    /// registers pixel-for-pixel with the processed result.
    @Test
    @MainActor
    func comparisonImageIsReadyAfterRender() async throws
    {
        let file     = try FITSFile( data: Data( contentsOf: TestFixtures.monoImage ), options: .lenient )
        let input    = try FITSRenderSource( sections: file.sections )
        let renderer = ImageRenderer( source: input )

        await renderer.render()

        let before = try #require( renderer.originalImage, "the before image is rendered as part of the normal render" )
        let result = try #require( renderer.result )

        #expect( before.width  == result.image.width,  "the before image registers with the processed result" )
        #expect( before.height == result.image.height )
    }

    /// The captured "before" image is reused across re-renders at the same
    /// orientation: a re-render triggered by another adjustment does not
    /// needlessly re-render the original.
    @Test
    @MainActor
    func theComparisonImageIsReusedAcrossReRenders() async throws
    {
        let file     = try FITSFile( data: Data( contentsOf: TestFixtures.monoImage ), options: .lenient )
        let input    = try FITSRenderSource( sections: file.sections )
        let renderer = ImageRenderer( source: input )

        await renderer.render()

        let first = try #require( renderer.originalImage, "the before image is rendered as part of the render" )

        renderer.adjustments.brightness = 0.2

        await renderer.render()

        #expect( renderer.originalImage === first, "an unchanged orientation reuses the captured before image" )
    }

    /// The "before" image follows the current orientation so it stays registered
    /// pixel-for-pixel with the processed result: a 90° rotation re-renders it as
    /// part of the render and swaps its dimensions.
    @Test
    @MainActor
    func theComparisonImageReRendersWhenOrientationChanges() async throws
    {
        // A non-square image so a 90° rotation is observable as swapped dimensions.
        let ( data, properties ) = FITSTestData.gradient( width: 16, height: 8 )
        let renderer             = ImageRenderer( source: FITSRenderSource( data: data, properties: properties ) )

        await renderer.render()

        let identity = try #require( renderer.originalImage )

        #expect( identity.width  == 16 )
        #expect( identity.height == 8 )

        renderer.adjustments.orientation = .init( rotation: .clockwise90, mirroredHorizontally: false )

        await renderer.render()

        let rotated = try #require( renderer.originalImage )

        #expect( rotated !== identity,  "a changed orientation re-renders the before image" )
        #expect( rotated.width  == 8,   "a 90° rotation swaps the dimensions" )
        #expect( rotated.height == 16 )
    }

    private struct StaleError: Swift.Error {}
}
