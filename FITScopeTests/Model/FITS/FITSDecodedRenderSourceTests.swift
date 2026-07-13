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
import Testing

/// Tests for ``FITSDecodedRenderSource`` and ``FITSRenderSource/decoded()``: the
/// decode-once render is byte-identical to the byte path, a colour-plane frame
/// keeps the byte path, and the decoded auto-stretch colour source is correct.
@Suite( "FITSDecodedRenderSource" )
struct FITSDecodedRenderSourceTests
{
    /// A monochrome 4×4 ramp image HDU.
    private static func monoHDU() -> ( data: Data, properties: [ FITSPropertySnapshot ] )
    {
        let properties =
            [
                FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
                FITSPropertySnapshot( name: "NAXIS",  value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS1", value: .integer( 4 ) ),
                FITSPropertySnapshot( name: "NAXIS2", value: .integer( 4 ) ),
            ]

        return ( Data( ( 0 ..< 16 ).map { UInt8( $0 * 10 ) } ), properties )
    }

    /// An RGB colour-plane image HDU (`NAXIS=3`, `NAXIS3=3`), the shape
    /// ``ImageProcessor/decodedImageHDU(data:properties:)`` does not decode ahead.
    private static func rgbPlanesHDU() -> ( data: Data, properties: [ FITSPropertySnapshot ] )
    {
        let properties =
            [
                FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
                FITSPropertySnapshot( name: "NAXIS",  value: .integer( 3 ) ),
                FITSPropertySnapshot( name: "NAXIS1", value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS2", value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS3", value: .integer( 3 ) ),
            ]

        return ( Data( ( 0 ..< 12 ).map { UInt8( $0 * 10 ) } ), properties )
    }

    /// Rendering through the decode-once frame produces byte-identical output to the
    /// byte path, for several settings — the core "output unchanged" guarantee.
    @Test
    func decodeOnceRendersIdenticallyToTheBytePath() throws
    {
        let ( data, properties ) = Self.monoHDU()
        let source               = FITSRenderSource( data: data, properties: properties )
        let decoded              = try #require( try source.decoded() )

        for settings in [ ImageProcessor.Settings(), ImageProcessor.Settings( normalize: .identity ) ]
        {
            let viaBytes   = try source.makeResult( settings: settings )
            let viaDecoded = try decoded.makeResult( settings: settings )

            #expect( viaDecoded.bytes == viaBytes.bytes )
            #expect( viaDecoded.inputPixelFormat == viaBytes.inputPixelFormat )
            #expect( viaDecoded.outputPixelFormat == viaBytes.outputPixelFormat )
        }
    }

    /// A colour-plane frame cannot decode ahead, so ``FITSRenderSource/decoded()``
    /// returns `nil` and the renderer keeps the byte path.
    @Test
    func aColourPlaneFrameKeepsTheBytePath() throws
    {
        let ( data, properties ) = Self.rgbPlanesHDU()
        let source               = FITSRenderSource( data: data, properties: properties )

        #expect( try source.decoded() == nil )
    }

    /// The decoded frame's auto-stretch colour source is the mono luminance for a
    /// monochrome frame, and derives a usable stretch over the source's domain.
    @Test
    func autoStretchColorSourceIsMonoLuminance() throws
    {
        let ( data, properties ) = Self.monoHDU()
        let source               = FITSRenderSource( data: data, properties: properties )
        let decoded              = try #require( try source.decoded() )
        let colour               = try #require( decoded.autoStretchColorSource( maxDimension: nil ) )

        guard case .mono = colour
        else
        {
            Issue.record( "expected a mono colour source for a mono frame, got \( colour )" )

            return
        }

        #expect( ImageProcessor.autoStretchSettings( colorSource: colour, domain: source.autoStretchDomain ) != nil )
    }
}
