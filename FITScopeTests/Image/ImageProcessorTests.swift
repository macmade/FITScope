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
import SwiftFITS
import SwiftPixel
import Testing

/// Tests for `ImageProcessor`'s header interpretation, in particular the linear
/// pixel-scaling keywords `BSCALE` / `BZERO`.
@Suite( "ImageProcessor" )
struct ImageProcessorTests
{
    /// A `BSCALE` carrying a floating-point value must be honoured as that
    /// float, rather than falling back to the integer default of 1.
    @Test
    func floatScalingKeywordsAreHonoured() throws
    {
        let properties =
            [
                FITSPropertySnapshot( name: "BSCALE", value: .float( 1.5 ) ),
                FITSPropertySnapshot( name: "BZERO",  value: .float( 0 ) ),
            ]

        let scaling = ImageProcessor.scaling( from: properties )

        #expect( scaling.scale == 1.5 )
        #expect( scaling.scale != 1, "a float BSCALE must not fall back to the default scale" )
    }

    /// With identity normalization, integer samples render in their native
    /// full-scale `[0, 1]` domain — a mid-scale `BITPIX = 8` value renders as
    /// mid-grey, not clamped to white. This confirms the `1 / fullScale` scaling
    /// the config folds in, matching the domain a Screen Transfer is authored in.
    @Test
    func rendersIntegerSamplesInFullScaleDomainUnderIdentity() throws
    {
        let properties =
            [
                FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
                FITSPropertySnapshot( name: "NAXIS",  value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS1", value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS2", value: .integer( 2 ) ),
            ]

        let data   = Data( [ 0, 128, 255, 128 ] )
        let result = try ImageProcessor.render( data: data, properties: properties, settings: ImageProcessor.Settings( normalize: .identity ) )

        // Under the old scale-1 behaviour, identity would clamp 128 to 1.0 (white);
        // the full-scale scaling instead maps it to ~0.5, so a mid-grey byte appears.
        #expect( result.bytes.contains { $0 > 0 && $0 < 200 } )
    }

    /// Min/max normalization is unaffected by the full-scale scaling (min/max is
    /// scale-invariant): a `BITPIX = 8` ramp still spans black to white with the
    /// interior values in between, exactly as before the scaling was folded in.
    @Test
    func minMaxRenderingIsUnchangedByFullScaleScaling() throws
    {
        let properties =
            [
                FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
                FITSPropertySnapshot( name: "NAXIS",  value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS1", value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS2", value: .integer( 2 ) ),
            ]

        let data   = Data( [ 10, 20, 30, 40 ] )
        let result = try ImageProcessor.render( data: data, properties: properties )

        // 10 → 0, 40 → 255, and the interior 20/30 map to (value − 10) / 30, i.e.
        // ~85 and ~170 — the same result the raw samples produced before scaling.
        #expect( result.bytes.contains { ( 80 ... 90 ).contains( $0 ) } )
        #expect( result.bytes.contains { ( 165 ... 175 ).contains( $0 ) } )
    }

    /// The auto-stretch settings derive a *uniform* Screen Transfer seeded over
    /// identity normalization — matching the inspector's "Auto" action, so opening
    /// and clicking Auto agree; per-channel balancing stays a manual choice.
    @Test
    func autoStretchSettingsDeriveUniformStretchOverIdentity() throws
    {
        let buffer   = try PixelBuffer( width: 4, height: 4, channels: 1, pixels: ( 0 ..< 16 ).map { Double( $0 ) * 100 }, isNormalized: false )
        let settings = try #require( ImageProcessor.autoStretchSettings( detectionImage: buffer, fullScale: 1600 ) )

        #expect( settings.normalize == .identity )

        guard case .uniform = try #require( settings.stretch )
        else
        {
            Issue.record( "the auto-stretch settings must be a uniform Screen Transfer, not per-channel" )

            return
        }
    }

    /// No detection image means no auto-stretch settings to open with.
    @Test
    func autoStretchSettingsAreNilWithoutADetectionImage()
    {
        #expect( ImageProcessor.autoStretchSettings( detectionImage: nil, fullScale: 65535 ) == nil )
    }

