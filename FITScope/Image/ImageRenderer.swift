/*******************************************************************************
 * The MIT License (MIT)
 * 
 * Copyright (c) 2025 Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import Cocoa
import SwiftFITS
import CoreGraphics

public class ImageRenderer
{
    public enum BitsPerPixel
    {
        case uint8
        case int16
        case int32
        case float32
        case float64
        
        public static func from< T: BinaryInteger >( value: T ) -> BitsPerPixel?
        {
            switch value
            {
                case   8: return .uint8
                case  16: return .int16
                case  32: return .int32
                case -32: return .float32
                case -64: return .float64
                default:  return nil
            }
        }
        
        public func size( numberOfPixels: Int ) -> Int
        {
            switch self
            {
                case .uint8:   return numberOfPixels * 1
                case .int16:   return numberOfPixels * 2
                case .int32:   return numberOfPixels * 4
                case .float32: return numberOfPixels * 4
                case .float64: return numberOfPixels * 8
            }
        }
    }
    
    public struct RenderOptions
    {
        public let bitsPerPixel: BitsPerPixel
        public let width:        Int
        public let height:       Int
        public let scale:        Double
        public let scaleOffset:  Int64
        public let bayerPattern: Debayer.Pattern?
    }
    
    private init()
    {}
    
    public class func render( data: Data, properties: [ FITSProperty ] ) throws -> NSImage
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
    
    public class func render( data: Data, options: RenderOptions ) throws -> NSImage
    {
        let raw = try Benchmark.run( label: "Reading Raw Pixels" )
        {
            try self.readRawPixels( data: data, width: options.width, height: options.height, bitsPerPixel: options.bitsPerPixel )
        }
        
        let scaled = Benchmark.run( label: "Applying Scale" )
        {
            self.scale( pixels: raw, scale: options.scale, offset: options.scaleOffset )
        }

        let rgb = if let pattern = options.bayerPattern
        {
            try Benchmark.run( label: "Debayering (VNG)" )
            {
                try Debayer.vng( pattern: pattern, width: options.width, height: options.height, data: scaled )
            }
        }
        else
        {
            scaled.flatMap
            {
                [ $0, $0, $0 ]
            }
        }
        
        let normalized = Benchmark.run( label: "Normalizing Pixels" )
        {
            self.normalize( pixels: rgb )
        }
        
        guard let provider = CGDataProvider( data: Data( normalized ) as CFData )
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

        return NSImage( cgImage: cgImage, size: NSSize( width: options.width, height: options.height ) )
    }
    
    public class func readRawPixels( data: Data, width: Int, height: Int, bitsPerPixel: BitsPerPixel ) throws -> [ Double ]
    {
        let count = width * height
        let size  = bitsPerPixel.size( numberOfPixels: count )
        
        guard data.count == size
        else
        {
            throw RuntimeError( message: "Data size does not match expected size: \( data.count ) != \( size )" )
        }
        
        return switch bitsPerPixel
        {
            case .uint8: data.prefix( count ).map
            {
                Double( $0 )
            }

            case .int16: ( 0 ..< count ).map
            {
                let size   = 2
                let offset = $0 * size
                let value  = data.subdata( in: offset ..< offset + size ).withUnsafeBytes
                {
                    Int16( bigEndian: $0.load( as: Int16.self ) )
                }
                
                return Double( value )
            }

            case .int32: ( 0 ..< count ).map
            {
                let size   = 4
                let offset = $0 * size
                let value  = data.subdata( in: offset ..< offset + size ).withUnsafeBytes
                {
                    Int32( bigEndian: $0.load( as: Int32.self ) )
                }
                
                return Double( value )
            }

            case .float32: ( 0 ..< count ).map
            {
                let size   = 4
                let offset = $0 * size
                let value  = data.subdata( in: offset ..< offset + size ).withUnsafeBytes
                {
                    Float32( bitPattern: UInt32( bigEndian: $0.load( as: UInt32.self ) ) )
                }
                
                return Double( value )
            }

            case .float64: ( 0 ..< count ).map
            {
                let size   = 8
                let offset = $0 * size
                let value  = data.subdata( in: offset ..< offset + size ).withUnsafeBytes
                {
                    Float64( bitPattern: UInt64( bigEndian: $0.load( as: UInt64.self ) ) )
                }
                
                return value
            }
        }
    }
    
    public class func scale( pixels: [ Double ], scale: Double, offset: Int64 ) -> [ Double ]
    {
        pixels.map
        {
            $0 * scale + Double( offset )
        }
    }
    
    public class func normalize( pixels: [ Double ] ) -> [ UInt8 ]
    {
        let minPixel = pixels.min() ?? 0
        let maxPixel = pixels.max() ?? 1
        let range    = max( 1.0, maxPixel - minPixel )
        
        return pixels.map
        {
            UInt8( max( 0, min( 255, ( $0 - minPixel ) / range * 255.0 ) ) )
        }
    }
}
