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

/// Tests that HEIC files open through the shared ImageIO path: a single-image HEIC
/// loads as one frame with its metadata, and a multi-image HEIC surfaces its contained
/// images as separate carousel frames. HEIC is lossily compressed, so these assert the
/// structure and geometry rather than exact sample values (the lossless decode maths is
/// covered by the PNG/TIFF fixtures).
@Suite( "ImageIO HEIC" )
struct ImageIOHEICTests
{
    /// The factory routes a HEIC file to the shared ImageIO loader.
    @Test
    @MainActor
    func factoryRoutesHEICToImageIOLoader()
    {
        #expect( ImageLoader.loader( for: TestFixtures.photoHEIC ) is ImageIOImageLoader )
    }

    /// The factory also routes the `.heif` container extension to the ImageIO loader —
    /// `public.heic` and `public.heif` do not cross-conform, so both are registered. The
    /// factory keys on the extension, so this needs no file on disk.
    @Test
    @MainActor
    func factoryRoutesHEIFExtensionToImageIOLoader()
    {
        #expect( ImageLoader.loader( for: URL( fileURLWithPath: "/tmp/example.heif" ) ) is ImageIOImageLoader )
    }

    /// A single-image HEIC loads as one colour frame at its stored geometry, with the
    /// EXIF capture date extracted.
    @Test
    @MainActor
    func loadsSingleImageHEIC() async throws
    {
        let loader = ImageIOImageLoader( url: TestFixtures.photoHEIC )

        await loader.load()

        let image = try #require( loader.image )

        #expect( loader.error == nil )
        #expect( loader.frames.count == 1 )
        #expect( image.isColor )
        #expect( image.observationDate != nil )

        let source = try image.renderer.renderSourceSnapshot()
        let result = try source.makeResult( settings: image.renderer.adjustments.baseline )

        #expect( result.inputPixelFormat == .rgb )
        #expect( result.image.width == 8 )
        #expect( result.image.height == 8 )
    }

    /// A multi-image HEIC surfaces its contained images as separate frames, each
    /// rendering to its own geometry — the carousel path.
    @Test
    @MainActor
    func loadsMultiImageHEICAsFrames() async throws
    {
        let loader = ImageIOImageLoader( url: TestFixtures.multiImageHEIC )

        await loader.load()

        #expect( loader.error == nil )
        #expect( loader.frames.count == 3 )

        try loader.frames.forEach
        {
            frame in

            let result = try frame.renderer.renderSourceSnapshot().makeResult( settings: frame.renderer.adjustments.baseline )

            #expect( result.image.width == 6 )
            #expect( result.image.height == 4 )
        }
    }
}
