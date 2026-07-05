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

/// Tests for `ExternalImageFile`: it names a temporary TIFF after the source
/// file, writes the rendered image to it losslessly, and clears the previous
/// temporary image on the next write so they do not accumulate.
@Suite( "ExternalImageFile" )
struct ExternalImageFileTests
{
    @Test
    func namesTheTempFileAfterTheSourceWithATIFFExtension()
    {
        #expect( ExternalImageFile.fileName( forSource: "M31.fits" ) == "M31.tiff" )
        #expect( ExternalImageFile.fileName( forSource: "andromeda" ) == "andromeda.tiff" )
    }

    @Test
    func fallsBackToAGenericNameWhenTheSourceHasNoBaseName()
    {
        #expect( ExternalImageFile.fileName( forSource: "" ) == "Image.tiff" )
    }

    @Test
    func writesALosslessTIFFNamedAfterTheSource() throws
    {
        let parent = Self.makeUniqueDirectory()

        defer { try? FileManager.default.removeItem( at: parent ) }

        let image = Self.makeImage( width: 20, height: 12 )
        let url   = try ExternalImageFile.write( image, sourceName: "M31.fits", in: parent )

        #expect( url.lastPathComponent == "M31.tiff" )
        #expect( FileManager.default.fileExists( atPath: url.path ) )

        let source  = try #require( CGImageSourceCreateWithURL( url as CFURL, nil ), "the temp file must be a readable image" )
        let utiName = try #require( CGImageSourceGetType( source ) as String? )

        #expect( utiName == UTType.tiff.identifier, "the temp file must be a TIFF" )

        let decoded = try #require( CGImageSourceCreateImageAtIndex( source, 0, nil ) )

        #expect( decoded.width == 20 && decoded.height == 12, "the temp file must keep the source dimensions" )
    }

    @Test
    func writingAgainReplacesThePreviousTempImage() throws
    {
        let parent = Self.makeUniqueDirectory()

        defer { try? FileManager.default.removeItem( at: parent ) }

        let image = Self.makeImage( width: 8, height: 8 )
        let first = try ExternalImageFile.write( image, sourceName: "first.fits", in: parent )

        #expect( FileManager.default.fileExists( atPath: first.path ) )

        let second = try ExternalImageFile.write( image, sourceName: "second.fits", in: parent )

        #expect( FileManager.default.fileExists( atPath: second.path ) )
        #expect( FileManager.default.fileExists( atPath: first.path ) == false, "the previous temp image is cleaned up" )
    }

    @Test
    func removeTemporaryFilesDeletesTheExports() throws
    {
        let parent = Self.makeUniqueDirectory()

        defer { try? FileManager.default.removeItem( at: parent ) }

        let image = Self.makeImage( width: 8, height: 8 )
        let url   = try ExternalImageFile.write( image, sourceName: "M31.fits", in: parent )

        #expect( FileManager.default.fileExists( atPath: url.path ) )

        ExternalImageFile.removeTemporaryFiles( in: parent )

        #expect( FileManager.default.fileExists( atPath: url.path ) == false, "cleanup removes the exported temp file so nothing lingers" )
    }

    @Test
    func removeTemporaryFilesIsSafeWhenNothingWasWritten()
    {
        let parent = Self.makeUniqueDirectory()

        defer { try? FileManager.default.removeItem( at: parent ) }

        // Must not throw or fail when there is nothing to clean up.
        ExternalImageFile.removeTemporaryFiles( in: parent )
    }

    /// Creates a unique, empty directory under the system temporary directory to
    /// act as the injected parent, so each test is isolated.
    private static func makeUniqueDirectory() -> URL
    {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent( "ExternalImageFileTests-\( UUID().uuidString )", isDirectory: true )

        try? FileManager.default.createDirectory( at: url, withIntermediateDirectories: true )

        return url
    }

    /// Builds a small opaque RGB image for the write tests.
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

        context.setFillColor( red: 0.2, green: 0.4, blue: 0.6, alpha: 1 )
        context.fill( CGRect( x: 0, y: 0, width: width, height: height ) )

        return context.makeImage()!
    }
}
