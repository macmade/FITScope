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

import CoreGraphics
import Foundation
import SwiftFITS

public enum ImageRenderer
{
    public struct RenderOptions
    {
        public let bitsPerPixel: BitsPerPixel
        public let width:        Int
        public let height:       Int
        public let scale:        Double
        public let scaleOffset:  Int64
        public let bayerPattern: Debayer.Pattern?
    }

    public static func render( data: Data, properties: [ FITSProperty ] ) throws -> CGImage
    {
        guard let bitPix = properties.first( where: { $0.name == "BITPIX" } )?.value as? Int64
        else
        {
            throw RuntimeError( message: "Missing BITPIX property" )
        }

        guard let bitsPerPixel = BitsPerPixel.from( value: bitPix )
        else
        {
            throw RuntimeError( message: "Unsupported BITPIX value \( bitPix )" )
        }

        guard let nAxis = properties.first( where: { $0.name == "NAXIS" } )?.value as? Int64
        else
        {
            throw RuntimeError( message: "Missing NAXIS property" )
        }

        guard nAxis == 2
        else
        {
            throw RuntimeError( message: "Unsupported NAXIS value \( nAxis )" )
        }

        guard let nAxis1 = properties.first( where: { $0.name == "NAXIS1" } )?.value as? Int64
        else
        {
            throw RuntimeError( message: "Missing NAXIS1 property" )
        }

        guard let width = Int( exactly: nAxis1 )
        else
        {
            throw RuntimeError( message: "Invalid NAXIS1 value \( nAxis1 )" )
        }

        guard let nAxis2 = properties.first( where: { $0.name == "NAXIS2" } )?.value as? Int64
        else
        {
            throw RuntimeError( message: "Missing NAXIS2 property" )
        }

        guard let height = Int( exactly: nAxis2 )
        else
        {
            throw RuntimeError( message: "Invalid NAXIS1 value \( nAxis1 )" )
        }

        let size = bitsPerPixel.size( numberOfPixels: width * height )

        guard data.count == size
        else
        {
            throw RuntimeError( message: "Data size does not match expected size: \( data.count ) != \( size )" )
        }

        let bayerPattern: Debayer.Pattern? = if let pattern = properties.first( where: { $0.name == "BAYERPAT" } )?.value as? String
        {
            switch pattern
            {
                case "BGGR": .bggr
                case "RGBG": .rgbg
                case "GRBG": .grbg
                case "RGGB": .rggb
                default:     throw RuntimeError( message: "Unsupported BAYERPAT value \( pattern )" )
            }
        }
        else
        {
            nil
        }

        let offset: Int64 = if let bZero = properties.first( where: { $0.name == "BZERO" } )?.value as? Int64
        {
            bZero
        }
        else
        {
            0
        }

        let scale: Double = if let bScale = properties.first( where: { $0.name == "BSCALE" } )?.value as? Int64
        {
            Double( bScale )
        }
        else
        {
            1
        }

        let options = RenderOptions(
            bitsPerPixel: bitsPerPixel,
            width:        width,
            height:       height,
            scale:        scale,
            scaleOffset:  offset,
            bayerPattern: bayerPattern
        )

        return try Benchmark.run( label: "Rendering Image" )
        {
            try self.render( data: data, options: options )
        }
    }

    public static func render( data: Data, options: RenderOptions ) throws -> CGImage
    {
        let pixels = try PixelPipeline(
            data:         data,
            width:        options.width,
            height:       options.height,
            bitsPerPixel: options.bitsPerPixel,
            options:      .useAccelerate
        )
        .scale( scale: options.scale, offset: options.scaleOffset )
        .debayerOrConvertToRGBTriplets( pattern: options.bayerPattern )
        .normalized()

        guard let provider = CGDataProvider( data: Data( pixels ) as CFData )
        else
        {
            throw RuntimeError( message: "Unable to create a data provider" )
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo( rawValue: CGImageAlphaInfo.none.rawValue )
        let cgImage    = CGImage(
            width:             options.width,
            height:            options.height,
            bitsPerComponent:  8,
            bitsPerPixel:      24,
            bytesPerRow:       options.width * 3,
            space:             colorSpace,
            bitmapInfo:        bitmapInfo,
            provider:          provider,
            decode:            nil,
            shouldInterpolate: false,
            intent:            .defaultIntent
        )

        guard let cgImage
        else
        {
            throw RuntimeError( message: "Unable to create a CGImage" )
        }

        return cgImage
    }
}
