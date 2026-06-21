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

import Foundation
import SwiftFITS
import SwiftPixel

/// Loads bundled sample FITS files and builds derived model objects for use in
/// SwiftUI previews and tests.
///
/// Every accessor is failable or returns synthetic data so that a preview keeps
/// rendering even when a sample file is missing from the bundle.
public enum PreviewHelper
{
    /// A sample FITS file bundled with the app for previews.
    public enum TestFile
    {
        /// A one-shot-colour (Bayer) deep-sky capture of the Orion Nebula.
        case M42

        /// A monochrome Hubble Faint Object Spectrograph frame.
        case HST_FOS
    }

    /// The bundle URL of the given sample file, or `nil` when it is not present.
    ///
    /// - Parameter file: The sample file to locate.
    /// - Returns: The file's URL, or `nil` if it is missing from the bundle.
    public static func url( file: TestFile ) -> URL?
    {
        switch file
        {
            case .M42:     return Bundle.main.url( forResource: "2025-03-02_21-20-31_G252_B1x1_O7_T-9.80_F_10.00s_0000_H3.69", withExtension: "fits" )
            case .HST_FOS: return Bundle.main.url( forResource: "FOSy19g0309t_c2f", withExtension: "fits" )
        }
    }

    /// The raw bytes of the given sample file.
    ///
    /// - Parameter file: The sample file to read.
    /// - Returns: The file's contents, or `nil` if it is missing or unreadable.
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

    /// Parses the given sample file into a `FITSFile`.
    ///
    /// - Parameter file: The sample file to parse.
    /// - Returns: The parsed file, or `nil` if it is missing or fails to parse.
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

    /// Builds the ``FITSImageInfo`` (header metadata) for the given sample file.
    ///
    /// - Parameter file: The sample file to describe.
    /// - Returns: The header info, or `nil` if the file is missing or unparsable.
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

    /// Builds a ``FITSImage`` (header info plus a renderer) for the given sample
    /// file, for previewing views that take a loaded image. The renderer has not
    /// rendered yet; call `render()` from the preview's `task` to populate its
    /// histogram and statistics.
    ///
    /// - Parameter file: The sample file to build an image for.
    /// - Returns: The image, or `nil` if the file is missing or unparsable.
    @MainActor
    public static func image( file: TestFile ) -> FITSImage?
    {
        guard let url      = self.url( file: file ),
              let fitsFile = self.file( file: file )
        else
        {
            return nil
        }

        let info     = FITSImageInfo( url: url, file: fitsFile )
        let renderer = FITSImageRenderer( file: fitsFile )

        return FITSImage( info: info, renderer: renderer )
    }

    /// Builds an ``OpenFile`` for the given sample file, for previewing views
    /// that observe a file as it loads. Call `load()` from the preview's `task`
    /// to populate its image.
    ///
    /// - Parameter file: The sample file to open.
    /// - Returns: The open file, or `nil` if the sample is missing.
    @MainActor
    public static func openFile( file: TestFile ) -> OpenFile?
    {
        guard let url = self.url( file: file )
        else
        {
            return nil
        }

        return OpenFile( url: url )
    }

    /// The first metadata section of the given sample file.
    ///
    /// - Parameter file: The sample file to inspect.
    /// - Returns: The first section, or `nil` if unavailable.
    public static func section( file: TestFile ) -> FITSImageSection?
    {
        self.info( file: file )?.sections.first
    }

    /// The header properties of the given sample file's first section.
    ///
    /// - Parameter file: The sample file to inspect.
    /// - Returns: The properties, or `nil` if unavailable.
    public static func properties( file: TestFile ) -> [ FITSImageProperty ]?
    {
        self.section( file: file )?.properties
    }

    /// The first header property of the given sample file's first section.
    ///
    /// - Parameter file: The sample file to inspect.
    /// - Returns: The first property, or `nil` if unavailable.
    public static func property( file: TestFile ) -> FITSImageProperty?
    {
        self.properties( file: file )?.first
    }

    /// Builds a synthetic histogram from random Gaussian-distributed RGB data,
    /// for previewing histogram views without rendering a real image.
    ///
    /// - Returns: A histogram with both RGB and luminance channels populated.
    public static func histogram() -> FITSImageRenderer.Histogram
    {
        let bytes     = self.generateRandomRGBData( count: 1000 )
        let rgb       = Histogram( bytes: bytes, channels: 3, mode: .rgb )
        let luminance = Histogram( bytes: bytes, channels: 3, mode: .luminance )
        let mono      = Histogram( bytes: bytes, channels: 3, mode: .mono )

        return FITSImageRenderer.Histogram( rgb: rgb, luminance: luminance, mono: mono, isMono: false )
    }

    /// Builds synthetic per-channel histogram statistics from the same random
    /// data as ``histogram()``, for previewing statistics views.
    ///
    /// - Returns: Statistics for the red, green, blue and luminance channels.
    public static func statistics() -> FITSImageRenderer.HistogramStatistics
    {
        let histogram = self.histogram()
        let red       = HistogramStatistics( data: histogram.rgb.data[ 0 ] )
        let green     = HistogramStatistics( data: histogram.rgb.data[ 1 ] )
        let blue      = HistogramStatistics( data: histogram.rgb.data[ 2 ] )
        let luminance = HistogramStatistics( data: histogram.luminance.data[ 0 ] )
        let mono      = HistogramStatistics( data: histogram.mono.data[ 0 ] )

        return FITSImageRenderer.HistogramStatistics(
            red:       red,
            green:     green,
            blue:      blue,
            luminance: luminance,
            mono:      mono
        )
    }

    /// Generates random interleaved RGB bytes whose per-channel distributions
    /// follow distinct Gaussian curves, producing a plausible-looking colour
    /// histogram.
    ///
    /// - Parameter count: The number of pixels to generate (three bytes each).
    /// - Returns: `count * 3` interleaved red, green and blue bytes.
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

    /// Builds a discrete Gaussian weight curve used to bias the random sampler
    /// toward a target brightness.
    ///
    /// - Parameters:
    ///   - bins:   The number of bins (typically 256, one per 8-bit level).
    ///   - mean:   The bin index at which the curve peaks.
    ///   - stdDev: The spread of the curve, in bins.
    /// - Returns: A per-bin weight, scaled to integers for sampling.
    private static func gaussianCurve( bins: Int, mean: Double, stdDev: Double ) -> [ Int ]
    {
        ( 0 ..< bins ).map
        {
            let x     = Double( $0 )
            let value = exp( -pow( x - mean, 2 ) / ( 2 * pow( stdDev, 2 ) ) )

            return Int( value * 1000 )
        }
    }

    /// Picks a bin index at random, weighted by the given per-bin weights.
    ///
    /// - Parameter weights: The relative weight of each bin.
    /// - Returns: The chosen bin index. Returns `0` when the weights are empty
    ///   or all zero, rather than trapping on an empty random range.
    static func weightedRandom( from weights: [ Int ] ) -> Int
    {
        let total = weights.reduce( 0, + )

        // An all-zero (or empty) weight set has no bin to pick; return the first
        // index rather than trapping on an empty `Int.random` range.
        guard total > 0
        else
        {
            return 0
        }

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
