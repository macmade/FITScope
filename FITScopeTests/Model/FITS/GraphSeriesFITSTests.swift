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

/// Tests for decoding a FITS HDU into a ``GraphSeries``: a one-dimensional spectrum
/// (`NAXIS=1`) and a stack of spectra (`NAXIS=2`) — sample scaling, the
/// physical-vs-sample horizontal axis, the axis labels, the per-row lines, and the
/// spectra-stack detection rule.
@Suite( "GraphSeries+FITS" )
struct GraphSeriesFITSTests
{
    /// Parses a synthesized one-dimensional FITS file and decodes its HDU into a
    /// graph series.
    ///
    /// - Parameters:
    ///   - samples:      The signed 16-bit samples.
    ///   - extraRecords: Extra header records (WCS/scaling keywords).
    /// - Returns: The decoded series.
    private func decode( samples: [ Int16 ], extraRecords: [ String ] = [] ) throws -> GraphSeries
    {
        let data       = FITSTestData.oneDimensional( samples: samples, extraRecords: extraRecords )
        let file       = try FITSFile( data: data, options: .lenient )
        let dataIndex  = try #require( file.sections.firstIndex { $0.kind == .data }, "the 1-D file must have a data section" )
        let header     = file.sections[ dataIndex - 1 ]

        return try GraphSeries( oneDimensionalHeader: header, data: file.sections[ dataIndex ].data )
    }

    /// Every sample is decoded, with `BSCALE`/`BZERO` applied: `y = BZERO + BSCALE·raw`.
    @Test
    func decodesSamplesWithScaling() throws
    {
        let series = try self.decode( samples: [ 0, 100, -50 ], extraRecords: [ "BSCALE  = 2", "BZERO   = 10" ] )

        #expect( series.points.count == 3 )
        #expect( series.points.map { $0.y } == [ 10, 210, -90 ] )
    }

    /// Without scaling keywords, samples decode at their stored value and the axes
    /// are the plain sample number and "Value".
    @Test
    func decodesUnscaledSamplesOnSampleAxis() throws
    {
        let series = try self.decode( samples: [ 5, 6, 7 ] )

        #expect( series.points.map { $0.y } == [ 5, 6, 7 ] )
        #expect( series.points.map { $0.x } == [ 1, 2, 3 ], "the sample axis is one-based" )
        #expect( series.xAxisLabel == "Sample" )
        #expect( series.yAxisLabel == "Value" )
    }

    /// With a coordinate type and a non-zero increment, the horizontal axis is
    /// physical: `x = CRVAL1 + (pixel − CRPIX1)·CDELT1`, labelled from `CTYPE1`/`CUNIT1`.
    @Test
    func buildsPhysicalAxisFromWCS() throws
    {
        let series = try self.decode( samples: [ 1, 2, 3 ], extraRecords: [ "CTYPE1  = 'WAVE'", "CUNIT1  = 'nm'", "CRVAL1  = 400.0", "CRPIX1  = 1.0", "CDELT1  = 2.5" ] )

        #expect( series.points.map { $0.x } == [ 400.0, 402.5, 405.0 ] )
        #expect( series.xAxisLabel == "WAVE (nm)" )
    }

    /// A reference pixel other than 1 shifts the physical origin: with `CRPIX1=2`,
    /// the second sample sits at `CRVAL1`.
    @Test
    func honorsReferencePixel() throws
    {
        let series = try self.decode( samples: [ 1, 2, 3 ], extraRecords: [ "CTYPE1  = 'FREQ'", "CRVAL1  = 100.0", "CRPIX1  = 2.0", "CDELT1  = 10.0" ] )

        #expect( series.points.map { $0.x } == [ 90.0, 100.0, 110.0 ] )
    }

    /// A coordinate type with no increment cannot be scaled, so the axis falls back
    /// to the sample number labelled "Sample".
    @Test
    func fallsBackToSampleAxisWithoutIncrement() throws
    {
        let series = try self.decode( samples: [ 1, 2 ], extraRecords: [ "CTYPE1  = 'WAVE'" ] )

        #expect( series.points.map { $0.x } == [ 1, 2 ] )
        #expect( series.xAxisLabel == "Sample" )
    }

    /// The coordinate type alone (no unit) labels the axis without a parenthesized
    /// unit.
    @Test
    func labelsAxisWithoutUnit() throws
    {
        let series = try self.decode( samples: [ 1, 2 ], extraRecords: [ "CTYPE1  = 'WAVE'", "CDELT1  = 1.0" ] )

        #expect( series.xAxisLabel == "WAVE" )
    }

