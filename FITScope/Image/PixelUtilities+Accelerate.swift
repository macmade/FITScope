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

import Accelerate
import Foundation
import SwiftUtilities

public extension PixelUtilities
{
    enum Accelerate
    {
        public static func scale( pixels: UnsafeMutableBufferPointer< Double >, scale: Double, offset: Int64 ) throws
        {
            guard let baseAddress = pixels.baseAddress
            else
            {
                throw RuntimeError( message: "Failed to access data buffer" )
            }

            var scalar = scale
            var addend = Double( offset )

            vDSP_vsmulD( baseAddress, 1, &scalar, baseAddress, 1, vDSP_Length( pixels.count ) )
            vDSP_vsaddD( baseAddress, 1, &addend, baseAddress, 1, vDSP_Length( pixels.count ) )
        }

        public static func scale( pixels: [ Double ], scale: Double, offset: Int64 ) throws -> [ Double ]
        {
            var pixels = pixels

            try pixels.withUnsafeMutableBufferPointer
            {
                try self.scale( pixels: $0, scale: scale, offset: offset )
            }

            return pixels
        }

        public static func normalize( pixels: [ Double ] ) throws -> [ UInt8 ]
        {
            guard pixels.isEmpty == false
            else
            {
                return []
            }

            var minPixel = 0.0
            var maxPixel = 0.0
            let count    = vDSP_Length( pixels.count )

            try pixels.withUnsafeBufferPointer
            {
                guard let baseAddress = $0.baseAddress
                else
                {
                    throw RuntimeError( message: "Failed to access data buffer" )
                }

                vDSP_minvD( baseAddress, 1, &minPixel, count )
                vDSP_maxvD( baseAddress, 1, &maxPixel, count )
            }

            let range  = max( 1.0, maxPixel - minPixel )
            let scale  = 255.0 / range
            let offset = -minPixel * scale
            var buffer = [ Double ]( repeating: 0, count: pixels.count )
            var result = [ UInt8  ]( repeating: 0, count: pixels.count )

            try buffer.withUnsafeMutableBufferPointer
            {
                guard let bufferBaseAddress = $0.baseAddress
                else
                {
                    throw RuntimeError( message: "Failed to access data buffer" )
                }

                try pixels.withUnsafeBufferPointer
                {
                    guard let pixelsBaseAddress = $0.baseAddress
                    else
                    {
                        throw RuntimeError( message: "Failed to access data buffer" )
                    }

                    vDSP_vsmsaD( pixelsBaseAddress, 1, [ scale ], [ offset ], bufferBaseAddress, 1, count )

                    var lower = 0.0
                    var upper = 255.0

                    vDSP_vclipD( bufferBaseAddress, 1, &lower, &upper, bufferBaseAddress, 1, count )
                    vDSP_vfixu8D( bufferBaseAddress, 1, &result, 1, count )
                }
            }

            return result
        }
    }
}
