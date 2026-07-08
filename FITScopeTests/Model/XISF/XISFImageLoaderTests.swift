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

/// Tests that `XISFImageLoader` opens XISF files — grayscale, RGB, CFA and
/// multi-image — into the format-neutral image layer, mapping metadata and the
/// embedded FITS keywords through the shared astrometry path.
@Suite( "XISFImageLoader" )
struct XISFImageLoaderTests
{
    /// The URL used for the synthesized in-memory files.
    private let url = URL( fileURLWithPath: "/tmp/test.xisf" )

    /// A single grayscale image loads as one monochrome frame and renders as mono.
    @Test
    @MainActor
    func loadsGrayscaleImage() async throws
    {
        let data   = XISFTestData.file( images: [ Self.grayscale( width: 2, height: 2 ) ] )
        let loader = XISFImageLoader( url: self.url, data: data )

        await loader.load()

        let image = try #require( loader.image )

        #expect( loader.error == nil )
        #expect( loader.frames.count == 1 )
        #expect( image.graph == nil )
        #expect( image.isColor == false )
        #expect( image.isColorFilterArray == false )

        let result = try image.renderer.renderSourceSnapshot().makeResult( settings: ImageProcessor.Settings() )

        #expect( result.inputPixelFormat == .mono )
        #expect( result.image.width == 2 )
        #expect( result.image.height == 2 )
    }

    /// A three-channel RGB image loads as a single colour frame.
    @Test
    @MainActor
    func loadsRGBImageAsColor() async throws
    {
        let planes = XISFTestData.hex( XISFTestData.uInt16LE( [ 1, 2, 3, 4 ] + [ 10, 20, 30, 40 ] + [ 100, 200, 300, 400 ] ) )
        let image  = XISFTestData.Image( geometry: "2:2:3", sampleFormat: "UInt16", colorSpace: "RGB", hexData: planes )
        let loader = XISFImageLoader( url: self.url, data: XISFTestData.file( images: [ image ] ) )

        await loader.load()

        let loaded = try #require( loader.image )

        #expect( loaded.isColor )
        #expect( loaded.isColorFilterArray == false )

        let result = try loaded.renderer.renderSourceSnapshot().makeResult( settings: ImageProcessor.Settings() )

        #expect( result.inputPixelFormat == .rgb )
    }

    /// A colour-filter-array grayscale image reports as CFA (offering the debayer
    /// controls) and as colour.
    @Test
    @MainActor
    func loadsColorFilterArrayImage() async throws
    {
        let hex    = XISFTestData.hex( XISFTestData.uInt16LE( Array( 0 ..< 16 ).map { $0 * 100 } ) )
        let image  = XISFTestData.Image( geometry: "4:4:1", sampleFormat: "UInt16", colorSpace: "Gray", cfaPattern: "RGGB", hexData: hex )
        let loader = XISFImageLoader( url: self.url, data: XISFTestData.file( images: [ image ] ) )

        await loader.load()

        let loaded = try #require( loader.image )

        #expect( loaded.isColorFilterArray )
        #expect( loaded.isColor )

        // The detection image is a demosaiced luminance channel (built via
        // BayerGrayscaleConverter, as the FITS path does), not the raw mosaic:
        // present, single-channel, at the image geometry.
        let detection = try #require( loaded.renderer.renderSourceSnapshot().detectionImage )

        #expect( detection.channels == 1 )
        #expect( detection.width == 4 )
        #expect( detection.height == 4 )
    }

    /// A multi-image file loads one frame per contained image, surfaced in order.
    @Test
    @MainActor
    func loadsMultipleImagesAsFrames() async throws
    {
        let data   = XISFTestData.file( images: [ Self.grayscale( width: 2, height: 2 ), Self.grayscale( width: 3, height: 2 ), Self.grayscale( width: 4, height: 4 ) ] )
        let loader = XISFImageLoader( url: self.url, data: data )

        await loader.load()

        #expect( loader.frames.count == 3 )
        #expect( loader.image === loader.frames.first )

        let second = try #require( loader.frames.dropFirst().first )
        let result = try second.renderer.renderSourceSnapshot().makeResult( settings: ImageProcessor.Settings() )

        #expect( result.image.width == 3 )
    }

