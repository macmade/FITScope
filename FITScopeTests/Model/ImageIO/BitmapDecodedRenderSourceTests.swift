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
import Testing

/// Tests for ``BitmapDecodedRenderSource`` and ``BitmapRenderSource/decoded()``:
/// the decode-once render is byte-identical to the byte path for mono and RGB
/// images, and the decoded auto-stretch colour source is the mono luminance.
@Suite( "BitmapDecodedRenderSource" )
struct BitmapDecodedRenderSourceTests
{
    /// A grayscale image renders identically through the decode-once frame and the
    /// byte path, for several settings.
    @Test
    func monoDecodeOnceRendersIdenticallyToTheBytePath() throws
    {
        let data       = Data( [ 100, 125, 150 ] )
        let properties = BitmapImageProperties( width: 3, height: 1, channelCount: 1, componentsPerPixel: 1, bytesPerComponent: 1 )
        let source     = BitmapRenderSource( data: data, properties: properties )
        let decoded    = try #require( try source.decoded() )

        for settings in [ ImageProcessor.Settings(), ImageProcessor.Settings( normalize: .identity ) ]
        {
            let viaBytes   = try source.makeResult( settings: settings )
            let viaDecoded = try decoded.makeResult( settings: settings )

            #expect( viaDecoded.bytes == viaBytes.bytes )
            #expect( viaDecoded.inputPixelFormat == viaBytes.inputPixelFormat )
            #expect( viaDecoded.outputPixelFormat == viaBytes.outputPixelFormat )
        }
    }

    /// An RGB image (stored `RGBX`) renders identically through the decode-once frame
    /// and the byte path.
    @Test
    func rgbDecodeOnceRendersIdenticallyToTheBytePath() throws
    {
        let data       = Data( [ 200, 10, 20, 255, 20, 200, 10, 255 ] )
        let properties = BitmapImageProperties( width: 2, height: 1, channelCount: 3, componentsPerPixel: 4, bytesPerComponent: 1 )
        let source     = BitmapRenderSource( data: data, properties: properties )
        let decoded    = try #require( try source.decoded() )

        for settings in [ ImageProcessor.Settings(), ImageProcessor.Settings( normalize: .identity ) ]
        {
            let viaBytes   = try source.makeResult( settings: settings )
            let viaDecoded = try decoded.makeResult( settings: settings )

            #expect( viaDecoded.bytes == viaBytes.bytes )
            #expect( viaDecoded.inputPixelFormat == viaBytes.inputPixelFormat )
            #expect( viaDecoded.outputPixelFormat == viaBytes.outputPixelFormat )
        }
    }

    /// The decoded auto-stretch colour source is the single-channel luminance.
    @Test
    func autoStretchColorSourceIsMonoLuminance() throws
    {
        let data       = Data( [ 200, 10, 20, 255, 20, 200, 10, 255 ] )
        let properties = BitmapImageProperties( width: 2, height: 1, channelCount: 3, componentsPerPixel: 4, bytesPerComponent: 1 )
        let decoded    = try #require( try BitmapRenderSource( data: data, properties: properties ).decoded() )
        let colour     = try #require( decoded.autoStretchColorSource( maxDimension: nil ) )

        guard case .mono = colour
        else
        {
            Issue.record( "expected a mono luminance colour source, got \( colour )" )

            return
        }
    }
}
