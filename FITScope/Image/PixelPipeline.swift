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
import SwiftUtilities

public class PixelPipeline
{
    public struct Options: OptionSet, Sendable
    {
        public let rawValue: Int

        public init( rawValue: Int )
        {
            self.rawValue = rawValue
        }

        public static let useAccelerate = Options( rawValue: 1 << 0 )
    }

    private var pixels:  [ Double ]
    private let width:   Int
    private let height:  Int
    private let options: Options

    public init( data: Data, width: Int, height: Int, bitsPerPixel: BitsPerPixel, options: Options ) throws
    {
        self.width   = width
        self.height  = height
        self.options = options
        self.pixels  = try Benchmark.run( label: "Reading Raw Pixels" )
        {
            try PixelUtilities.readRawPixels( data: data, width: width, height: height, bitsPerPixel: bitsPerPixel )
        }
    }

    @discardableResult
    public func scale( scale: Double, offset: Int64 ) throws -> Self
    {
        try Benchmark.run( label: "Scaling Pixels" )
        {
            try self.pixels.withUnsafeMutableBufferPointer
            {
                if self.options.contains( .useAccelerate )
                {
                    try PixelUtilities.Accelerate.scale( pixels: $0, scale: scale, offset: offset )
                }
                else
                {
                    PixelUtilities.scale( pixels: $0, scale: scale, offset: offset )
                }
            }
        }

        return self
    }

    @discardableResult
    public func debayerOrConvertToRGBTriplets( pattern: Debayer.Pattern? ) throws -> Self
    {
        if let pattern
        {
            return try self.debayer( pattern: pattern )
        }

        return self.convertToRGBTriplets()
    }

    @discardableResult
    public func debayer( pattern: Debayer.Pattern ) throws -> Self
    {
        try Benchmark.run( label: "Debayering Pixels (VNG)" )
        {
            self.pixels = try Debayer.vng( pixels: self.pixels, pattern: pattern, width: self.width, height: self.height )
        }

        return self
    }

    @discardableResult
    public func convertToRGBTriplets() -> Self
    {
        Benchmark.run( label: "Converting Pixels to RGB Triplets" )
        {
            self.pixels = PixelUtilities.convertToRGBTriplets( pixels: self.pixels )
        }

        return self
    }

    public func normalized() throws -> [ UInt8 ]
    {
        try Benchmark.run( label: "Normalizing Pixels" )
        {
            if self.options.contains( .useAccelerate )
            {
                return try PixelUtilities.Accelerate.normalize( pixels: self.pixels )
            }
            else
            {
                return PixelUtilities.normalize( pixels: self.pixels )
            }
        }
    }

    public func unnormalized() -> [ Double ]
    {
        self.pixels
    }
}