    /// The vertical axis is labelled from `BUNIT` when present.
    @Test
    func labelsValueAxisFromBUNIT() throws
    {
        let series = try self.decode( samples: [ 1, 2 ], extraRecords: [ "BUNIT   = 'Jy'" ] )

        #expect( series.yAxisLabel == "Jy" )
    }

    /// Points keep a stable, zero-based index identity independent of their `x`.
    @Test
    func pointsCarryStableIndex() throws
    {
        let series = try self.decode( samples: [ 9, 8, 7 ] )

        #expect( series.points.map { $0.index } == [ 0, 1, 2 ] )
        #expect( series.points.map { $0.id }    == [ 0, 1, 2 ] )
    }

    /// Decodes a synthesized stacked-spectra (`NAXIS=2`) FITS file into a multi-line
    /// graph series.
    ///
    /// - Parameters:
    ///   - rows:         The per-spectrum signed 16-bit samples.
    ///   - extraRecords: Extra header records (WCS/scaling keywords).
    /// - Returns: The decoded series.
    private func decodeStack( rows: [ [ Int16 ] ], extraRecords: [ String ] = [ "CTYPE1  = 'WAVE'" ] ) throws -> GraphSeries
    {
        let data  = FITSTestData.stackedSpectra( rows: rows, extraRecords: extraRecords )
        let file  = try FITSFile( data: data, options: .lenient )
        let index = try #require( file.sections.firstIndex { $0.kind == .data }, "the stacked-spectra file must have a data section" )

        return try GraphSeries( stackedSpectraHeader: file.sections[ index - 1 ], data: file.sections[ index ].data )
    }

    /// Parses a synthesized `NAXIS=2` FITS file and returns the image HDU's header,
    /// for exercising the spectra-stack detection rule.
    ///
    /// - Parameters:
    ///   - extraRecords: The header records under test (e.g. a `CTYPE1`).
    ///   - rows:         The stack's rows (default two 2-sample rows).
    /// - Returns: The image HDU header.
    private func header( extraRecords: [ String ], rows: [ [ Int16 ] ] = [ [ 1, 2 ], [ 3, 4 ] ] ) throws -> FITSSection
    {
        let data  = FITSTestData.stackedSpectra( rows: rows, extraRecords: extraRecords )
        let file  = try FITSFile( data: data, options: .lenient )
        let index = try #require( file.sections.firstIndex { $0.kind == .data }, "the file must have a data section" )

        return file.sections[ index - 1 ]
    }

    /// Each row becomes its own named line (`"Row 1"`, `"Row 2"`, …), decoded in
    /// storage order, and the series reports itself as multi-line.
    @Test
    func decodesStackedSpectraAsNamedLines() throws
    {
        let series = try self.decodeStack( rows: [ [ 10, 20, 30 ], [ 40, 50, 60 ] ] )

        #expect( series.lines.count == 2 )
        #expect( series.lines.map { $0.name } == [ "Row 1", "Row 2" ] )
        #expect( series.lines[ 0 ].points.map { $0.y } == [ 10, 20, 30 ] )
        #expect( series.lines[ 1 ].points.map { $0.y } == [ 40, 50, 60 ] )
        #expect( series.isMultiLine )
    }

    /// Every row shares the one physical horizontal axis built from the header, so a
    /// stack overlays its spectra on a common dispersion axis.
    @Test
    func stackedSpectraRowsShareHorizontalAxis() throws
    {
        let series   = try self.decodeStack( rows: [ [ 1, 2, 3 ], [ 4, 5, 6 ] ], extraRecords: [ "CTYPE1  = 'WAVE'", "CUNIT1  = 'nm'", "CRVAL1  = 400.0", "CRPIX1  = 1.0", "CDELT1  = 2.5" ] )
        let expected = [ 400.0, 402.5, 405.0 ]

        #expect( series.lines[ 0 ].points.map { $0.x } == expected )
        #expect( series.lines[ 1 ].points.map { $0.x } == expected )
        #expect( series.xAxisLabel == "WAVE (nm)" )
    }

    /// `BSCALE`/`BZERO` are applied to every row's samples.
    @Test
    func stackedSpectraAppliesScalingPerRow() throws
    {
        let series = try self.decodeStack( rows: [ [ 0, 100 ], [ -50, 100 ] ], extraRecords: [ "CTYPE1  = 'WAVE'", "BSCALE  = 2", "BZERO   = 10" ] )

        #expect( series.lines[ 0 ].points.map { $0.y } == [ 10, 210 ] )
        #expect( series.lines[ 1 ].points.map { $0.y } == [ -90, 210 ] )
    }

