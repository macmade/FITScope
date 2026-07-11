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

/// Tests for `FITSImageLoader`'s load lifecycle: a successful load is not
/// repeated, while a failed load remains retriable.
@Suite( "FITSImageLoader" )
struct FITSImageLoaderTests
{
    /// A second `load()` after a successful one is a no-op: the parsed image is
    /// retained rather than rebuilt, so a re-triggered `.task` cannot discard
    /// and reparse the file.
    @Test
    @MainActor
    func loadIsIdempotentOnSuccess() async throws
    {
        let url    = TestFixtures.monoImage
        let data   = try Data( contentsOf: url )
        let loader = FITSImageLoader( url: url, data: data )

        await loader.load()

        let first = try #require( loader.image )

        await loader.load()

        let second = try #require( loader.image )

        #expect( first === second, "a successful load must not be repeated" )
    }

    /// The loader produces a usable `LoadedImage` — parsed header info plus a
    /// renderer that renders — built entirely from Sendable values, without the
    /// image retaining the non-Sendable `FITSFile`.
    @Test
    @MainActor
    func loadProducesRenderableImageWithValidInfo() async throws
    {
        let url    = TestFixtures.monoImage
        let data   = try Data( contentsOf: url )
        let loader = FITSImageLoader( url: url, data: data )

        await loader.load()

        let image = try #require( loader.image )

        #expect( image.metadata.sections.isEmpty == false, "the loaded image must carry parsed header info" )

        await image.renderer.render()

        #expect( image.renderer.result != nil, "the loaded image's renderer must render" )
    }

    /// A loader created from a URL alone reads the file's bytes itself and
    /// produces a renderable image, without a pre-read document.
    @Test
    @MainActor
    func loadFromURLProducesRenderableImage() async throws
    {
        let url    = TestFixtures.monoImage
        let loader = FITSImageLoader( url: url )

        await loader.load()

        let image = try #require( loader.image )

        #expect( image.metadata.sections.isEmpty == false, "the loaded image must carry parsed header info" )
    }

    /// With auto-stretch on, an integer-format image opens with an auto Screen
    /// Transfer seeded over identity normalization — the full-scale domain — and
    /// reports no adjustments over its own baseline.
    @Test
    @MainActor
    func opensWithAutoStretchWhenEnabled() async throws
    {
        let loader = FITSImageLoader( url: TestFixtures.colorImage, autoStretch: true )

        await loader.load()

        let image       = try #require( loader.image )
        let adjustments = image.renderer.adjustments

        #expect( adjustments.baseline.stretch   != nil )
        #expect( adjustments.baseline.normalize == .identity )
        #expect( adjustments.hasAdjustments == false )
        #expect( adjustments.isModified( \.stretch ) == false )
    }

    /// With auto-stretch off, the image opens linear on the default min/max
    /// baseline, with no stretch.
    @Test
    @MainActor
    func opensLinearWhenAutoStretchDisabled() async throws
    {
        let loader = FITSImageLoader( url: TestFixtures.colorImage )

        await loader.load()

        let image = try #require( loader.image )

        #expect( image.renderer.adjustments.baseline.stretch   == nil )
        #expect( image.renderer.adjustments.baseline.normalize == .minMax )
    }

    /// A floating-point image has no fixed full scale, so auto-stretch is skipped
    /// even when enabled: the image opens linear on the min/max baseline.
    @Test
    @MainActor
    func floatingPointImageOpensLinearEvenWithAutoStretch() async throws
    {
        let loader = FITSImageLoader( url: TestFixtures.monoImage, autoStretch: true )

        await loader.load()

        let image = try #require( loader.image )

        #expect( image.renderer.adjustments.baseline.stretch   == nil )
        #expect( image.renderer.adjustments.baseline.normalize == .minMax )
    }

    /// A failed load leaves no image, so the idempotency guard never
    /// short-circuits a failed loader: a subsequent `load()` retries rather than
    /// being blocked by the failure state.
    @Test
    @MainActor
    func failedLoadDoesNotBlockReload() async throws
    {
        let loader = FITSImageLoader( url: URL( fileURLWithPath: "/dev/null" ), data: Data( "not a FITS file".utf8 ) )

        await loader.load()

        #expect( loader.image == nil, "invalid data should not produce an image" )
        #expect( loader.error != nil, "invalid data should surface an error" )

        await loader.load()

        #expect( loader.image == nil, "the failure state must remain retriable, not latched" )
        #expect( loader.error != nil )
    }
}
