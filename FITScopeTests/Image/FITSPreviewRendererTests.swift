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
import SwiftFITS
import SwiftPixel
import Testing

/// Tests for `FITSPreviewRenderer`: the shared default-settings renderer used by
/// both the app's first render and the QuickLook extensions. It turns a FITS
/// file (by URL or raw bytes) into a display-ready `CGImage`, and surfaces a
/// malformed file as a thrown error.
@Suite( "FITSPreviewRenderer" )
struct FITSPreviewRendererTests
{
    @Test
    func rendersAValidFITSFileToAnImage() throws
    {
        let image = try FITSPreviewRenderer.render( contentsOf: TestFixtures.monoImage )

        #expect( image.width > 0 && image.height > 0 )
    }

    @Test
    func rendersFromRawFITSData() throws
    {
        let data  = try Data( contentsOf: TestFixtures.monoImage )
        let image = try FITSPreviewRenderer.render( data: data )

        #expect( image.width > 0 && image.height > 0 )
    }

    @Test
    func throwsForAMalformedFITSFile()
    {
        #expect( throws: ( any Swift.Error ).self )
        {
            try FITSPreviewRenderer.render( contentsOf: TestFixtures.invalidImage )
        }
    }

    /// An isolated shared-suite store with the FITS previews preference set to the
    /// given value, plus its name for teardown.
    private static func isolatedSuite( fitsPreviews: Bool ) -> ( defaults: UserDefaults, name: String )
    {
        let name     = "FITScopeTests.FITSPreview.\( UUID().uuidString )"
        let defaults = UserDefaults( suiteName: name ) ?? .standard

        defaults.set( fitsPreviews, forKey: AutoStretchPreference.previewsKey( .fits ) )

        return ( defaults, name )
    }

    /// A small integer (`BITPIX = 8`) image HDU with a simple ramp.
    private static func rampHDU() -> ( data: Data, properties: [ FITSPropertySnapshot ] )
    {
        let properties =
            [
                FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
                FITSPropertySnapshot( name: "NAXIS",  value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS1", value: .integer( 4 ) ),
                FITSPropertySnapshot( name: "NAXIS2", value: .integer( 4 ) ),
            ]

        return ( Data( ( 0 ..< 16 ).map { UInt8( $0 * 10 ) } ), properties )
    }

    /// With the FITS previews preference on, an integer-format image previews with an
    /// auto Screen Transfer over identity normalization.
    @Test
    func autoStretchesWhenPreviewsPreferenceOn() throws
    {
        let ( defaults, name ) = Self.isolatedSuite( fitsPreviews: true )

        defer { defaults.removePersistentDomain( forName: name ) }

        let settings = FITSPreviewRenderer.previewSettings( hdu: Self.rampHDU(), previewsDefaults: defaults )

        #expect( settings.stretch   != nil )
        #expect( settings.normalize == .identity )
    }

    /// With the FITS previews preference off, the image previews linear (min/max).
    @Test
    func rendersLinearWhenPreviewsPreferenceOff() throws
    {
        let ( defaults, name ) = Self.isolatedSuite( fitsPreviews: false )

        defer { defaults.removePersistentDomain( forName: name ) }

        let settings = FITSPreviewRenderer.previewSettings( hdu: Self.rampHDU(), previewsDefaults: defaults )

        #expect( settings.stretch   == nil )
        #expect( settings.normalize == .minMax )
    }

    /// When the shared suite cannot be opened (`nil`), the sandboxed extension has no
    /// preference to read and previews linear.
    @Test
    func rendersLinearWhenNoSharedSuite()
    {
        let settings = FITSPreviewRenderer.previewSettings( hdu: Self.rampHDU(), previewsDefaults: nil )

        #expect( settings.stretch   == nil )
        #expect( settings.normalize == .minMax )
    }

    /// Decode-once must not change the result: deriving the preview settings from the
    /// frame's already-decoded samples matches deriving them from the raw bytes.
    @Test
    func decodeOnceSettingsMatchTheBytePath() throws
    {
        let ( defaults, name ) = Self.isolatedSuite( fitsPreviews: true )

        defer { defaults.removePersistentDomain( forName: name ) }

        let hdu     = Self.rampHDU()
        let decoded = try #require( ImageProcessor.decodedImageHDU( data: hdu.data, properties: hdu.properties ) )
        let frame   = FITSDecodedRenderSource( samples: decoded.samples, width: decoded.width, height: decoded.height, bitsPerPixel: decoded.bitsPerPixel, properties: hdu.properties )

        let bytePath    = FITSPreviewRenderer.previewSettings( hdu: hdu, previewsDefaults: defaults )
        let decodedPath = FITSPreviewRenderer.previewSettings( frame: frame, previewsDefaults: defaults )

        #expect( decodedPath.stretch   == bytePath.stretch )
        #expect( decodedPath.normalize == bytePath.normalize )
    }

    /// An RGB colour-planes image previews with a per-channel (unlinked) auto Screen
    /// Transfer when the preference is on, and — crucially — the preview matches the
    /// app: it derives from the same colour source over the same full-scale domain.
    @Test
    func autoStretchesRGBPlanesAsPerChannelMatchingTheApp() throws
    {
        let ( defaults, name ) = Self.isolatedSuite( fitsPreviews: true )

        defer { defaults.removePersistentDomain( forName: name ) }

        let file = try FITSFile( data: try Data( contentsOf: TestFixtures.rgbImage ), options: .lenient )
        let hdu  = try FITSImageDecoder.imageHDU( in: file.sections )

        #expect( FITSImageDecoder.channelCount( from: hdu.properties ) == 3, "the RGB fixture must take the RGB-planes colour branch" )

        let settings = FITSPreviewRenderer.previewSettings( hdu: hdu, previewsDefaults: defaults )

        #expect( settings.normalize == .identity )

        guard case .perChannel = try #require( settings.stretch )
        else
        {
            Issue.record( "an RGB colour image must preview with a per-channel Screen Transfer" )

            return
        }

        // Same colour source + same full-scale derivation the app opens with.
        let fullScale   = try #require( FITSImageDecoder.fullScale( from: hdu.properties ) )
        let colorSource = try #require( ImageProcessor.autoStretchColorSource( forImageHDU: hdu.data, properties: hdu.properties ) )
        let app         = try #require( ImageProcessor.autoStretchSettings( colorSource: colorSource, fullScale: fullScale ) )

        #expect( settings.stretch == app.stretch )
    }
}