    /// A non-positive full scale cannot bring samples into `[0, 1]`, so no settings
    /// are derived (the caller opens the image linear instead).
    @Test
    func autoStretchSettingsAreNilForANonPositiveFullScale() throws
    {
        let buffer = try PixelBuffer( width: 2, height: 2, channels: 1, pixels: [ 0, 100, 200, 300 ], isNormalized: false )

        #expect( ImageProcessor.autoStretchSettings( detectionImage: buffer, fullScale: 0 ) == nil )
    }

    /// A mono colour source derives exactly the same settings as the single-channel
    /// detection path — the shared derivation is a superset that keeps mono uniform.
    @Test
    func autoStretchSettingsFromAMonoColorSourceMatchTheDetectionPath() throws
    {
        let buffer     = try PixelBuffer( width: 4, height: 4, channels: 1, pixels: ( 0 ..< 16 ).map { Double( $0 ) * 100 }, isNormalized: false )
        let fromColor  = try #require( ImageProcessor.autoStretchSettings( colorSource: .mono( buffer ), fullScale: 1600 ) )
        let fromMono   = try #require( ImageProcessor.autoStretchSettings( detectionImage: buffer, fullScale: 1600 ) )

        #expect( fromColor == fromMono )
    }

    /// A colour-filter-array source derives a per-channel (unlinked) STF over identity
    /// normalization, in the full-scale domain — matching the mosaic derivation
    /// applied to the same scaled, clamped samples.
    @Test
    func autoStretchSettingsFromAMosaicColorSourceArePerChannel() throws
    {
        // A 4×4 RGGB mosaic whose channels carry different levels, so the unlinked
        // derivation must give the channels different mappings.
        let fullScale = 1000.0
        let buffer    = try PixelBuffer( width: 4, height: 4, channels: 1, pixels: ( 0 ..< 16 ).map { Double( $0 ) * 50 }, isNormalized: false )
        let settings  = try #require( ImageProcessor.autoStretchSettings( colorSource: .mosaic( buffer, pattern: .rggb ), fullScale: fullScale ) )

        #expect( settings.normalize == .identity )

        guard case .perChannel( let red, let green, _ ) = try #require( settings.stretch )
        else
        {
            Issue.record( "a colour-filter-array source must derive a per-channel Screen Transfer" )

            return
        }

        // The channels are genuinely unlinked: red and green come from their own sites.
        #expect( red != green )

        // And it matches the mosaic derivation over the same scaled, clamped buffer.
        var input = try PixelBuffer( width: 4, height: 4, channels: 1, pixels: buffer.pixels.map { $0 / fullScale }, isNormalized: false )

        try Processors.Normalize( mode: .identity ).process( buffer: &input )

        let expected = try Processors.Stretch.STFParameters.computed( fromMosaic: input, pattern: .rggb )

        #expect( settings.stretch == expected )
    }

    /// A co-located 3-channel source (RGB planes or a photographic image) derives a
    /// per-channel (unlinked) STF from its channels directly.
    @Test
    func autoStretchSettingsFromAChannelsColorSourceArePerChannel() throws
    {
        let red      = ( 0 ..< 16 ).map { _ in 50.0 }
        let green    = ( 0 ..< 16 ).map { Double( $0 ) * 40 }
        let blue     = ( 0 ..< 16 ).map { Double( $0 ) * 20 }
        let planes   = zip( red, zip( green, blue ) ).flatMap { [ $0.0, $0.1.0, $0.1.1 ] }
        let buffer   = try PixelBuffer( width: 4, height: 4, channels: 3, pixels: planes, isNormalized: false )
        let settings = try #require( ImageProcessor.autoStretchSettings( colorSource: .channels( buffer ), fullScale: 1000 ) )

        #expect( settings.normalize == .identity )

        guard case .perChannel = try #require( settings.stretch )
        else
        {
            Issue.record( "a 3-channel colour source must derive a per-channel Screen Transfer" )

            return
        }
    }

    /// No colour source, or a non-positive full scale, yields no settings.
    @Test
    func autoStretchSettingsFromAColorSourceAreNilWhenUnavailable() throws
    {
        let buffer = try PixelBuffer( width: 2, height: 2, channels: 1, pixels: [ 0, 100, 200, 300 ], isNormalized: false )

        #expect( ImageProcessor.autoStretchSettings( colorSource: nil, fullScale: 1000 ) == nil )
        #expect( ImageProcessor.autoStretchSettings( colorSource: .mosaic( buffer, pattern: .rggb ), fullScale: 0 ) == nil )
    }

