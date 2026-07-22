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

/// Tests the RAW-facing ``ImageProcessor`` entry: decoding a cropped 16-bit sensor
/// mosaic into a displayable image, the per-pixel read-out, and the linear
/// luminance — driven on hand-built mosaic data so the maths is deterministic.
@Suite( "ImageProcessor+RAW" )
struct ImageProcessorRAWTests
{
    /// Packs 16-bit mosaic samples into host-order bytes, as the loader's crop does.
    private static func data( _ samples: [ UInt16 ] ) -> Data
    {
        samples.withUnsafeBytes { Data( $0 ) }
    }

    /// A colour-filter-array mosaic renders as colour (debayered), reported as a `.cfa`
    /// input layout at the image's geometry.
    @Test
    func rendersColorFilterArrayAsColor() throws
    {
        let samples    = ( 0 ..< 16 ).map { UInt16( $0 * 1000 ) }
        let properties = RAWImageProperties( width: 4, height: 4, colorFilterArrayPattern: "RGGB", whiteLevel: 65535 )
        let result     = try ImageProcessor.render( data: Self.data( samples ), raw: properties )

        #expect( result.inputPixelFormat == .cfa )
        #expect( result.image.width == 4 )
        #expect( result.image.height == 4 )
    }

    /// A colour-filter-array sensor exposes its raw mosaic and pattern for a
    /// per-channel auto Screen Transfer.
    @Test
    func colorSourceIsMosaicForACFASensor() throws
    {
        let samples    = ( 0 ..< 16 ).map { UInt16( $0 * 1000 ) }
        let properties = RAWImageProperties( width: 4, height: 4, colorFilterArrayPattern: "RGGB", whiteLevel: 65535 )
        let source     = try #require( ImageProcessor.rawAutoStretchColorSource( data: Self.data( samples ), properties: properties ) )

        guard case .mosaic( _, let pattern ) = source
        else
        {
            Issue.record( "a CFA RAW sensor must expose a mosaic colour input" )

            return
        }

        #expect( pattern == .rggb )
    }

    /// A monochrome sensor has no colour input, so the caller falls back to its
    /// single-channel luminance and a uniform STF.
    @Test
    func colorSourceIsNilForAMonoSensor() throws
    {
        let samples    = ( 0 ..< 16 ).map { UInt16( $0 * 1000 ) }
        let properties = RAWImageProperties( width: 4, height: 4, colorFilterArrayPattern: nil, whiteLevel: 65535 )

        #expect( ImageProcessor.rawAutoStretchColorSource( data: Self.data( samples ), properties: properties ) == nil )
    }

    /// A monochrome mosaic (no CFA pattern) renders as a mono image.
    @Test
    func rendersMonochromeAsMono() throws
    {
        let samples    = ( 0 ..< 16 ).map { UInt16( $0 * 1000 ) }
        let properties = RAWImageProperties( width: 4, height: 4, colorFilterArrayPattern: nil, whiteLevel: 65535 )
        let result     = try ImageProcessor.render( data: Self.data( samples ), raw: properties )

        #expect( result.inputPixelFormat == .mono )
        #expect( result.image.width == 4 )
        #expect( result.image.height == 4 )
    }

    /// The per-pixel read-out returns the raw sample and its fraction of the white
    /// level, in row-major order.
    @Test
    func readsBackSamples() throws
    {
        let samples    = [ UInt16 ]( [ 10, 20, 30, 40 ] )
        let properties = RAWImageProperties( width: 2, height: 2, colorFilterArrayPattern: "RGGB", whiteLevel: 100 )
        let data       = Self.data( samples )

        let topRight = try #require( ImageProcessor.rawImagePixelValues( data: data, properties: properties, x: 1, y: 0 ) )
        let bottom   = try #require( ImageProcessor.rawImagePixelValues( data: data, properties: properties, x: 0, y: 1 ) )

        #expect( topRight.count == 1 )
        #expect( topRight[ 0 ].value == 20 )
        #expect( topRight[ 0 ].fraction == 0.2 )
        #expect( bottom[ 0 ].value == 30 )
    }

    /// The read-out rejects out-of-bounds coordinates.
    @Test
    func readOutRejectsOutOfBounds() throws
    {
        let properties = RAWImageProperties( width: 2, height: 2, colorFilterArrayPattern: "RGGB", whiteLevel: 100 )
        let data       = Self.data( [ 10, 20, 30, 40 ] )

        #expect( ImageProcessor.rawImagePixelValues( data: data, properties: properties, x: 2, y: 0 ) == nil )
        #expect( ImageProcessor.rawImagePixelValues( data: data, properties: properties, x: 0, y: -1 ) == nil )
    }