    /// The embedded FITS keywords flow through the shared `FITSMetadata` path, so an
    /// XISF image that carries them gets the same astrometry fields as a FITS file.
    @Test
    @MainActor
    func mapsEmbeddedFITSKeywords() async throws
    {
        let keywords: [ ( name: String, value: String, comment: String? ) ] =
            [
                ( "DATE-OBS", "2026-01-02T03:04:05", "capture" ),
                ( "EXPTIME", "12.5", "seconds" ),
                ( "CRVAL1", "10.0", nil ),
                ( "CRVAL2", "20.0", nil ),
                ( "CRPIX1", "1.0", nil ),
                ( "CRPIX2", "1.0", nil ),
                ( "CDELT1", "0.0005", nil ),
                ( "CDELT2", "0.0005", nil ),
            ]
        let hex    = XISFTestData.hex( XISFTestData.uInt16LE( [ 1, 2, 3, 4 ] ) )
        let image  = XISFTestData.Image( geometry: "2:2:1", sampleFormat: "UInt16", colorSpace: "Gray", keywords: keywords, hexData: hex )
        let loader = XISFImageLoader( url: self.url, data: XISFTestData.file( images: [ image ] ) )

        await loader.load()

        let loaded = try #require( loader.image )

        #expect( loaded.exposureTime == 12.5 )
        #expect( loaded.observationDate != nil )
        #expect( loaded.wcs != nil, "CRVAL/CRPIX keywords must yield a WCS for the overlays" )
        #expect( loaded.target != nil, "the reference RA/Dec must yield a target" )
        #expect( loaded.pixelScale != nil, "CDELT must yield a plate scale" )
        #expect( loaded.metadata.sections.contains { $0.title == "FITS Keywords" } )
        #expect( loaded.metadata.sections.contains { $0.title == "Image" } )
    }

    /// A file whose astrometry lives in FITS-quoted string cards and PixInsight-style
    /// geo keywords — exactly as the real PixInsight sample files write them — still
    /// resolves the time and location fields: the enclosing single quotes are
    /// stripped and the `OBSGEO-*` / `LAT-OBS` variants are read for the coordinate.
    @Test
    @MainActor
    func resolvesQuotedAndAlternateAstrometryKeywords() async throws
    {
        let keywords: [ ( name: String, value: String, comment: String? ) ] =
            [
                ( "OBJECT", "'M 42'", nil ),
                ( "DATE-OBS", "'2026-01-01T22:47:49.936'", nil ),
                ( "EXPTIME", "10.000", nil ),
                ( "RA", "83.78065576108365", nil ),
                ( "DEC", "-5.502081209577875", nil ),
                ( "OBSGEO-B", "46.525358", nil ),
                ( "OBSGEO-L", "6.620649", nil ),
            ]
        let hex    = XISFTestData.hex( XISFTestData.uInt16LE( [ 1, 2, 3, 4 ] ) )
        let image  = XISFTestData.Image( geometry: "2:2:1", sampleFormat: "UInt16", colorSpace: "Gray", keywords: keywords, hexData: hex )
        let loader = XISFImageLoader( url: self.url, data: XISFTestData.file( images: [ image ] ) )

        await loader.load()

        let loaded = try #require( loader.image )

        #expect( loaded.observationDate != nil, "a FITS-quoted DATE-OBS must still parse" )
        #expect( loaded.exposureTime == 10.0 )
        #expect( loaded.coordinate != nil, "OBSGEO-B / OBSGEO-L must yield the observing-site coordinate" )
        #expect( loaded.target != nil )

        // The quoted string card displays without its enclosing FITS quotes.
        let object = loaded.metadata.sections.flatMap { $0.properties }.first { $0.name == "OBJECT" }

        #expect( object?.value == "M 42" )
    }