    /// The derivation works over the min/max domain too (a floating-point source with no
    /// fixed full scale): colour yields per-channel, mono yields uniform — the same
    /// shape as the full-scale domain, just normalized differently.
    @Test
    func autoStretchSettingsDeriveOverTheMinMaxDomain() throws
    {
        let red    = ( 0 ..< 16 ).map { Double( 20  + $0 % 8 ) }
        let green  = ( 0 ..< 16 ).map { Double( 120 + $0 % 8 ) }
        let blue   = ( 0 ..< 16 ).map { Double( 200 + $0 % 8 ) }
        let planes = try PixelUtilities.interleave( planes: [ red, green, blue ] )
        let colour = try PixelBuffer( width: 16, height: 1, channels: 3, pixels: planes, isNormalized: false )
        let mono   = try PixelBuffer( width: 16, height: 1, channels: 1, pixels: ( 0 ..< 16 ).map { Double( $0 ) * 10 }, isNormalized: false )

        let colourSettings = try #require( ImageProcessor.autoStretchSettings( colorSource: .channels( colour ), domain: .minMax ) )
        let monoSettings   = try #require( ImageProcessor.autoStretchSettings( colorSource: .mono( mono ), domain: .minMax ) )

        #expect( colourSettings.normalize == .minMax )
        #expect( monoSettings.normalize   == .minMax )

        guard case .perChannel = try #require( colourSettings.stretch ), case .uniform = try #require( monoSettings.stretch )
        else
        {
            Issue.record( "min/max colour must be per-channel and min/max mono uniform" )

            return
        }
    }

    /// A colour-filter-array source derives per-channel over the min/max domain as well.
    @Test
    func autoStretchSettingsDeriveMosaicPerChannelOverMinMax() throws
    {
        let buffer   = try PixelBuffer( width: 4, height: 4, channels: 1, pixels: ( 0 ..< 16 ).map { Double( $0 ) * 50 }, isNormalized: false )
        let settings = try #require( ImageProcessor.autoStretchSettings( colorSource: .mosaic( buffer, pattern: .rggb ), domain: .minMax ) )

        #expect( settings.normalize == .minMax )

        guard case .perChannel = try #require( settings.stretch )
        else
        {
            Issue.record( "a mosaic source must derive per-channel over the min/max domain too" )

            return
        }
    }

    /// A FITS RGB `NAXIS=3` frame exposes a co-located 3-channel colour input, so it
    /// derives a per-channel STF.
    @Test
    func fitsColorSourceIsChannelsForRGBPlanes() throws
    {
        let ( data, properties ) = FITSTestData.rgbPlanes( width: 4, height: 3 )
        let source               = try #require( ImageProcessor.autoStretchColorSource( forImageHDU: data, properties: properties ) )

        guard case .channels( let buffer ) = source
        else
        {
            Issue.record( "an RGB NAXIS=3 frame must expose a channels colour input" )

            return
        }

        #expect( buffer.channels == 3 )
    }

    /// A FITS frame carrying `BAYERPAT` exposes its raw mosaic and pattern, so it
    /// derives a per-channel STF by deinterleaving.
    @Test
    func fitsColorSourceIsMosaicForACFAFrame() throws
    {
        let ( data, base ) = FITSTestData.gradient( width: 4, height: 4 )
        let properties     = base + [ FITSPropertySnapshot( name: "BAYERPAT", value: .string( "RGGB" ) ) ]
        let source         = try #require( ImageProcessor.autoStretchColorSource( forImageHDU: data, properties: properties ) )

        guard case .mosaic( _, let pattern ) = source
        else
        {
            Issue.record( "a BAYERPAT frame must expose a mosaic colour input" )

            return
        }

        #expect( pattern == .rggb )
    }

    /// A mono FITS frame has no colour input, so the caller falls back to its
    /// single-channel luminance and a uniform STF.
    @Test
    func fitsColorSourceIsNilForAMonoFrame()
    {
        let ( data, properties ) = FITSTestData.gradient( width: 4, height: 4 )

        #expect( ImageProcessor.autoStretchColorSource( forImageHDU: data, properties: properties ) == nil )
    }

