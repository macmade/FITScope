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

/// Tests for decoding a one-dimensional FITS HDU into a ``GraphSeries``: sample
/// scaling, the physical-vs-sample horizontal axis, and the axis labels.
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
}
