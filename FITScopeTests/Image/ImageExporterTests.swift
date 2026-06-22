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

/// Tests for `ImageExporter`: it encodes a `CGImage` to TIFF, PNG and JPEG with
/// the requested type and dimensions, and honours the JPEG quality.
@Suite( "ImageExporter" )
struct ImageExporterTests
{
    @Test
    func encodesTIFFWithTheRightTypeAndSize() throws
    {
        try Self.expectEncodes( format: .tiff, asType: UTType.tiff )
    }

    @Test
    func encodesPNGWithTheRightTypeAndSize() throws
    {
        try Self.expectEncodes( format: .png, asType: UTType.png )
    }

    @Test
    func encodesJPEGWithTheRightTypeAndSize() throws
    {
        try Self.expectEncodes( format: .jpeg( quality: 0.9 ), asType: UTType.jpeg )
    }

    @Test
    func jpegQualityIsHonored() throws
    {
        let image = Self.makeImage( width: 128, height: 128 )
        let low   = try ImageExporter.data( for: image, format: .jpeg( quality: 0.1 ) )
        let high  = try ImageExporter.data( for: image, format: .jpeg( quality: 0.95 ) )

        #expect( low.isEmpty == false && high.isEmpty == false )
        #expect( low.count < high.count, "a lower JPEG quality must produce a smaller file" )
    }

    @Test
    func writesAFileToDisk() throws
    {
        let image = Self.makeImage( width: 16, height: 16 )
        let url   = URL( fileURLWithPath: NSTemporaryDirectory() ).appendingPathComponent( "FITScopeExportTest-\( UUID().uuidString ).png" )

        defer { try? FileManager.default.removeItem( at: url ) }

        try ImageExporter.write( image, format: .png, to: url )

        #expect( FileManager.default.fileExists( atPath: url.path ) )
        #expect( ( try Data( contentsOf: url ) ).isEmpty == false )
    }

    /// Encodes the image in the given format and asserts the produced data is a
    /// readable image of the expected type and original dimensions.
    private static func expectEncodes( format: ImageExporter.Format, asType type: UTType ) throws
    {
        let width  = 24
        let height = 18
        let image  = self.makeImage( width: width, height: height )
        let data   = try ImageExporter.data( for: image, format: format )

        #expect( data.isEmpty == false )

        let source  = try #require( CGImageSourceCreateWithData( data as CFData, nil ), "the exported data must be a readable image source" )
        let utiName = try #require( CGImageSourceGetType( source ) as String? )

        #expect( utiName == type.identifier, "the exported file must be of the requested type" )

        let decoded = try #require( CGImageSourceCreateImageAtIndex( source, 0, nil ) )

        #expect( decoded.width == width && decoded.height == height, "the exported image must keep the source dimensions" )
    }

    /// Builds a non-uniform RGB image so that JPEG quality measurably affects the
    /// encoded size (a flat image compresses to nearly the same size at any
    /// quality).
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