    /// The core of the initiative: on a colour-imbalanced frame (a dim channel), the
    /// per-channel derivation clips that channel by only its own tail, where the old
    /// uniform (luminance-derived) shadow crushes most of it to black.
    @Test
    func perChannelClipsAnImbalancedChannelFarLessThanUniform() throws
    {
        let fullScale = 1000.0
        let count     = 64
        let red       = ( 0 ..< count ).map { Double( 25  + $0 % 10 ) } // dim: ~0.025–0.034 of full scale
        let green     = ( 0 ..< count ).map { Double( 295 + $0 % 10 ) } // bright: ~0.30
        let blue      = ( 0 ..< count ).map { Double( 295 + $0 % 10 ) }

        // The colour input (raw domain, as the loaders build it) and the mean
        // luminance the old uniform path derived a single shadow from.
        let interleavedRaw = try PixelUtilities.interleave( planes: [ red, green, blue ] )
        let colorBuffer    = try PixelBuffer( width: count, height: 1, channels: 3, pixels: interleavedRaw, isNormalized: false )
        let luminanceRaw   = ( 0 ..< count ).map { ( red[ $0 ] + green[ $0 ] + blue[ $0 ] ) / 3 }
        let luminance      = try PixelBuffer( width: count, height: 1, channels: 1, pixels: luminanceRaw, isNormalized: false )

        let perChannel = try #require( ImageProcessor.autoStretchSettings( colorSource: .channels( colorBuffer ), fullScale: fullScale ) )
        let uniform    = try #require( ImageProcessor.autoStretchSettings( colorSource: .mono( luminance ),       fullScale: fullScale ) )

        // The display buffer the render stretches: the raw samples scaled into [0, 1].
        let displayPixels = interleavedRaw.map { $0 / fullScale }
        let perChannelSTF = try #require( perChannel.stretch )
        let uniformSTF    = try #require( uniform.stretch )

        let uniformClipped    = try Self.redClippedFraction( applying: uniformSTF,    to: displayPixels, count: count )
        let perChannelClipped = try Self.redClippedFraction( applying: perChannelSTF, to: displayPixels, count: count )

        #expect( uniformClipped    > 0.9 ) // the linked shadow crushes the dim red channel
        #expect( perChannelClipped < 0.1 ) // each channel clips only its own darkest tail
    }

    /// Applies an STF to an interleaved 3-channel display buffer and returns the
    /// fraction of the red channel clipped to black.
    ///
    /// - Parameters:
    ///   - stretch: The STF to apply.
    ///   - pixels:  The interleaved, normalized `[0, 1]` samples.
    ///   - count:   The pixel count (red samples stride the buffer by three).
    /// - Returns: The fraction of red samples mapped to `0`.
    /// - Throws: Any error thrown building or processing the buffer.
    private static func redClippedFraction( applying stretch: Processors.Stretch.STFParameters, to pixels: [ Double ], count: Int ) throws -> Double
    {
        var buffer = try PixelBuffer( width: count, height: 1, channels: 3, pixels: pixels, isNormalized: true )

        try Processors.Stretch( parameters: stretch ).process( buffer: &buffer )

        let red     = stride( from: 0, to: buffer.pixels.count, by: 3 ).map { buffer.pixels[ $0 ] }
        let clipped = red.filter { $0 <= 0.0 }.count

        return Double( clipped ) / Double( red.count )
    }

    /// Integer-formatted scaling keywords keep working: a `BZERO` of the
    /// integer `32768` (the usual unsigned-16-bit offset) is read as `32768`.
    @Test
    func integerScalingKeywordsAreHonoured() throws
    {
        let properties =
            [
                FITSPropertySnapshot( name: "BZERO",  value: .integer( 32768 ) ),
                FITSPropertySnapshot( name: "BSCALE", value: .integer( 1 ) ),
            ]

        let scaling = ImageProcessor.scaling( from: properties )

        #expect( scaling.offset == 32768 )
    }

    /// `render` itself handles only a single 2-D image (or an RGB colour cube); a
    /// whole `NAXIS=3` cube passed to it directly is rejected with a diagnostic that
    /// names the offending `NAXIS` value. (A multi-image cube is split into per-plane
    /// 2-D render sources by the loader, so `render` never sees the whole cube for a
    /// supported file — see `FITSImageLoaderMultiImageTests`.)
    @Test
    func nonTwoDimensionalGeometryIsRejected() throws
    {
        let properties: [ FITSPropertySnapshot ] =
            [
                FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
                FITSPropertySnapshot( name: "NAXIS",  value: .integer( 3 ) ),
                FITSPropertySnapshot( name: "NAXIS1", value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS2", value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS3", value: .integer( 2 ) ),
            ]

        let error = try #require( throws: ( any Error ).self )
        {
            _ = try ImageProcessor.render( data: Data(), properties: properties )
        }

        let message = "\( error )"

        #expect( message.contains( "Unsupported image geometry" ), "expected an unsupported-geometry error, got: \"\( message )\"" )
        #expect( message.contains( "NAXIS = 3" ), "the error must report the offending NAXIS value, got: \"\( message )\"" )
    }

