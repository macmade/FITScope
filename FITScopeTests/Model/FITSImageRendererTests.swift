/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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

import Foundation
import SwiftFITS
import SwiftPixel
import Testing
@testable import FITScope

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

        // The file that used to trap: a single header section, no data section.
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
        let url = FITSCorpus.url( "NASA/FOSy19g0309t_c2f.fits" )

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

    /// Changing an adjustment and triggering the debounced re-render entry point
    /// produces a render distinct from the default one.
    @Test
    @MainActor
    func reRenderWithChangedAdjustmentsProducesNewResult() async throws
    {
        let file     = try FITSFile( data: Data( contentsOf: FITSCorpus.url( "NASA/FOSy19g0309t_c2f.fits" ) ), options: .lenient )
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

    /// A render failure must not strand the user: the thrown error surfaces but
    /// the last good render is retained, so the image and its controls survive.
    @Test
    @MainActor
    func failedRenderRetainsLastGoodResult() async throws
    {
        let file     = try FITSFile( data: Data( contentsOf: FITSCorpus.url( "NASA/FOSy19g0309t_c2f.fits" ) ), options: .lenient )
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
        let file     = try FITSFile( data: Data( contentsOf: FITSCorpus.url( "NASA/FOSy19g0309t_c2f.fits" ) ), options: .lenient )
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
}
