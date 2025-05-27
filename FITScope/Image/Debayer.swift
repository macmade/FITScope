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

public enum Debayer
{
    public enum Pattern: Sendable
    {
        case bggr
        case rgbg
        case grbg
        case rggb
    }

    public enum ColorType: Sendable
    {
        case red
        case green
        case blue
    }

    public static func vng( pixels: [ Double ], pattern: Pattern, width: Int, height: Int ) throws -> [ Double ]
    {
        guard pixels.count == width * height
        else
        {
            throw RuntimeError( message: "Data size does not match expected size: \( pixels.count ) != \( width * height )")
        }

        let colorMap = self.colorMap( width: width, height: height, pattern: pattern )
        var output   = [ Double ]( repeating: 0.0, count: width * height * 3 )

        try pixels.withUnsafeBufferPointer
        {
            guard let baseAddress = $0.baseAddress
            else
            {
                throw RuntimeError( message: "Failed to access input data buffer" )
            }
            
            let input = UnsafeSendable( baseAddress )
            
            try output.withUnsafeMutableBufferPointer
            {
                guard let baseAddress = $0.baseAddress
                else
                {
                    throw RuntimeError( message: "Failed to access output data buffer" )
                }
                
                let output = UnsafeSendable( baseAddress )

                DispatchQueue.concurrentPerform( iterations: height )
                {
                    y in ( 0 ..< width ).forEach
                    {
                        x in
                        
                        let i         = index( x: x, y: y, width: width )
                        let val       = input.value[ i ]
                        let colorType = colorMap[ i ]
                        
                        var r = 0.0
                        var g = 0.0
                        var b = 0.0
                        
                        switch colorType
                        {
                            case .red:
                                
                                r = val
                                g = self.averageSIMD( values:
                                    [
                                        self.safeRead( x: x - 1, y: y,     width: width, height: height, data: input.value ),
                                        self.safeRead( x: x + 1, y: y,     width: width, height: height, data: input.value ),
                                        self.safeRead( x: x,     y: y - 1, width: width, height: height, data: input.value ),
                                        self.safeRead( x: x,     y: y + 1, width: width, height: height, data: input.value ),
                                    ]
                                )
                                b = self.averageSIMD( values:
                                    [
                                        self.safeRead( x: x - 1, y: y - 1, width: width, height: height, data: input.value ),
                                        self.safeRead( x: x + 1, y: y - 1, width: width, height: height, data: input.value ),
                                        self.safeRead( x: x - 1, y: y + 1, width: width, height: height, data: input.value ),
                                        self.safeRead( x: x + 1, y: y + 1, width: width, height: height, data: input.value ),
                                    ]
                                )

                            case .green:
                                
                                let left  = self.colorAt( x: x - 1, y: y, pattern: pattern )
                                let right = self.colorAt( x: x + 1, y: y, pattern: pattern )

                                if left == .red || right == .red
                                {
                                    r = self.averageSIMD( values:
                                        [
                                            self.safeRead( x: x - 1, y: y, width: width, height: height, data: input.value ),
                                            self.safeRead( x: x + 1, y: y, width: width, height: height, data: input.value ),
                                        ]
                                    )
                                    g = val
                                    b = self.averageSIMD( values:
                                        [
                                            self.safeRead( x: x, y: y - 1, width: width, height: height, data: input.value ),
                                            self.safeRead( x: x, y: y + 1, width: width, height: height, data: input.value ),
                                        ]
                                    )
                                }
                                else
                                {
                                    r = self.averageSIMD( values:
                                        [
                                            self.safeRead( x: x, y: y - 1, width: width, height: height, data: input.value ),
                                            self.safeRead( x: x, y: y + 1, width: width, height: height, data: input.value ),
                                        ]
                                    )
                                    g = val
                                    b = self.averageSIMD( values:
                                        [
                                            self.safeRead( x: x - 1, y: y, width: width, height: height, data: input.value ),
                                            self.safeRead( x: x + 1, y: y, width: width, height: height, data: input.value ),
                                        ]
                                    )
                                }

                            case .blue:
                                
                                r = self.averageSIMD( values:
                                    [
                                        self.safeRead( x: x - 1, y: y - 1, width: width, height: height, data: input.value ),
                                        self.safeRead( x: x + 1, y: y - 1, width: width, height: height, data: input.value ),
                                        self.safeRead( x: x - 1, y: y + 1, width: width, height: height, data: input.value ),
                                        self.safeRead( x: x + 1, y: y + 1, width: width, height: height, data: input.value ),
                                    ]
                                )
                                g = self.averageSIMD( values:
                                    [
                                        self.safeRead( x: x - 1, y: y,     width: width, height: height, data: input.value ),
                                        self.safeRead( x: x + 1, y: y,     width: width, height: height, data: input.value ),
                                        self.safeRead( x: x,     y: y - 1, width: width, height: height, data: input.value ),
                                        self.safeRead( x: x,     y: y + 1, width: width, height: height, data: input.value ),
                                    ]
                                )
                                b = val
                        }

                        let index                 = i * 3
                        output.value[ index + 0 ] = r
                        output.value[ index + 1 ] = g
                        output.value[ index + 2 ] = b
                    }
                }
            }
        }

        return output
    }

    private static func index( x: Int, y: Int, width: Int ) -> Int
    {
        return y * width + x
    }
    
    private static func colorMap( width: Int, height: Int, pattern: Pattern ) -> [ ColorType ]
    {
        var map = [ ColorType ]( repeating: .red, count: width * height )

        ( 0 ..< height ).forEach
        {
            y in ( 0 ..< width ).forEach
            {
                x in map[ self.index( x: x, y: y, width: width ) ] = self.colorAt( x: x, y: y, pattern: pattern )
            }
        }

        return map
    }

    private static func colorAt( x: Int, y: Int, pattern: Pattern ) -> ColorType
    {
        let evenCol = x % 2 == 0
        let evenRow = y % 2 == 0

        switch pattern
        {
            case .bggr: switch ( evenRow, evenCol )
            {
                case ( true,  true  ): return .blue
                case ( true,  false ): return .green
                case ( false, true  ): return .green
                case ( false, false ): return .red
            }

            case .rggb, .rgbg: switch ( evenRow, evenCol )
            {
                case ( true,  true  ): return .red
                case ( true,  false ): return .green
                case ( false, true  ): return .green
                case ( false, false ): return .blue
            }

            case .grbg: switch ( evenRow, evenCol )
            {
                case ( true,  false ): return .red
                case ( true,  true  ): return .green
                case ( false, false ): return .green
                case ( false, true  ): return .blue
            }
        }
    }

    private static func safeRead( x: Int, y: Int, width: Int, height: Int, data: UnsafePointer< Double > ) -> Double
    {
        let clampedX = min( max( x, 0 ), width  - 1 )
        let clampedY = min( max( y, 0 ), height - 1 )
        
        return data[ self.index( x: clampedX, y: clampedY, width: width ) ]
    }

    private static func averageSIMD( values: [ Double ] ) -> Double
    {
        var result = 0.0
        
        vDSP_meanvD( values, 1, &result, vDSP_Length( values.count ) )
        
        return result
    }
}