    /// A file with no images fails the load with an error rather than an empty image.
    @Test
    @MainActor
    func emptyFileFailsWithError() async throws
    {
        let data   = XISFTestData.file( images: [] )
        let loader = XISFImageLoader( url: self.url, data: data )

        await loader.load()

        #expect( loader.image == nil )
        #expect( loader.frames.isEmpty )
        #expect( loader.error != nil )
    }

    /// An image whose declared geometry exceeds its data loads with its metadata but
    /// surfaces the error only at render, matching how a malformed FITS file degrades.
    @Test
    @MainActor
    func undecodableImageLoadsWithMetadataButErrorsAtRender() async throws
    {
        // 4×4 declared, but only three samples of data.
        let hex    = XISFTestData.hex( XISFTestData.uInt16LE( [ 1, 2, 3 ] ) )
        let image  = XISFTestData.Image( geometry: "4:4:1", sampleFormat: "UInt16", colorSpace: "Gray", hexData: hex )
        let loader = XISFImageLoader( url: self.url, data: XISFTestData.file( images: [ image ] ) )

        await loader.load()

        let loaded = try #require( loader.image, "the file must still load with its metadata" )

        #expect( loaded.metadata.sections.isEmpty == false )
        #expect( throws: ( any Error ).self )
        {
            try loaded.renderer.renderSourceSnapshot().makeResult( settings: ImageProcessor.Settings() )
        }
    }

    /// The bundled on-disk RGB XISF fixture loads end-to-end from its URL: it opens
    /// as a colour image, renders through the colour pipeline, and exposes the
    /// astrometry fields carried by its embedded FITS keywords.
    @Test
    @MainActor
    func loadsBundledRGBFixture() async throws
    {
        let loader = XISFImageLoader( url: TestFixtures.xisfImage )

        await loader.load()

        let image = try #require( loader.image )

        #expect( loader.error == nil )
        #expect( loader.frames.count == 1 )
        #expect( image.isColor )
        #expect( image.isColorFilterArray == false )
        #expect( image.wcs != nil, "the fixture carries a TAN WCS" )
        #expect( image.target != nil )
        #expect( image.exposureTime == 30.0 )
        #expect( image.observationDate != nil )

        let result = try image.renderer.renderSourceSnapshot().makeResult( settings: ImageProcessor.Settings() )

        #expect( result.inputPixelFormat == .rgb )
        #expect( result.image.width == 8 )
        #expect( result.image.height == 8 )
    }

    /// The bundled on-disk multi-image XISF fixture loads end-to-end as three
    /// distinct frames — the carousel producer path — each rendering to its own
    /// mono image and carrying its own frame title from the image `id`.
    @Test
    @MainActor
    func loadsBundledMultiImageFixture() async throws
    {
        let loader = XISFImageLoader( url: TestFixtures.xisfMultiImage )

        await loader.load()

        #expect( loader.error == nil )
        #expect( loader.frames.count == 3 )
        #expect( loader.image === loader.frames.first )

        // Each frame renders to its own 6 × 4 mono image.
        for frame in loader.frames
        {
            let result = try frame.renderer.renderSourceSnapshot().makeResult( settings: ImageProcessor.Settings() )

            #expect( result.inputPixelFormat == .mono )
            #expect( result.image.width == 6 )
            #expect( result.image.height == 4 )
        }

        // The frames carry their own titles (from each image's `id`).
        #expect( loader.frames.compactMap { $0.frameTitle } == [ "frame_1", "frame_2", "frame_3" ] )
    }

    /// A grayscale test image of the given size, filled with a simple ramp.
    private static func grayscale( width: Int, height: Int ) -> XISFTestData.Image
    {
        let hex = XISFTestData.hex( XISFTestData.uInt16LE( Array( 0 ..< ( width * height ) ).map { $0 * 10 } ) )

        return XISFTestData.Image( geometry: "\( width ):\( height ):1", sampleFormat: "UInt16", colorSpace: "Gray", hexData: hex )
    }
}