    /// A 90° rotation swaps the rendered image's width and height; without an
    /// orientation the dimensions are unchanged.
    @Test
    func rotationSwapsRenderedDimensions() throws
    {
        let properties: [ FITSPropertySnapshot ] =
            [
                FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
                FITSPropertySnapshot( name: "NAXIS",  value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS1", value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS2", value: .integer( 1 ) ),
            ]

        let data = Data( [ 10, 200 ] )

        let unrotated = try ImageProcessor.render( data: data, properties: properties )

        #expect( unrotated.image.width  == 2 )
        #expect( unrotated.image.height == 1 )

        var settings = ImageProcessor.Settings()

        settings.orientation = .init( rotation: .clockwise90, mirroredHorizontally: false )

        let rotated = try ImageProcessor.render( data: data, properties: properties, settings: settings )

        #expect( rotated.image.width  == 1 )
        #expect( rotated.image.height == 2 )
    }

    /// An RGB colour-planes image (`NAXIS=3`, third axis = 3, `CTYPE1`/`CTYPE2`
    /// present, no `CTYPE3`) renders as a genuine colour image: the display image
    /// keeps the plane dimensions and the render is tagged as an `.rgb` input.
    @Test
    func rgbColorPlanesRenderAsColor() throws
    {
        let ( data, properties ) = FITSTestData.rgbPlanes( width: 4, height: 3 )

        let result = try ImageProcessor.render( data: data, properties: properties )

        #expect( result.image.width  == 4 )
        #expect( result.image.height == 3 )
        #expect( result.inputPixelFormat  == .rgb, "RGB planes must render as a colour (rgb) input, not mono" )
        #expect( result.outputPixelFormat == .rgb )
    }

    /// The RGB-planes rule accepts any `NAXIS=3` with a third axis of exactly 3 and
    /// no `CTYPE3`. The spatial `CTYPE1`/`CTYPE2` are *not* required — many real RGB
    /// FITS files carry no WCS — so a bare 3-plane cube is still recognised as colour.
    @Test
    func rgbPlanesDetectionRule() throws
    {
        func properties( naxis3: Int64, ctype1: String? = "RA---TAN", ctype2: String? = "DEC--TAN", ctype3: String? = nil ) -> [ FITSPropertySnapshot ]
        {
            var props: [ FITSPropertySnapshot ] =
                [
                    FITSPropertySnapshot( name: "NAXIS",  value: .integer( 3 ) ),
                    FITSPropertySnapshot( name: "NAXIS3", value: .integer( naxis3 ) ),
                ]

            ctype1.map { props.append( FITSPropertySnapshot( name: "CTYPE1", value: .string( $0 ) ) ) }
            ctype2.map { props.append( FITSPropertySnapshot( name: "CTYPE2", value: .string( $0 ) ) ) }
            ctype3.map { props.append( FITSPropertySnapshot( name: "CTYPE3", value: .string( $0 ) ) ) }

            return props
        }

        #expect( ImageProcessor.isRGBPlanes( properties: properties( naxis3: 3 ) ) )
        #expect( ImageProcessor.isRGBPlanes( properties: properties( naxis3: 5 ) ) == false, "the third axis must be 3" )
        #expect( ImageProcessor.isRGBPlanes( properties: properties( naxis3: 3, ctype1: nil, ctype2: nil ) ), "a bare 3-plane cube (no WCS) is still RGB" )
        #expect( ImageProcessor.isRGBPlanes( properties: properties( naxis3: 3, ctype2: "  " ) ), "a blank CTYPE2 no longer disqualifies RGB" )
        #expect( ImageProcessor.isRGBPlanes( properties: properties( naxis3: 3, ctype3: "WAVE" ) ) == false, "a present CTYPE3 rules out the RGB-planes case" )
        #expect( ImageProcessor.isRGBPlanes( properties: FITSTestData.gradient().properties ) == false, "a 2-D image is not RGB planes" )
    }

