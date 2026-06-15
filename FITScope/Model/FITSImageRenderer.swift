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

import SwiftFITS
import SwiftPixel
import SwiftUI
import SwiftUtilities

@MainActor
public class FITSImageRenderer: ObservableObject
{
    public struct Result
    {
        public let image:      CGImage
        public let bytes:      [ UInt8 ]
        public let histogram:  Histogram
        public let statistics: HistogramStatistics
    }

    public struct Histogram
    {
        public let rgb:       SwiftPixel.Histogram
        public let luminance: SwiftPixel.Histogram
    }

    public struct HistogramStatistics
    {
        public let red:       SwiftPixel.HistogramStatistics
        public let green:     SwiftPixel.HistogramStatistics
        public let blue:      SwiftPixel.HistogramStatistics
        public let luminance: SwiftPixel.HistogramStatistics
    }

    @Published public private( set ) var result: Result?
    @Published public private( set ) var error:  Error?

    private let file: FITSFile

    public init( file: FITSFile )
    {
        self.file = file
    }

    /// Selects the bytes and header properties of the first renderable image HDU.
    ///
    /// FITS files may place the image in an extension following an empty
    /// primary header, and a header-only file has no data section at all.
    /// Rather than indexing a fixed position — which mis-pairs extension data
    /// with the primary header and traps on single-section files — find the
    /// first `.data` section and pair it with the header that owns it (the
    /// section immediately preceding it in file order).
    ///
    /// - Parameter sections: The file's sections, in file order.
    /// - Returns: The data section's bytes and its owning header's properties.
    /// - Throws: ``RuntimeError`` when the file contains no image data section.
    nonisolated static func imageHDU( in sections: [ FITSSection ] ) throws -> ( data: Data, properties: [ FITSProperty ] )
    {
        guard let dataIndex = sections.firstIndex( where: { $0.kind == .data } ), dataIndex > 0
        else
        {
            throw RuntimeError( message: "FITS file contains no image HDU" )
        }

        return ( data: sections[ dataIndex ].data, properties: sections[ dataIndex - 1 ].properties )
    }

    public func render() async
    {
        let file = UnsafeSendable( self.file )

        do
        {
            let result = try await withCheckedThrowingContinuation
            {
                continuation in DispatchQueue.global( qos: .userInitiated ).async
                {
                    do
                    {
                        let hdu                 = try FITSImageRenderer.imageHDU( in: file.value.sections )
                        let render              = try ImageProcessor.render( data: hdu.data, properties: hdu.properties )
                        let rgbHistogram        = Benchmark.run( label: "Histogram (RGB)" ) { SwiftPixel.Histogram( bytes: render.bytes, channels: 3, mode: .rgb ) }
                        let luminanceHistogram  = Benchmark.run( label: "Histogram (L)"   ) { SwiftPixel.Histogram( bytes: render.bytes, channels: 3, mode: .luminance ) }
                        let redStatistics       = Benchmark.run( label: "Statistics (R)"  ) { SwiftPixel.HistogramStatistics( data: rgbHistogram.data[ 0 ] ) }
                        let greenStatistics     = Benchmark.run( label: "Statistics (G)"  ) { SwiftPixel.HistogramStatistics( data: rgbHistogram.data[ 1 ] ) }
                        let blueStatistics      = Benchmark.run( label: "Statistics (B)"  ) { SwiftPixel.HistogramStatistics( data: rgbHistogram.data[ 2 ] ) }
                        let luminanceStatistics = Benchmark.run( label: "Statistics (L)"  ) { SwiftPixel.HistogramStatistics( data: luminanceHistogram.data[ 0 ] ) }
                        let histogram           = Histogram( rgb: rgbHistogram, luminance: luminanceHistogram )
                        let statistics          = HistogramStatistics(
                            red:       redStatistics,
                            green:     greenStatistics,
                            blue:      blueStatistics,
                            luminance: luminanceStatistics
                        )

                        let result = Result(
                            image: render.image,
                            bytes: render.bytes,
                            histogram: histogram,
                            statistics: statistics
                        )

                        continuation.resume( returning: result )
                    }
                    catch
                    {
                        continuation.resume( throwing: error )
                    }
                }
            }

            await MainActor.run
            {
                self.result = result
                self.error  = nil
            }
        }
        catch
        {
            self.result = nil
            self.error  = error
        }
    }
}
