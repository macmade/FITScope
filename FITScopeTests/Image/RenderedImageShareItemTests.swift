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

import CoreGraphics
@testable import FITScope
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

/// Tests for `RenderedImageShareItem`: the payload handed to the system share
/// menu is a ~90%-quality JPEG of the rendered image, and the suggested file
/// name carries the `.jpg` extension.
@Suite( "RenderedImageShareItem" )
struct RenderedImageShareItemTests
{
    @Test
    func sharePayloadIsANinetyPercentJPEG() throws
    {
        let image    = Self.makeImage( width: 32, height: 24 )
        let item     = RenderedImageShareItem( image: image, name: "M42" )
        let payload  = try item.jpegData()
        let expected = try ImageExporter.data( for: image, format: .jpeg( quality: 0.9 ) )

        #expect( payload == expected, "the share payload must be a 90%-quality JPEG" )
    }

    @Test
    func sharePayloadIsAReadableJPEGOfTheSourceSize() throws
    {
        let width   = 32
        let height  = 24
        let item    = RenderedImageShareItem( image: Self.makeImage( width: width, height: height ), name: "M42" )
        let payload = try item.jpegData()

        #expect( payload.isEmpty == false )

        let source  = try #require( CGImageSourceCreateWithData( payload as CFData, nil ), "the share payload must be a readable image source" )
        let utiName = try #require( CGImageSourceGetType( source ) as String? )

        #expect( utiName == UTType.jpeg.identifier, "the share payload must be a JPEG" )

        let decoded = try #require( CGImageSourceCreateImageAtIndex( source, 0, nil ) )

        #expect( decoded.width == width && decoded.height == height, "the shared image must keep the source dimensions" )
    }

    @Test
    func suggestedFileNameAppendsTheJPEGExtension()
    {
        let item = RenderedImageShareItem( image: Self.makeImage( width: 4, height: 4 ), name: "M42" )

        #expect( item.suggestedFileName == "M42.jpg" )
    }

    /// Builds a non-uniform RGB image so the encoded JPEG is a real, decodable
    /// image rather than a degenerate flat field.
    private static func makeImage( width: Int, height: Int ) -> CGImage
    {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context    = CGContext(
            data:             nil,
            width:            width,
            height:           height,
            bitsPerComponent: 8,
            bytesPerRow:      0,
            space:            colorSpace,
            bitmapInfo:       CGImageAlphaInfo.premultipliedLast.rawValue
        )!

        for y in 0 ..< height
        {
            for x in 0 ..< width
            {
                context.setFillColor(
                    red:   CGFloat( ( x * 7 + y * 13 ) % 256 ) / 255,
                    green: CGFloat( ( x * 3 + y * 5  ) % 256 ) / 255,
                    blue:  CGFloat( ( x ^ y          ) % 256 ) / 255,
                    alpha: 1
                )
                context.fill( CGRect( x: x, y: y, width: 1, height: 1 ) )
            }
        }

        return context.makeImage()!
    }
}
