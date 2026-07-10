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

@testable import FITScope
import Foundation
import Testing

/// Tests that `ImageIOImageLoader` opens photographic files — PNG, TIFF and JPEG —
/// into the format-neutral image layer: decoding to the normalized representation,
/// opening as authored (identity baseline), and mapping EXIF/GPS metadata.
@Suite( "ImageIOImageLoader" )
struct ImageIOImageLoaderTests
{
    /// A PNG loads as a single colour frame, decodes the correct top-left pixel (so a
    /// vertical flip would be caught), and opens on the as-authored baseline.
    @Test
    @MainActor
    func loadsPNGAsAuthoredColor() async throws
    {
        let loader = ImageIOImageLoader( url: TestFixtures.photoRGB )

        await loader.load()

        let image = try #require( loader.image )

        #expect( loader.error == nil )
        #expect( loader.frames.count == 1 )
        #expect( image.isColor )
        #expect( image.isColorFilterArray == false )
        #expect( image.graph == nil )

        // The fixture's top-left pixel is (10, 20, 100); reading it back proves the
        // decode is not vertically flipped.
        let source   = try image.renderer.renderSourceSnapshot()
        let topLeft  = try #require( source.pixelValues( atX: 0, y: 0 ) )

        #expect( topLeft.map { $0.value } == [ 10, 20, 100 ] )

        let result = try source.makeResult( settings: image.renderer.adjustments.baseline )

        #expect( result.inputPixelFormat == .rgb )
        #expect( result.image.width == 4 )
        #expect( result.image.height == 3 )

        // Opened as authored: the identity-normalized baseline reproduces the stored
        // pixel exactly, and the image is not marked as edited.
        #expect( image.renderer.adjustments.baseline.normalize == .identity )
        #expect( image.renderer.adjustments.hasAdjustments == false )
        #expect( Array( result.bytes.prefix( 3 ) ) == [ 10, 20, 100 ] )
    }

    /// A 16-bit grayscale TIFF loads as a monochrome frame decoded at full precision.
    @Test
    @MainActor
    func loads16BitGrayscaleTIFF() async throws
    {
        let loader = ImageIOImageLoader( url: TestFixtures.photoGray16 )

        await loader.load()

        let image = try #require( loader.image )

        #expect( image.isColor == false )

        let source = try image.renderer.renderSourceSnapshot()

        // The fixture's (0,0) is 0 and (1,0) is 4000 — a 16-bit value whose fraction
        // is against the 16-bit full scale, confirming the depth was preserved.
        let origin = try #require( source.pixelValues( atX: 0, y: 0 ) )
        let next   = try #require( source.pixelValues( atX: 1, y: 0 ) )

        #expect( origin.map { $0.value } == [ 0 ] )
        #expect( next.map { $0.value } == [ 4000 ] )
        #expect( next[ 0 ].fraction == 4000.0 / 65535.0 )

        let result = try source.makeResult( settings: image.renderer.adjustments.baseline )

        #expect( result.inputPixelFormat == .mono )
    }

    /// A JPEG with EXIF/GPS loads with its capture date, exposure, observing-site
    /// coordinate and camera metadata mapped through the neutral model.
    @Test
    @MainActor
    func loadsJPEGWithMetadata() async throws
    {
        let loader = ImageIOImageLoader( url: TestFixtures.photoExif )

        await loader.load()

        let image = try #require( loader.image )

        #expect( image.observationDate != nil )
        #expect( image.exposureTime == 0.5 )
        #expect( image.wcs == nil )
        #expect( image.pixelScale == nil )

        // The GPS location comes through as the observing-site coordinate, S/E-signed.
        let coordinate = try #require( image.coordinate )

        #expect( coordinate.latitude < 0 )
        #expect( coordinate.longitude > 0 )

        // The Info window's metadata carries the EXIF and GPS sections.
        let titles = image.metadata.sections.map { $0.title }

        #expect( titles.contains( "EXIF" ) )
        #expect( titles.contains( "GPS" ) )

        // The summary carries the camera model.
        let information = try #require( image.information )

        #expect( information.rows.contains { $0.field == .instrument && $0.value == "TestCam 1" } )
    }

    /// Undecodable bytes fail the load and surface an error, with no image.
    @Test
    @MainActor
    func undecodableDataFails() async throws
    {
        let loader = ImageIOImageLoader( url: URL( fileURLWithPath: "/tmp/broken.png" ), data: Data( [ 0, 1, 2, 3, 4, 5 ] ) )

        await loader.load()

        #expect( loader.image == nil )
        #expect( loader.frames.isEmpty )
        #expect( loader.error != nil )
    }

    /// The loader factory routes the photographic types to the ImageIO loader.
    @Test
    @MainActor
    func factoryRoutesPhotographicTypes()
    {
        #expect( ImageLoader.loader( for: URL( fileURLWithPath: "/tmp/a.png" ) )  is ImageIOImageLoader )
        #expect( ImageLoader.loader( for: URL( fileURLWithPath: "/tmp/a.tiff" ) ) is ImageIOImageLoader )
        #expect( ImageLoader.loader( for: URL( fileURLWithPath: "/tmp/a.jpg" ) )  is ImageIOImageLoader )
    }

    /// The decode applies the image's EXIF orientation: a `4 × 2` fixture tagged
    /// orientation 6 (rotate 90° clockwise), with its stored top-left pixel white,
    /// uprights to `2 × 4` with the white pixel at the top-right.
    @Test
    @MainActor
    func appliesExifOrientation() async throws
    {
        let loader = ImageIOImageLoader( url: TestFixtures.orientedPhoto )

        await loader.load()

        let image  = try #require( loader.image )
        let source = try image.renderer.renderSourceSnapshot()

        // Uprighting swaps the stored 4 × 2 to a displayed 2 × 4.
        let dimensions = try #require( source.dimensions )

        #expect( dimensions.width == 2 )
        #expect( dimensions.height == 4 )

        // The stored top-left white pixel rotates to the displayed top-right.
        let topLeft  = try #require( source.pixelValues( atX: 0, y: 0 ) )
        let topRight = try #require( source.pixelValues( atX: 1, y: 0 ) )

        #expect( topLeft[ 0 ].value < 60 )
        #expect( topRight[ 0 ].value > 200 )
    }
}