    /// Every FITS WCS spectral coordinate type (Paper III, Table 1) marks a `NAXIS=2`
    /// file as a spectra stack.
    @Test
    func detectsEveryKnownSpectralType() throws
    {
        for code in [ "FREQ", "ENER", "WAVN", "VRAD", "WAVE", "VOPT", "ZOPT", "AWAV", "VELO", "BETA" ]
        {
            let header = try self.header( extraRecords: [ "CTYPE1  = '\( code )'" ] )

            #expect( GraphSeries.isSpectraStack( header: header ), "\( code ) is a spectral type" )
        }
    }

    /// A spectral `CTYPE1` with an algorithm-code suffix (e.g. `WAVE-F2W`) is still
    /// recognized by its root.
    @Test
    func detectsSpectralTypeWithAlgorithmSuffix() throws
    {
        #expect( GraphSeries.isSpectraStack( header: try self.header( extraRecords: [ "CTYPE1  = 'WAVE-F2W'" ] ) ) )
    }

    /// A normal image is never a stack: a spatial `CTYPE1`, no `CTYPE1`, or a
    /// non-spectral label (`PIXEL`) all keep it on the raster path — the no-regression
    /// guarantee.
    @Test
    func rejectsNormalImageAsStack() throws
    {
        #expect( GraphSeries.isSpectraStack( header: try self.header( extraRecords: [ "CTYPE1  = 'RA---TAN'", "CTYPE2  = 'DEC--TAN'" ] ) ) == false )
        #expect( GraphSeries.isSpectraStack( header: try self.header( extraRecords: [] ) ) == false, "no CTYPE1 → not a stack" )
        #expect( GraphSeries.isSpectraStack( header: try self.header( extraRecords: [ "CTYPE1  = 'PIXEL'" ] ) ) == false, "PIXEL is not a known spectral type" )
    }

    /// A long-slit spectrogram — a spectral `CTYPE1` but a spatial `CTYPE2` — is a
    /// genuine 2-D image and stays an image, whether the spatial axis is equatorial,
    /// galactic, or ecliptic (any longitude/latitude); a spectral `CTYPE1` with a
    /// non-spatial `CTYPE2` is a stack.
    @Test
    func rejectsLongSlitSpectrogramButAcceptsNonSpatialSecondAxis() throws
    {
        for spatial in [ "DEC--TAN", "RA---TAN", "GLAT-CAR", "GLON-CAR", "ELAT-TAN", "ELON-TAN" ]
        {
            #expect( GraphSeries.isSpectraStack( header: try self.header( extraRecords: [ "CTYPE1  = 'WAVE'", "CTYPE2  = '\( spatial )'" ] ) ) == false, "spatial CTYPE2 \( spatial ) → a long-slit image" )
        }

        #expect( GraphSeries.isSpectraStack( header: try self.header( extraRecords: [ "CTYPE1  = 'WAVE'", "CTYPE2  = 'PIXEL'" ] ) ), "non-spatial CTYPE2 → a stack" )
    }

    /// A truncated stacked-spectra HDU cannot be decoded: the initializer throws, so
    /// the loader's best-effort decode falls through to the raster path — matching a
    /// malformed 2-D file rather than failing the whole load.
    @Test
    func truncatedStackedSpectraThrows() throws
    {
        // The default header declares NAXIS1 = NAXIS2 = 2 (8 bytes at BITPIX 16); far
        // fewer bytes are supplied.
        let header = try self.header( extraRecords: [ "CTYPE1  = 'WAVE'" ] )

        #expect( throws: ( any Error ).self )
        {
            _ = try GraphSeries( stackedSpectraHeader: header, data: Data( [ 0, 1, 2, 3 ] ) )
        }
    }

    /// A one-dimensional file is not a stack — the rule requires `NAXIS=2`.
    @Test
    func oneDimensionalFileIsNotStack() throws
    {
        let data  = FITSTestData.oneDimensional( samples: [ 1, 2, 3 ], extraRecords: [ "CTYPE1  = 'WAVE'" ] )
        let file  = try FITSFile( data: data, options: .lenient )
        let index = try #require( file.sections.firstIndex { $0.kind == .data }, "the 1-D file must have a data section" )

        #expect( GraphSeries.isSpectraStack( header: file.sections[ index - 1 ] ) == false )
    }
}
