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

import Foundation
import Accelerate

public struct PixelUtilities
{
    private init()
    {}
    
    public static func readRawPixels( data: Data, width: Int, height: Int, bitsPerPixel: BitsPerPixel ) throws -> [ Double ]
    {
        let count = width * height
        let size  = bitsPerPixel.size( numberOfPixels: count )
        
        guard data.count == size
        else
        {
            throw RuntimeError( message: "Data size does not match expected size: \( data.count ) != \( size )" )
        }
        
        return data.withUnsafeBytes
        {
            buffer in
            
            switch bitsPerPixel
            {
                case .uint8: return ( 0 ..< count ).map
                {
                    Double( buffer[ $0 ] )
                }
                
                case .int16: return ( 0 ..< count ).map
                {
                    Double( Int16( bigEndian: buffer.load( fromByteOffset: $0 * 2, as: Int16.self ) ) )
                }
                
                case .int32: return ( 0 ..< count).map
                {
                    Double( Int32( bigEndian: buffer.load( fromByteOffset: $0 * 4, as: Int32.self ) ) )
                }
                
                case .float32: return ( 0 ..< count ).map
                {
                    Double( Float32( bitPattern: UInt32( bigEndian: buffer.load( fromByteOffset: $0 * 4, as: UInt32.self ) ) ) )
                }
                
                case .float64: return ( 0 ..< count ).map
                {
                    Double( bitPattern: UInt64( bigEndian: buffer.load( fromByteOffset: $0 * 8, as: UInt64.self ) ) )
                }
            }
        }
    }
    
    public static func scale( pixels: [ Double ], scale: Double, offset: Int64 ) -> [ Double ]
    {
        pixels.map
        {
            $0 * scale + Double( offset )
        }
    }
    
    public static func scaleWithAccelerate( pixels: [ Double ], scale: Double, offset: Int64 ) -> [ Double ]
    {
        var result = [ Double ]( repeating: 0.0, count: pixels.count )
        var scalar = scale
        var addend = Double( offset )
    
        vDSP_vsmulD( pixels, 1, &scalar, &result, 1, vDSP_Length( pixels.count ) )
        vDSP_vsaddD( result, 1, &addend, &result, 1, vDSP_Length( pixels.count ) )
        
        return result
    }
    
    public static func normalize( pixels: [ Double ] ) -> [ UInt8 ]
    {
        let minPixel = pixels.min() ?? 0
        let maxPixel = pixels.max() ?? 1
        let range    = max( 1.0, maxPixel - minPixel )
        
        return pixels.map
        {
            UInt8( max( 0, min( 255, ( $0 - minPixel ) / range * 255.0 ) ) )
        }
    }
    
    public static func normalizeWithAccelerate( pixels: [ Double ] ) -> [ UInt8 ]
    {
        guard pixels.isEmpty == false
        else
        {
            return []
        }

        var minPixel = 0.0
        var maxPixel = 0.0
        
        vDSP_minvD( pixels, 1, &minPixel, vDSP_Length( pixels.count ) )
        vDSP_maxvD( pixels, 1, &maxPixel, vDSP_Length( pixels.count ) )

        let range      = max( 1.0, maxPixel - minPixel )
        let scale      = 255.0 / range
        let offset     = -minPixel * scale
        var normalized = [ Double ]( repeating: 0.0, count: pixels.count )
        
        vDSP_vsmsaD( pixels, 1, [ scale ], [ offset ], &normalized, 1, vDSP_Length( pixels.count ) )

        var clipped    = [ Double ]( repeating: 0.0, count: pixels.count )
        var lowerBound = 0.0
        var upperBound = 255.0
        
        vDSP_vclipD( normalized, 1, &lowerBound, &upperBound, &clipped, 1, vDSP_Length( pixels.count ) )

        var floatPixels = [ Float ]( repeating: 0.0, count: pixels.count )
        
        vDSP_vdpsp( clipped, 1, &floatPixels, 1, vDSP_Length( pixels.count ) )

        var result = [ UInt8 ]( repeating: 0, count: pixels.count )
        
        vDSP_vfixu8( floatPixels, 1, &result, 1, vDSP_Length( pixels.count ) )

        return result
    }
}
