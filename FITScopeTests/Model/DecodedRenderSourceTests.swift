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
import SwiftPixel
import Testing

/// Tests for the ``DecodedRenderSource`` / ``RenderResultProducing`` seam — the
/// default `decoded()` behaviour and the shared render-producing conformance.
/// The per-format decode-once conformers are covered by their own suites.
@Suite( "DecodedRenderSource" )
struct DecodedRenderSourceTests
{
    /// A test error thrown by the stub's unused `makeResult`.
    private struct StubError: Error {}

    /// A minimal ``ImageRenderSource`` that does not override ``decoded()``, so it
    /// exercises the default (no decode-ahead) behaviour. Its `makeResult` is never
    /// called by these tests.
    private struct StubRenderSource: ImageRenderSource
    {
        let detectionImage: PixelBuffer?

        var fullScale: Double? { nil }

        var dimensions: ( width: Int, height: Int )? { nil }

        func makeResult( settings: ImageProcessor.Settings ) throws -> ImageProcessor.RenderResult
        {
            throw StubError()
        }

        func pixelValues( atX x: Int, y: Int ) -> [ ImageProcessor.PixelValue ]?
        {
            nil
        }
    }

    /// A source that does not override `decoded()` cannot decode ahead: the default
    /// returns `nil`, so the renderer falls back to rendering through the source.
    @Test
    func aSourceThatDoesNotDecodeAheadReturnsNilByDefault() throws
    {
        let source  = StubRenderSource( detectionImage: nil )
        let decoded = try source.decoded()

        #expect( decoded == nil )
    }

    /// Every ``ImageRenderSource`` is a ``RenderResultProducing``, so the renderer
    /// can drive a source and a pre-decoded frame through the one code path.
    @Test
    func aSourceIsARenderResultProducer()
    {
        let producer: any RenderResultProducing = StubRenderSource( detectionImage: nil )

        #expect( producer is any ImageRenderSource )
    }
}
