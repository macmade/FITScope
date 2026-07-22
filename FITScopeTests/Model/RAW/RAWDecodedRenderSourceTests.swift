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

/// Tests for ``RAWDecodedRenderSource`` and ``RAWRenderSource/decoded()``: the
/// decode-once render is byte-identical to the byte path for a CFA and a mono
/// sensor, and the decoded auto-stretch colour source is correct.
@Suite( "RAWDecodedRenderSource" )
struct RAWDecodedRenderSourceTests
{
    /// Packs 16-bit mosaic samples into host-order bytes, as the loader's crop does.
    private static func data( _ samples: [ UInt16 ] ) -> Data
    {
        samples.withUnsafeBytes { Data( $0 ) }
    }

    /// Rendering through the decode-once frame produces byte-identical output to the
    /// byte path, for both a CFA and a monochrome sensor and several settings.
    @Test
    func decodeOnceRendersIdenticallyToTheBytePath() throws
    {
        for pattern in [ "RGGB", nil ]
        {
            let samples    = ( 0 ..< 16 ).map { UInt16( $0 * 1000 ) }
            let properties = RAWImageProperties( width: 4, height: 4, colorFilterArrayPattern: pattern, whiteLevel: 65535 )
            let source     = RAWRenderSource( data: Self.data( samples ), properties: properties )
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
    }

    /// A CFA sensor's decoded auto-stretch colour source is its raw mosaic and pattern.
    @Test
    func autoStretchColorSourceIsMosaicForACFASensor() throws
    {
        let samples    = ( 0 ..< 16 ).map { UInt16( $0 * 1000 ) }
        let properties = RAWImageProperties( width: 4, height: 4, colorFilterArrayPattern: "RGGB", whiteLevel: 65535 )
        let decoded    = try #require( try RAWRenderSource( data: Self.data( samples ), properties: properties ).decoded() )
        let colour     = try #require( decoded.autoStretchColorSource( maxDimension: nil ) )

        guard case .mosaic( _, let pattern ) = colour
        else
        {
            Issue.record( "expected a mosaic colour source for a CFA sensor, got \( colour )" )

            return
        }

        #expect( pattern == .rggb )
    }

    /// A monochrome sensor's decoded auto-stretch colour source is the mono mosaic
    /// luminance (matching the byte-based source's detection-image fallback).
    @Test
    func autoStretchColorSourceIsMonoForAMonoSensor() throws
    {
        let samples    = ( 0 ..< 16 ).map { UInt16( $0 * 1000 ) }
        let properties = RAWImageProperties( width: 4, height: 4, colorFilterArrayPattern: nil, whiteLevel: 65535 )
        let decoded    = try #require( try RAWRenderSource( data: Self.data( samples ), properties: properties ).decoded() )
        let colour     = try #require( decoded.autoStretchColorSource( maxDimension: nil ) )

        guard case .mono = colour
        else
        {
            Issue.record( "expected a mono colour source for a mono sensor, got \( colour )" )

            return
        }
    }
}