    /// The multi-image rule accepts a `NAXIS=3` cube whose third axis is a plain
    /// frame index: `NAXIS3 ≥ 2` and `≠ 3` (a count of 3 is claimed as RGB) and no
    /// `CTYPE3` (whose presence marks a physical data cube).
    @Test
    func multiImageCubeDetectionRule() throws
    {
        func properties( naxis: Int64 = 3, naxis3: Int64, ctype3: String? = nil ) -> [ FITSPropertySnapshot ]
        {
            var props: [ FITSPropertySnapshot ] =
                [
                    FITSPropertySnapshot( name: "NAXIS",  value: .integer( naxis ) ),
                    FITSPropertySnapshot( name: "NAXIS3", value: .integer( naxis3 ) ),
                ]

            ctype3.map { props.append( FITSPropertySnapshot( name: "CTYPE3", value: .string( $0 ) ) ) }

            return props
        }

        #expect( ImageProcessor.isMultiImageCube( properties: properties( naxis3: 2 ) ), "2 planes with no physical third axis is a multi-image cube" )
        #expect( ImageProcessor.isMultiImageCube( properties: properties( naxis3: 7 ) ), "7 planes is a multi-image cube" )
        #expect( ImageProcessor.isMultiImageCube( properties: properties( naxis3: 3 ) ) == false, "a 3-plane cube is claimed by the RGB rule, not multi-image" )
        #expect( ImageProcessor.isMultiImageCube( properties: properties( naxis3: 1 ) ) == false, "a single plane is not a stack" )
        #expect( ImageProcessor.isMultiImageCube( properties: properties( naxis3: 4, ctype3: "WAVE" ) ) == false, "a physical CTYPE3 marks a data cube, not separate images" )
        #expect( ImageProcessor.isMultiImageCube( properties: properties( naxis: 2, naxis3: 0 ) ) == false, "a 2-D image is not a multi-image cube" )

        // The RGB and multi-image rules are mutually exclusive over every NAXIS=3 shape.
        #expect( ImageProcessor.isRGBPlanes( properties: properties( naxis3: 4 ) ) == false )
        #expect( ImageProcessor.isMultiImageCube( properties: properties( naxis3: 3 ) ) == false )
    }

    /// `cubePlanes` splits a multi-image cube into one 2-D HDU per plane: each plane
    /// carries a `NAXIS=2` header (no `NAXIS3`) and its own contiguous byte slice, so
    /// the existing 2-D render path renders each frame unchanged.
    @Test
    func cubePlanesSplitsIntoTwoDimensionalHDUs() throws
    {
        // Three 2×2 planes filled with distinct constants: 1, 2, 3.
        let planeBytes: [ [ UInt8 ] ] = [ [ 1, 1, 1, 1 ], [ 2, 2, 2, 2 ], [ 3, 3, 3, 3 ] ]
        let data                      = Data( planeBytes.flatMap { $0 } )
        let properties: [ FITSPropertySnapshot ] =
            [
                FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
                FITSPropertySnapshot( name: "NAXIS",  value: .integer( 3 ) ),
                FITSPropertySnapshot( name: "NAXIS1", value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS2", value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS3", value: .integer( 4 ) ),
            ]

        let planes = ImageProcessor.cubePlanes( data: data, properties: properties )

        // NAXIS3 says 4 but only 3 planes of data are present; the truncated plane is
        // dropped rather than surfaced as a broken frame.
        #expect( planes.count == 3, "one HDU per plane actually present in the data" )

        for ( index, plane ) in planes.enumerated()
        {
            #expect( plane.properties.first { $0.name == "NAXIS"  }?.value.integer == 2, "each plane is a 2-D HDU" )
            #expect( plane.properties.contains { $0.name == "NAXIS3" } == false, "the third-axis keyword is dropped from a plane" )
            #expect( Array( plane.data ) == planeBytes[ index ], "each plane carries its own contiguous slice" )
        }
    }

