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
import SwiftPixel

public enum PreviewHelper
{
    public enum TestFile
    {
        case M42
        case HST_FOS
    }

    public static func url( file: TestFile ) -> URL?
    {
        switch file
        {
            case .M42:     return Bundle.main.url( forResource: "2025-03-02_21-20-31_G252_B1x1_O7_T-9.80_F_10.00s_0000_H3.69", withExtension: "fits" )
            case .HST_FOS: return Bundle.main.url( forResource: "FOSy19g0309t_c2f", withExtension: "fits" )
        }
    }

    public static func data( file: TestFile ) -> Data?
    {
        guard let url = PreviewHelper.url( file: file )
        else
        {
            return nil
        }

        do
        {
            return try Data( contentsOf: url )
        }
        catch
        {
            return nil
        }
    }

    public static func file( file: TestFile ) -> FITSFile?
    {
        guard let url = PreviewHelper.url( file: file )
        else
        {
            return nil
        }

        do
        {
            return try FITSFile( url: url, options: .lenient )
        }
        catch
        {
            return nil
        }
    }

    public static func info( file: TestFile ) -> FITSImageInfo?
    {
        guard let url  = self.url( file: file ),
              let file = self.file( file: file )
        else
        {
            return nil
        }

        return FITSImageInfo( url: url, file: file )
    }

    public static func section( file: TestFile ) -> FITSImageSection?
    {
        self.info( file: file )?.sections.first
    }

    public static func properties( file: TestFile ) -> [ FITSImageProperty ]?
    {
        self.section( file: file )?.properties
    }

    public static func property( file: TestFile ) -> FITSImageProperty?
    {
        self.properties( file: file )?.first
    }

    public static func histogram() -> FITSImageRenderer.Histogram
    {
        let bytes     = self.generateRandomRGBData( count: 1000 )
        let rgb       = Histogram( bytes: bytes, channels: 3, mode: .rgb )
        let luminance = Histogram( bytes: bytes, channels: 3, mode: .luminance )

        return FITSImageRenderer.Histogram( rgb: rgb, luminance: luminance )
    }

    public static func statistics() -> FITSImageRenderer.HistogramStatistics
    {
        let histogram = self.histogram()
        let red       = HistogramStatistics( data: histogram.rgb.data[ 0 ] )
        let green     = HistogramStatistics( data: histogram.rgb.data[ 1 ] )
        let blue      = HistogramStatistics( data: histogram.rgb.data[ 2 ] )
        let luminance = HistogramStatistics( data: histogram.luminance.data[ 0 ] )

        return FITSImageRenderer.HistogramStatistics(
            red:       red,
            green:     green,
            blue:      blue,
            luminance: luminance
        )
    }

    public static func generateRandomRGBData( count: Int ) -> [ UInt8 ]
    {
        let bins  = 256
        let rHist = self.gaussianCurve( bins: bins, mean: 80, stdDev: 15 )
        let gHist = self.gaussianCurve( bins: bins, mean: 130, stdDev: 20 )
        let bHist = self.gaussianCurve( bins: bins, mean: 180, stdDev: 25 )
        var data  = [ UInt8 ]()

        data.reserveCapacity( count * 3 )

        ( 0 ..< count ).forEach
        {
            _ in

            let r = self.weightedRandom( from: rHist )
            let g = self.weightedRandom( from: gHist )
            let b = self.weightedRandom( from: bHist )

            data.append( UInt8( r ) )
            data.append( UInt8( g ) )
            data.append( UInt8( b ) )
        }

        return data
    }

    private static func gaussianCurve( bins: Int, mean: Double, stdDev: Double ) -> [ Int ]
    {
        ( 0 ..< bins ).map
        {
            let x     = Double( $0 )
            let value = exp( -pow( x - mean, 2 ) / ( 2 * pow( stdDev, 2 ) ) )

            return Int( value * 1000 )
        }
    }

    private static func weightedRandom( from weights: [ Int ] ) -> Int
    {
        let total     = weights.reduce( 0, + )
        let threshold = Int.random( in: 0 ..< total )
        var sum       = 0

        for ( i, w ) in weights.enumerated()
        {
            sum += w

            if sum > threshold
            {
                return i
            }
        }

        return weights.count - 1
    }
}