    /// The linear luminance is the raw mosaic samples, at the image geometry.
    @Test
    func linearLuminanceIsRawSamples() throws
    {
        let samples    = [ UInt16 ]( [ 10, 20, 30, 40, 50, 60 ] )
        let properties = RAWImageProperties( width: 3, height: 2, colorFilterArrayPattern: "RGGB", whiteLevel: 65535 )
        let luminance  = try #require( ImageProcessor.rawImageLinearLuminance( data: Self.data( samples ), properties: properties ) )

        #expect( luminance.width == 3 )
        #expect( luminance.height == 2 )
        #expect( luminance.samples == samples.map { Double( $0 ) } )
    }

    /// Truncated mosaic data is rejected rather than read out of bounds.
    @Test
    func rejectsTruncatedData() throws
    {
        let properties = RAWImageProperties( width: 4, height: 4, colorFilterArrayPattern: "RGGB", whiteLevel: 65535 )

        #expect( throws: ( any Swift.Error ).self )
        {
            try ImageProcessor.render( data: Self.data( [ 1, 2, 3, 4 ] ), raw: properties )
        }
    }

    /// Every standard Bayer phase, including GBRG, renders as colour.
    @Test
    func rendersEveryStandardBayerPhase() throws
    {
        let samples = ( 0 ..< 16 ).map { UInt16( $0 * 1000 ) }

        try [ "RGGB", "BGGR", "GRBG", "GBRG" ].forEach
        {
            pattern in

            let properties = RAWImageProperties( width: 4, height: 4, colorFilterArrayPattern: pattern, whiteLevel: 65535 )
            let result     = try ImageProcessor.render( data: Self.data( samples ), raw: properties )

            #expect( result.inputPixelFormat == .cfa )
            #expect( result.image.width == 4 )
        }
    }

    /// With identity normalization, sensor counts render in their native full-scale
    /// `[0, 1]` domain — a mid-scale value renders as mid-grey, not clamped to white.
    /// This confirms the `1 / whiteLevel` scaling the config applies, matching the
    /// domain an auto Screen Transfer is authored in.
    @Test
    func rendersSamplesInFullScaleDomainUnderIdentity() throws
    {
        let samples    = [ UInt16 ]( [ 0, 32768, 65535, 32768 ] )
        let properties = RAWImageProperties( width: 2, height: 2, colorFilterArrayPattern: nil, whiteLevel: 65535 )
        let result     = try ImageProcessor.render( data: Self.data( samples ), raw: properties, settings: ImageProcessor.Settings( normalize: .identity ) )

        // Under the old scale-1 behaviour, identity would clamp 32768 to 1.0 (white);
        // the full-scale scaling instead maps it to ~0.5, so a mid-grey byte appears.
        #expect( result.bytes.contains { $0 > 0 && $0 < 200 } )
    }

    /// Min/max normalization is unaffected by the full-scale scaling (min/max is
    /// scale-invariant): a sensor-count ramp still spans black to white with the
    /// interior values in between, exactly as before the scaling was applied.
    @Test
    func minMaxRenderingIsUnchangedByFullScaleScaling() throws
    {
        let samples    = [ UInt16 ]( [ 10, 20, 30, 40 ] )
        let properties = RAWImageProperties( width: 2, height: 2, colorFilterArrayPattern: nil, whiteLevel: 65535 )
        let result     = try ImageProcessor.render( data: Self.data( samples ), raw: properties )

        // 10 → 0, 40 → 255, and the interior 20/30 map to (value − 10) / 30, i.e.
        // ~85 and ~170 — the same result the raw samples produced before scaling.
        #expect( result.bytes.contains { ( 80 ... 90 ).contains( $0 ) } )
        #expect( result.bytes.contains { ( 165 ... 175 ).contains( $0 ) } )
    }

    /// An unrecognized colour-filter-array pattern is rejected at render.
    @Test
    func rejectsUnsupportedPattern() throws
    {
        let samples    = ( 0 ..< 16 ).map { UInt16( $0 ) }
        let properties = RAWImageProperties( width: 4, height: 4, colorFilterArrayPattern: "CYGM", whiteLevel: 65535 )

        #expect( throws: ( any Swift.Error ).self )
        {
            try ImageProcessor.render( data: Self.data( samples ), raw: properties )
        }
    }
}