    /// A `NAXIS=3` file with a physical `CTYPE3` is neither RGB nor a multi-image
    /// stack; `render` rejects it with a message that names it as a data cube,
    /// distinct from the RGB / multi-image cases.
    @Test
    func physicalDataCubeIsRejected() throws
    {
        let properties: [ FITSPropertySnapshot ] =
            [
                FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
                FITSPropertySnapshot( name: "NAXIS",  value: .integer( 3 ) ),
                FITSPropertySnapshot( name: "NAXIS1", value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS2", value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS3", value: .integer( 5 ) ),
                FITSPropertySnapshot( name: "CTYPE3", value: .string( "WAVE" ) ),
            ]

        #expect( ImageProcessor.isRGBPlanes( properties: properties ) == false )
        #expect( ImageProcessor.isMultiImageCube( properties: properties ) == false )

        let error = try #require( throws: ( any Error ).self )
        {
            _ = try ImageProcessor.render( data: Data(), properties: properties )
        }

        let message = "\( error )"

        #expect( message.contains( "NAXIS = 3" ), "expected the unsupported-geometry error, got: \"\( message )\"" )
        #expect( message.contains( "cube" ), "the message must identify it as a data cube, got: \"\( message )\"" )
    }

    /// A non-positive `NAXIS2` is rejected with a diagnostic that names the
    /// offending axis and value — NAXIS2, not NAXIS1.
    @Test
    func nonPositiveNAXIS2IsRejectedNamingTheAxis() throws
    {
        let properties: [ FITSPropertySnapshot ] =
            [
                FITSPropertySnapshot( name: "BITPIX", value: .integer( 8 ) ),
                FITSPropertySnapshot( name: "NAXIS",  value: .integer( 2 ) ),
                FITSPropertySnapshot( name: "NAXIS1", value: .integer( 1 ) ),
                FITSPropertySnapshot( name: "NAXIS2", value: .integer( 0 ) ),
            ]

        let error = try #require( throws: ( any Error ).self )
        {
            _ = try ImageProcessor.render( data: Data(), properties: properties )
        }

        let message = "\( error )"

        #expect( message.contains( "NAXIS2" ), "the error must name NAXIS2, got: \"\( message )\"" )
        #expect( message.contains( "0" ),      "the error must report the offending value, got: \"\( message )\"" )
    }

    /// The default settings snapshot carries an enabled, conservative cosmetic
    /// correction, so an untouched image is repaired out of the box.
    @Test
    func defaultSettingsCarryEnabledCosmeticCorrection() throws
    {
        let settings = ImageProcessor.Settings()

        #expect( settings.cosmeticCorrection == .default )
        #expect( settings.cosmeticCorrection.isEnabled )
    }

    /// An enabled cosmetic correction flows into the built pipeline configuration.
    @Test
    func enabledCosmeticCorrectionPopulatesConfig() throws
    {
        let settings = ImageProcessor.Settings()
        let config   = settings.config( scale: 1, offset: 0, inputFormat: .mono )

        #expect( config.cosmeticCorrection == .default )
    }

    /// A disabled cosmetic correction collapses to `nil` in the configuration, so
    /// no cosmetic stage is added to the pipeline — mirroring how the other neutral
    /// tunables collapse.
    @Test
    func disabledCosmeticCorrectionCollapsesToNilInConfig() throws
    {
        let disabled = Processors.CosmeticCorrection.Parameters( isEnabled: false, correctHot: true, hotThreshold: 8.0, correctCold: true, coldThreshold: 8.0 )
        let settings = ImageProcessor.Settings( cosmeticCorrection: disabled )
        let config   = settings.config( scale: 1, offset: 0, inputFormat: .mono )

        #expect( config.cosmeticCorrection == nil )
    }

    /// The colour-filter-array pattern mapping (shared by the FITS `BAYERPAT` and
    /// XISF paths) accepts the four valid Bayer arrangements — including the common
    /// `GBRG` — and rejects the non-standard `RGBG` and any unknown value.
    @Test
    func debayerPatternMappingAcceptsValidPatternsAndRejectsRGBG() throws
    {
        #expect( try ImageProcessor.debayerPattern( named: "BGGR" ) == .bggr )
        #expect( try ImageProcessor.debayerPattern( named: "GRBG" ) == .grbg )
        #expect( try ImageProcessor.debayerPattern( named: "RGGB" ) == .rggb )
        #expect( try ImageProcessor.debayerPattern( named: "GBRG" ) == .gbrg )

        #expect( throws: ( any Error ).self ) { try ImageProcessor.debayerPattern( named: "RGBG" ) }
        #expect( throws: ( any Error ).self ) { try ImageProcessor.debayerPattern( named: "XYZW" ) }
    }
}
