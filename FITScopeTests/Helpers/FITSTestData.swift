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

/// Synthesised, minimal FITS payloads for tests that need a precisely shaped
/// file rather than a bundled corpus sample.
enum FITSTestData
{
    /// A monochrome 8-bit pixel ramp and its header properties, ready to feed
    /// straight into `ImageProcessor.render`.
    ///
    /// The values span the full `0...255` range so that, after min/max
    /// normalisation, any monotonic stretch produces a varied (non-flat,
    /// non-black) result.
    static func gradient( width: Int = 16, height: Int = 16 ) -> ( data: Data, properties: [ FITSPropertySnapshot ] )
    {
        let count = max( width * height, 1 )
        let bytes = ( 0 ..< count ).map { UInt8( ( $0 * 255 ) / max( count - 1, 1 ) ) }

        let properties =
            [
                FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
                FITSPropertySnapshot( name: "NAXIS",  value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS1", value: .integer( Int64( width ) ) ),
                FITSPropertySnapshot( name: "NAXIS2", value: .integer( Int64( height ) ) ),
            ]

        return ( Data( bytes ), properties )
    }

    /// A minimal, valid one-dimensional (`NAXIS=1`) `BITPIX=16` FITS file carrying
    /// the given signed 16-bit samples, big-endian, as a header block plus a
    /// block-padded data segment.
    ///
    /// Extra header records (e.g. `"CTYPE1  = 'WAVE'"`, `"CDELT1  = 2.5"`) are
    /// inserted verbatim before `END`, so a caller can attach world-coordinate or
    /// scaling keywords. The samples take the graph branch (`NAXIS=1`) rather than
    /// the image pipeline.
    ///
    /// - Parameters:
    ///   - samples:      The signed 16-bit samples, in order.
    ///   - extraRecords: Additional header records to insert before `END`.
    /// - Returns: The complete FITS file bytes.
    static func oneDimensional( samples: [ Int16 ], extraRecords: [ String ] = [] ) -> Data
    {
        let records =
            [
                "SIMPLE  = T",
                "BITPIX  = 16",
                "NAXIS   = 1",
                "NAXIS1  = \( samples.count )",
            ]
            + extraRecords
            + [ "END" ]

        let header = records.map { $0.padding( toLength: 80, withPad: " ", startingAt: 0 ) }.joined()

        var data = Data( header.padding( toLength: FITSFile.blockSize, withPad: " ", startingAt: 0 ).utf8 )

        // Big-endian 16-bit samples.
        var payload = samples.reduce( into: Data() )
        {
            payload, sample in

            let bits = UInt16( bitPattern: sample )

            payload.append( UInt8( bits >> 8 ) )
            payload.append( UInt8( bits & 0xFF ) )
        }

        // Pad the data segment up to a whole FITS block.
        let remainder = payload.count % FITSFile.blockSize

        if remainder != 0
        {
            payload.append( Data( count: FITSFile.blockSize - remainder ) )
        }

        data.append( payload )

        return data
    }

    /// A minimal, valid two-dimensional (`NAXIS=2`) `BITPIX=16` FITS file holding a
    /// stack of one-dimensional spectra — one row per spectrum, big-endian, as a
    /// header block plus a block-padded data segment.
    ///
    /// The rows are stored row-major (the FITS convention: the first axis varies
    /// fastest, so each row is contiguous). Extra header records are inserted verbatim
    /// before `END`; the default carries a spectral `CTYPE1` so the file is detected
    /// as a spectra stack and takes the multi-line graph branch. Every row must have
    /// the same length.
    ///
    /// - Parameters:
    ///   - rows:         The per-spectrum signed 16-bit samples, one array per row.
    ///   - extraRecords: Additional header records to insert before `END`.
    /// - Returns: The complete FITS file bytes.
    static func stackedSpectra( rows: [ [ Int16 ] ], extraRecords: [ String ] = [ "CTYPE1  = 'WAVE'" ] ) -> Data
    {
        let width = rows.first?.count ?? 0

        let records =
            [
                "SIMPLE  = T",
                "BITPIX  = 16",
                "NAXIS   = 2",
                "NAXIS1  = \( width )",
                "NAXIS2  = \( rows.count )",
            ]
            + extraRecords
            + [ "END" ]

        let header = records.map { $0.padding( toLength: 80, withPad: " ", startingAt: 0 ) }.joined()

        var data = Data( header.padding( toLength: FITSFile.blockSize, withPad: " ", startingAt: 0 ).utf8 )

        // Row-major big-endian 16-bit samples (each row contiguous).
        var payload = rows.flatMap { $0 }.reduce( into: Data() )
        {
            payload, sample in

            let bits = UInt16( bitPattern: sample )

            payload.append( UInt8( bits >> 8 ) )
            payload.append( UInt8( bits & 0xFF ) )
        }

        let remainder = payload.count % FITSFile.blockSize

        if remainder != 0
        {
            payload.append( Data( count: FITSFile.blockSize - remainder ) )
        }

        data.append( payload )

        return data
    }

    /// An RGB colour-planes image (`NAXIS=3`, third axis = 3) and its header
    /// properties, ready to feed straight into `ImageProcessor.render`.
    ///
    /// The three `width × height` planes are stored band-sequential (all of the
    /// red plane, then green, then blue — the FITS convention) with distinct
    /// per-channel ramps so the channels are individually identifiable. The header
    /// carries `CTYPE1`/`CTYPE2` and no `CTYPE3`, so it matches the RGB-planes
    /// detection rule.
    ///
    /// - Parameters:
    ///   - width:  The plane width in pixels.
    ///   - height: The plane height in pixels.
    /// - Returns: The band-sequential bytes and the header properties.
    static func rgbPlanes( width: Int = 2, height: Int = 2 ) -> ( data: Data, properties: [ FITSPropertySnapshot ] )
    {
        let count = max( width * height, 1 )

        // Distinct 8-bit ramps per channel so a decoded channel is identifiable:
        // red 10, 20, …; green 50, 60, …; blue 90, 100, …
        let red   = ( 0 ..< count ).map { UInt8( truncatingIfNeeded: 10 + $0 * 10 ) }
        let green = ( 0 ..< count ).map { UInt8( truncatingIfNeeded: 50 + $0 * 10 ) }
        let blue  = ( 0 ..< count ).map { UInt8( truncatingIfNeeded: 90 + $0 * 10 ) }

        let properties =
            [
                FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
                FITSPropertySnapshot( name: "NAXIS",  value: .integer( 3 ) ),
                FITSPropertySnapshot( name: "NAXIS1", value: .integer( Int64( width ) ) ),
                FITSPropertySnapshot( name: "NAXIS2", value: .integer( Int64( height ) ) ),
                FITSPropertySnapshot( name: "NAXIS3", value: .integer( 3 ) ),
                FITSPropertySnapshot( name: "CTYPE1", value: .string( "RA---TAN" ) ),
                FITSPropertySnapshot( name: "CTYPE2", value: .string( "DEC--TAN" ) ),
            ]

        return ( Data( red + green + blue ), properties )
    }

    /// A minimal, valid RGB colour-planes FITS file (`NAXIS=3`, third axis = 3,
    /// `BITPIX=8`): three `width × height` band-sequential planes as a header block
    /// plus a block-padded data segment.
    ///
    /// Extra header records are inserted verbatim before `END`, so a caller can
    /// attach or override keywords (e.g. drop `CTYPE1`, or add `CTYPE3`, to exercise
    /// the non-RGB `NAXIS=3` rejection path).
    ///
    /// - Parameters:
    ///   - width:        The plane width in pixels.
    ///   - height:       The plane height in pixels.
    ///   - extraRecords: Additional header records to insert before `END`.
    /// - Returns: The complete FITS file bytes.
    static func rgbCube( width: Int = 2, height: Int = 2, extraRecords: [ String ] = [ "CTYPE1  = 'RA---TAN'", "CTYPE2  = 'DEC--TAN'" ] ) -> Data
    {
        let count = max( width * height, 1 )
        let red   = ( 0 ..< count ).map { UInt8( truncatingIfNeeded: 10 + $0 * 10 ) }
        let green = ( 0 ..< count ).map { UInt8( truncatingIfNeeded: 50 + $0 * 10 ) }
        let blue  = ( 0 ..< count ).map { UInt8( truncatingIfNeeded: 90 + $0 * 10 ) }

        let records =
            [
                "SIMPLE  = T",
                "BITPIX  = 8",
                "NAXIS   = 3",
                "NAXIS1  = \( width )",
                "NAXIS2  = \( height )",
                "NAXIS3  = 3",
            ]
            + extraRecords
            + [ "END" ]

        let header = records.map { $0.padding( toLength: 80, withPad: " ", startingAt: 0 ) }.joined()

        var data    = Data( header.padding( toLength: FITSFile.blockSize, withPad: " ", startingAt: 0 ).utf8 )
        var payload = Data( red + green + blue )

        // Pad the data segment up to a whole FITS block.
        let remainder = payload.count % FITSFile.blockSize

        if remainder != 0
        {
            payload.append( Data( count: FITSFile.blockSize - remainder ) )
        }

        data.append( payload )

        return data
    }

    /// A minimal, valid multi-image `NAXIS=3` cube FITS file (`BITPIX=8`): a stack
    /// of `planes` band-sequential `width × height` images, as a header block plus a
    /// block-padded data segment.
    ///
    /// The third axis is a plain frame index — no `CTYPE3` — and the plane count is
    /// *not* 3, so the file matches the multi-image rule
    /// (``ImageProcessor/isMultiImageCube(properties:)``) rather than the RGB rule.
    /// Each plane is filled with a distinct per-plane ramp (`plane p` starts at
    /// `(p + 1) · 20`) so a decoded frame is individually identifiable.
    ///
    /// Extra header records are inserted verbatim before `END`, so a caller can add
    /// keywords (e.g. `CTYPE3` to exercise the physical-cube rejection path, or a
    /// WCS).
    ///
    /// - Parameters:
    ///   - width:        The plane width in pixels.
    ///   - height:       The plane height in pixels.
    ///   - planes:       The number of stacked images (the third-axis length).
    ///   - extraRecords: Additional header records to insert before `END`.
    /// - Returns: The complete FITS file bytes.
    static func multiImageCube( width: Int = 2, height: Int = 2, planes: Int = 4, extraRecords: [ String ] = [] ) -> Data
    {
        let count   = max( width * height, 1 )
        let samples = ( 0 ..< planes ).flatMap
        {
            plane in

            ( 0 ..< count ).map { UInt8( truncatingIfNeeded: ( plane + 1 ) * 20 + $0 ) }
        }

        let records =
            [
                "SIMPLE  = T",
                "BITPIX  = 8",
                "NAXIS   = 3",
                "NAXIS1  = \( width )",
                "NAXIS2  = \( height )",
                "NAXIS3  = \( planes )",
            ]
            + extraRecords
            + [ "END" ]

        let header = records.map { $0.padding( toLength: 80, withPad: " ", startingAt: 0 ) }.joined()

        var data    = Data( header.padding( toLength: FITSFile.blockSize, withPad: " ", startingAt: 0 ).utf8 )
        var payload = Data( samples )

        // Pad the data segment up to a whole FITS block.
        let remainder = payload.count % FITSFile.blockSize

        if remainder != 0
        {
            payload.append( Data( count: FITSFile.blockSize - remainder ) )
        }

        data.append( payload )

        return data
    }

    /// A minimal, valid header-only FITS file
    /// (`SIMPLE=T / BITPIX=8 / NAXIS=0 / END`) as a single space-padded block.
    static func headerOnly() -> Data
    {
        let records =
            [
                "SIMPLE  = T",
                "BITPIX  = 8",
                "NAXIS   = 0",
                "END",
            ]
        let header = records.map { $0.padding( toLength: 80, withPad: " ", startingAt: 0 ) }.joined()

        return Data( header.padding( toLength: FITSFile.blockSize, withPad: " ", startingAt: 0 ).utf8 )
    }

    /// A minimal, valid `BITPIX = 64` image ( 1 × 1 ) — a format the pixel
    /// pipeline does not support — as a header block plus one zero-filled data
    /// block.
    static func bitpix64() -> Data
    {
        let records =
            [
                "SIMPLE  = T",
                "BITPIX  = 64",
                "NAXIS   = 2",
                "NAXIS1  = 1",
                "NAXIS2  = 1",
                "END",
            ]
        let header = records.map { $0.padding( toLength: 80, withPad: " ", startingAt: 0 ) }.joined()

        var data = Data( header.padding( toLength: FITSFile.blockSize, withPad: " ", startingAt: 0 ).utf8 )

        data.append( Data( count: FITSFile.blockSize ) )

        return data
    }
}
