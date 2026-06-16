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

/// Tests for `ImageProcessor`'s header interpretation, in particular the linear
/// pixel-scaling keywords `BSCALE` / `BZERO`.
@Suite( "ImageProcessor" )
struct ImageProcessorTests
{
    /// Scaling keywords written in floating-point form must be honoured rather
    /// than read as the integer defaults. UIT's `BSCALE` is float-formatted.
    @Test
    func floatScalingKeywordsAreHonoured() throws
    {
        let file = try FITSFile( data: Data( contentsOf: FITSCorpus.url( "NASA/UITfuv2582gc.fits" ) ), options: .lenient )
        let hdu  = try FITSImageRenderer.renderInput( from: file.sections )

        let headerScale = try #require( hdu.properties.first { $0.name == "BSCALE" }?.value.float )
        let scaling     = ImageProcessor.scaling( from: hdu.properties )

        #expect( scaling.scale == headerScale )
        #expect( scaling.scale != 1, "a float BSCALE must not fall back to the default scale" )
    }

    /// Integer-formatted scaling keywords keep working. The M42 file's `BZERO`
    /// is the integer `32768`.
    @Test
    func integerScalingKeywordsAreHonoured() throws
    {
        let file = try FITSFile( data: Data( contentsOf: FITSCorpus.url( "2025-03-02_21-20-31_G252_B1x1_O7_T-9.80_F_10.00s_0000_H3.69.fits" ) ), options: .lenient )
        let hdu  = try FITSImageRenderer.renderInput( from: file.sections )

        let scaling = ImageProcessor.scaling( from: hdu.properties )

        #expect( scaling.offset == 32768 )
    }

    /// A non-positive `NAXIS2` is rejected with a diagnostic that names the
    /// offending axis and value — NAXIS2, not NAXIS1.
    @Test
    func nonPositiveNAXIS2IsRejectedNamingTheAxis() throws
    {
        let properties: [ FITSPropertySnapshot ] =
        [
            FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
            FITSPropertySnapshot( name: "NAXIS",  value: .integer( 2 ) ),
            FITSPropertySnapshot( name: "NAXIS1", value: .integer( 1 ) ),
            FITSPropertySnapshot( name: "NAXIS2", value: .integer( 0 ) ),
        ]

        let error = try #require( throws: ( any Error ).self )
        {
            _ = try ImageProcessor.render( data: Data(), properties: properties )
        }

        let message = "\( error )"

        #expect( message.contains( "NAXIS2" ), "the error must name NAXIS2, got: \"\( message )\"" )
        #expect( message.contains( "0" ),      "the error must report the offending value, got: \"\( message )\"" )
    }
}
