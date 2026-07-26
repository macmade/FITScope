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
import SwiftAstro
import SwiftPixel
import SwiftXISF
import Testing

/// Tests for `XISFPreviewRenderer` and the `PreviewRenderer` dispatcher — the
/// default-settings renderers the QuickLook thumbnail and preview extensions use to
/// turn an XISF file into a display-ready `CGImage`.
@Suite( "XISFPreviewRenderer" )
struct XISFPreviewRendererTests
{
    /// A valid XISF file renders to an image at its geometry, from a URL.
    @Test
    func rendersAValidXISFFileToAnImage() throws
    {
        let image = try XISFPreviewRenderer.render( contentsOf: TestFixtures.xisfImage )

        #expect( image.width == 8 )
        #expect( image.height == 8 )
    }

    /// It renders from raw bytes too.
    @Test
    func rendersFromRawXISFData() throws
    {
        let data  = try Data( contentsOf: TestFixtures.xisfImage )
        let image = try XISFPreviewRenderer.render( data: data )

        #expect( image.width == 8 )
        #expect( image.height == 8 )
    }

    /// A multi-image file previews its first image.
    @Test
    func previewsFirstImageOfAMultiImageFile() throws
    {
        let image = try XISFPreviewRenderer.render( contentsOf: TestFixtures.xisfMultiImage )

        #expect( image.width == 6 )
        #expect( image.height == 4 )
    }

    /// A malformed file surfaces as a thrown error.
    @Test
    func throwsForAMalformedXISFFile()
    {
        #expect( throws: ( any Swift.Error ).self )
        {
            try XISFPreviewRenderer.render( data: Data( "not an xisf file".utf8 ) )
        }
    }

    /// The shared dispatcher routes an XISF file to the XISF renderer and a FITS
    /// file to the FITS renderer, so a single extension handles both.
    @Test
    func dispatcherRoutesByFormat() throws
    {
        let xisf = try PreviewRenderer.render( contentsOf: TestFixtures.xisfImage )
        let fits = try PreviewRenderer.render( contentsOf: TestFixtures.monoImage )

        #expect( xisf.width == 8 && xisf.height == 8 )
        #expect( fits.width > 0 && fits.height > 0 )
    }

    /// An isolated shared-suite store with the XISF previews preference set to the
    /// given value, plus its name for teardown.
    private static func isolatedSuite( xisfPreviews: Bool ) -> ( defaults: UserDefaults, name: String )
    {
        let name     = "FITScopeTests.XISFPreview.\( UUID().uuidString )"
        let defaults = UserDefaults( suiteName: name ) ?? .standard

        defaults.set( xisfPreviews, forKey: AutoStretchPreference.previewsKey( .xisf ) )

        return ( defaults, name )
    }

    /// With the XISF previews preference on, an image with no display function
    /// previews with an auto Screen Transfer over identity normalization.
    @Test
    func autoStretchesWhenPreviewsPreferenceOn() throws
    {
        let ( defaults, name ) = Self.isolatedSuite( xisfPreviews: true )

        defer { defaults.removePersistentDomain( forName: name ) }

        let properties = XISFImageProperties( width: 4, height: 4, channelCount: 1, sampleFormat: .uInt16, byteOrder: .little, pixelStorage: .planar, colorSpace: .gray, colorFilterArrayPattern: nil )
        let data       = Data( XISFTestData.uInt16LE( ( 0 ..< 16 ).map { $0 * 100 } ) )
        let settings   = XISFPreviewRenderer.previewSettings( data: data, properties: properties, previewsDefaults: defaults )

        #expect( settings.stretch   != nil )
        #expect( settings.normalize == .identity )
    }

    /// A colour-filter-array XISF frame previews with a per-channel (unlinked) auto
    /// Screen Transfer — split by deinterleaving, no demosaic dependency — and matches
    /// the app: the same colour source over the same full-scale domain.
    @Test
    func autoStretchesColorFilterArrayAsPerChannelMatchingTheApp() throws
    {
        let ( defaults, name ) = Self.isolatedSuite( xisfPreviews: true )

        defer { defaults.removePersistentDomain( forName: name ) }

        let properties = XISFImageProperties( width: 4, height: 4, channelCount: 1, sampleFormat: .uInt16, byteOrder: .little, pixelStorage: .planar, colorSpace: .gray, colorFilterArrayPattern: "RGGB" )
        let data       = Data( XISFTestData.uInt16LE( ( 0 ..< 16 ).map { $0 * 100 } ) )
        let settings   = XISFPreviewRenderer.previewSettings( data: data, properties: properties, previewsDefaults: defaults )

        #expect( settings.normalize == .identity )

        guard case .perChannel = try #require( settings.stretch )
        else
        {
            Issue.record( "a CFA XISF frame must preview with a per-channel Screen Transfer" )

            return
        }

        let fullScale   = try #require( XISFImageDecoder.fullScale( from: properties ) )
        let colorSource = try #require( ImageProcessor.xisfAutoStretchColorSource( data: data, properties: properties ) )
        let app         = try #require( ImageProcessor.autoStretchSettings( colorSource: colorSource, fullScale: fullScale ) )

        #expect( settings.stretch == app.stretch )
    }

