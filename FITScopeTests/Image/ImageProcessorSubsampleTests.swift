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

/// Tests for `AutoStretchColorSource.subsampled`, the app-side dispatch that maps
/// each colour-source case onto the generic `PixelBuffer` decimation (mono/channels
/// per sample, a Bayer mosaic in whole 2×2 cells). The decimation math itself is
/// covered in SwiftPixel's `Test_PixelBuffer_Decimate`; here we verify the case and
/// pattern are carried through and the `nil` cap is a no-op.
@Suite( "ImageProcessor.AutoStretchColorSource subsampling" )
struct ImageProcessorSubsampleTests
{
    /// The underlying buffer of a colour source, for asserting on dimensions
    /// regardless of the case.
    private func buffer( of source: ImageProcessor.AutoStretchColorSource ) -> PixelBuffer
    {
        switch source
        {
            case .mono( let buffer ):        return buffer
            case .channels( let buffer ):    return buffer
            case .mosaic( let buffer, _ ):   return buffer
        }
    }

    @Test
    func returnsSelfForNilMaximum() throws
    {
        let buffer = try PixelBuffer( width: 4, height: 4, channels: 1, pixels: ( 0 ..< 16 ).map { Double( $0 ) }, isNormalized: false )
        let source = ImageProcessor.AutoStretchColorSource.mono( buffer )
        let result = source.subsampled( maxDimension: nil )

        #expect( self.buffer( of: result ).width == 4 )
        #expect( self.buffer( of: result ).height == 4 )
    }

    @Test
    func monoIsDecimatedPerSample() throws
    {
        let buffer = try PixelBuffer( width: 4, height: 4, channels: 1, pixels: ( 0 ..< 16 ).map { Double( $0 ) }, isNormalized: false )
        let result = ImageProcessor.AutoStretchColorSource.mono( buffer ).subsampled( maxDimension: 2 )

        guard case .mono( let reduced ) = result
        else
        {
            Issue.record( "Expected a mono colour source" )

            return
        }

        // Per-sample decimation (blockSize 1): the top-left of each 2x2 block.
        #expect( reduced.pixels == [ 0, 2, 8, 10 ] )
    }

    @Test
    func mosaicIsDecimatedInWholeCellsPreservingPattern() throws
    {
        let buffer = try PixelBuffer( width: 8, height: 8, channels: 1, pixels: ( 0 ..< 64 ).map { Double( $0 ) }, isNormalized: false )
        let result = ImageProcessor.AutoStretchColorSource.mosaic( buffer, pattern: .rggb ).subsampled( maxDimension: 4 )

        guard case .mosaic( let reduced, let pattern ) = result
        else
        {
            Issue.record( "Expected a mosaic colour source" )

            return
        }

        // The case and its Bayer pattern are carried through, and the 2×2-cell
        // decimation preserves the mosaic's phase (verified in SwiftPixel).
        #expect( pattern == .rggb )
        #expect( reduced.width == 4 )
        #expect( reduced.height == 4 )
        #expect( reduced.pixels == [ 0, 1, 4, 5, 8, 9, 12, 13, 32, 33, 36, 37, 40, 41, 44, 45 ] )
    }

    @Test
    func previewBinFactorGatesOnMosaicAndReduction() throws
    {
        // A mosaic downsampled to <= half its size bins by 2.
        #expect( ImageProcessor.previewBinFactor( maxSide: 3008, maxDimension: 1024, isMosaic: true ) == 2 )
        #expect( ImageProcessor.previewBinFactor( maxSide: 2048, maxDimension: 1024, isMosaic: true ) == 2 )

        // A non-mosaic source never bins (a plain box average handles it post-debayer).
        #expect( ImageProcessor.previewBinFactor( maxSide: 3008, maxDimension: 1024, isMosaic: false ) == 1 )

        // A full-resolution render (no cap) never bins — so the preview extension doesn't.
        #expect( ImageProcessor.previewBinFactor( maxSide: 3008, maxDimension: nil, isMosaic: true ) == 1 )

        // A reduction of less than half would upsample after a bin, so it is skipped.
        #expect( ImageProcessor.previewBinFactor( maxSide: 1500, maxDimension: 1024, isMosaic: true ) == 1 )
    }
}
