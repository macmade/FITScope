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
import Testing
@testable import FITScope

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
        let url    = FITSCorpus.url( "NASA/FOSy19g0309t_c2f.fits" )
        let data   = try Data( contentsOf: url )
        let loader = FITSImageLoader( url: url, document: FITSDocument( data: data ) )

        await loader.load()

        let first = try #require( loader.image )

        await loader.load()

        let second = try #require( loader.image )

        #expect( first === second, "a successful load must not be repeated" )
    }

    /// A failed load leaves no image, so the idempotency guard never
    /// short-circuits a failed loader: a subsequent `load()` retries rather than
    /// being blocked by the failure state.
    @Test
    @MainActor
    func failedLoadDoesNotBlockReload() async throws
    {
        let loader = FITSImageLoader( url: URL( fileURLWithPath: "/dev/null" ), document: FITSDocument( data: Data( "not a FITS file".utf8 ) ) )

        await loader.load()

        #expect( loader.image == nil, "invalid data should not produce an image" )
        #expect( loader.error != nil, "invalid data should surface an error" )

        await loader.load()

        #expect( loader.image == nil, "the failure state must remain retriable, not latched" )
        #expect( loader.error != nil )
    }
}