    /// Decode-once must not change the result: deriving the preview settings from the
    /// image's already-decoded planes matches deriving them from the raw bytes.
    @Test
    func decodeOnceSettingsMatchTheBytePath() throws
    {
        let ( defaults, name ) = Self.isolatedSuite( xisfPreviews: true )

        defer { defaults.removePersistentDomain( forName: name ) }

        let properties = XISFImageProperties( width: 4, height: 4, channelCount: 1, sampleFormat: .uInt16, byteOrder: .little, pixelStorage: .planar, colorSpace: .gray, colorFilterArrayPattern: "RGGB" )
        let data       = Data( XISFTestData.uInt16LE( ( 0 ..< 16 ).map { $0 * 100 } ) )
        let planes     = try XISFImageDecoder.planeSamples( bytes: data, properties: properties )
        let frame      = XISFDecodedRenderSource( planes: planes, properties: properties )

        let bytePath    = XISFPreviewRenderer.previewSettings( data: data, properties: properties, previewsDefaults: defaults )
        let decodedPath = XISFPreviewRenderer.previewSettings( frame: frame, previewsDefaults: defaults )

        #expect( decodedPath.stretch   == bytePath.stretch )
        #expect( decodedPath.normalize == bytePath.normalize )
    }

    /// With the XISF previews preference off, an image with no display function
    /// previews linear (min/max), with no stretch.
    @Test
    func rendersLinearWhenPreviewsPreferenceOff() throws
    {
        let ( defaults, name ) = Self.isolatedSuite( xisfPreviews: false )

        defer { defaults.removePersistentDomain( forName: name ) }

        let properties = XISFImageProperties( width: 4, height: 4, channelCount: 1, sampleFormat: .uInt16, byteOrder: .little, pixelStorage: .planar, colorSpace: .gray, colorFilterArrayPattern: nil )
        let data       = Data( XISFTestData.uInt16LE( ( 0 ..< 16 ).map { $0 * 100 } ) )
        let settings   = XISFPreviewRenderer.previewSettings( data: data, properties: properties, previewsDefaults: defaults )

        #expect( settings.stretch   == nil )
        #expect( settings.normalize == .minMax )
    }

    /// A stored display function always applies to the preview — even with the
    /// previews preference off — mirroring the app's "display function as authored"
    /// rule on open.
    @Test
    func displayFunctionAppliesRegardlessOfPreviewsPreference() throws
    {
        let ( defaults, name ) = Self.isolatedSuite( xisfPreviews: false )

        defer { defaults.removePersistentDomain( forName: name ) }

        let hex        = XISFTestData.hex( XISFTestData.uInt16LE( Array( 0 ..< 16 ).map { $0 * 10 } ) )
        let image      = XISFTestData.Image( geometry: "4:4:1", sampleFormat: "UInt16", colorSpace: "Gray", displayFunction: ( m: "0.25:0.25:0.25:0.25", s: "0.1:0.1:0.1:0.1", h: "0.9:0.9:0.9:0.9", l: "0:0:0:0", r: "1:1:1:1" ), hexData: hex )
        let file       = try XISFFile( data: XISFTestData.file( images: [ image ] ), options: .lenient )
        let xisfImage  = try #require( file.images.first )
        let properties = XISFImageProperties( image: xisfImage )
        let settings   = XISFPreviewRenderer.previewSettings( data: try xisfImage.data, properties: properties, previewsDefaults: defaults )
        let expected   = Processors.Stretch.STFParameters.uniform( .init( shadows: 0.1, midtones: 0.25, highlights: 0.9, low: 0, high: 1 ) )

        #expect( settings.stretch   == expected )
        #expect( settings.normalize == .identity )
    }
}
