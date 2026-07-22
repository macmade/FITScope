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

/// Tests for ``XISFDecodedRenderSource`` and ``XISFRenderSource/decoded()``: the
/// decode-once render is byte-identical to the byte path for mono and RGB frames,
/// and the decoded auto-stretch colour source is correct (mono luminance / RGB
/// channels).
@Suite( "XISFDecodedRenderSource" )
struct XISFDecodedRenderSourceTests
{
    /// A grayscale image renders identically through the decode-once frame and the
    /// byte path, for several settings.
    @Test
    func monoDecodeOnceRendersIdenticallyToTheBytePath() throws
    {
        let properties = XISFImageProperties( width: 2, height: 2, channelCount: 1, sampleFormat: .uInt16, byteOrder: .little, pixelStorage: .planar, colorSpace: .gray, colorFilterArrayPattern: nil )
        let data       = Data( XISFTestData.uInt16LE( [ 10, 20, 30, 40 ] ) )
        let source     = XISFRenderSource( data: data, properties: properties )
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

    /// A three-channel RGB image renders identically through the decode-once frame
    /// and the byte path.
    @Test
    func rgbDecodeOnceRendersIdenticallyToTheBytePath() throws
    {
        let properties = XISFImageProperties( width: 2, height: 2, channelCount: 3, sampleFormat: .uInt16, byteOrder: .little, pixelStorage: .planar, colorSpace: .rgb, colorFilterArrayPattern: nil )
        let data       = Data( XISFTestData.uInt16LE( [ 1, 2, 3, 4 ] + [ 10, 20, 30, 40 ] + [ 100, 200, 300, 400 ] ) )
        let source     = XISFRenderSource( data: data, properties: properties )
        let decoded    = try #require( try source.decoded() )

        let viaBytes   = try source.makeResult( settings: ImageProcessor.Settings() )
        let viaDecoded = try decoded.makeResult( settings: ImageProcessor.Settings() )

        #expect( viaDecoded.bytes == viaBytes.bytes )
        #expect( viaDecoded.inputPixelFormat == viaBytes.inputPixelFormat )
        #expect( viaDecoded.outputPixelFormat == viaBytes.outputPixelFormat )
    }

    /// A grayscale frame's decoded auto-stretch colour source is the mono luminance.
    @Test
    func monoAutoStretchColorSourceIsLuminance() throws
    {
        let properties = XISFImageProperties( width: 2, height: 2, channelCount: 1, sampleFormat: .uInt16, byteOrder: .little, pixelStorage: .planar, colorSpace: .gray, colorFilterArrayPattern: nil )
        let data       = Data( XISFTestData.uInt16LE( [ 10, 20, 30, 40 ] ) )
        let decoded    = try #require( try XISFRenderSource( data: data, properties: properties ).decoded() )
        let colour     = try #require( decoded.autoStretchColorSource( maxDimension: nil ) )

        guard case .mono = colour
        else
        {
            Issue.record( "expected a mono colour source for a grayscale frame, got \( colour )" )

            return
        }
    }

    /// An RGB frame's decoded auto-stretch colour source is its per-channel input.
    @Test
    func rgbAutoStretchColorSourceIsChannels() throws
    {
        let properties = XISFImageProperties( width: 2, height: 2, channelCount: 3, sampleFormat: .uInt16, byteOrder: .little, pixelStorage: .planar, colorSpace: .rgb, colorFilterArrayPattern: nil )
        let data       = Data( XISFTestData.uInt16LE( [ 1, 2, 3, 4 ] + [ 10, 20, 30, 40 ] + [ 100, 200, 300, 400 ] ) )
        let decoded    = try #require( try XISFRenderSource( data: data, properties: properties ).decoded() )
        let colour     = try #require( decoded.autoStretchColorSource( maxDimension: nil ) )

        guard case .channels = colour
        else
        {
            Issue.record( "expected a channels colour source for an RGB frame, got \( colour )" )

            return
        }
    }
}
