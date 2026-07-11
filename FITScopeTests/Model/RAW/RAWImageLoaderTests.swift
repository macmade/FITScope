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
import SwiftPixel
import Testing

/// Tests that ``RAWImageLoader`` opens a camera RAW file into the format-neutral
/// image layer: decoding the linear sensor mosaic through SwiftRAW, debayering it to
/// colour, building the detection image, and mapping the camera/exposure metadata.
@Suite( "RAWImageLoader" )
struct RAWImageLoaderTests
{
    /// The factory routes a RAW file to ``RAWImageLoader`` (and not the photographic
    /// ImageIO loader, even though a DNG would also conform to `public.tiff`).
    @Test
    @MainActor
    func factoryRoutesRAWToRAWLoader()
    {
        let loader = ImageLoader.loader( for: TestFixtures.cameraRAW )

        #expect( loader is RAWImageLoader )
    }

    /// With auto-stretch on, the RAW image opens with an auto Screen Transfer applied
    /// as an adjustment (the "opened" state, over identity normalization — the
    /// full-scale domain the sensor counts are scaled into) — not flagged as edited
    /// on open, but resettable to the unstretched min/max baseline.
    @Test
    @MainActor
    func opensWithAutoStretchWhenEnabled() async throws
    {
        let loader = RAWImageLoader( url: TestFixtures.cameraRAW, autoStretch: true )

        await loader.load()

        let image       = try #require( loader.image )
        let adjustments = image.renderer.adjustments

        #expect( adjustments.stretch          != nil )
        #expect( adjustments.opened.stretch   != nil )
        #expect( adjustments.opened.normalize == .identity )
        #expect( adjustments.baseline.stretch   == nil )
        #expect( adjustments.baseline.normalize == .minMax )
        #expect( adjustments.hasAdjustments == false )
        #expect( adjustments.isModified( \.stretch ) )
    }

    /// With auto-stretch off, the RAW image opens linear on the unstretched min/max
    /// baseline, with no stretch.
    @Test
    @MainActor
    func opensLinearWhenAutoStretchDisabled() async throws
    {
        let loader = RAWImageLoader( url: TestFixtures.cameraRAW )

        await loader.load()

        let image = try #require( loader.image )

        #expect( image.renderer.adjustments.stretch            == nil )
        #expect( image.renderer.adjustments.baseline.stretch   == nil )
        #expect( image.renderer.adjustments.baseline.normalize == .minMax )
    }

    /// The bundled Canon CR3 loads as a single colour-filter-array frame, debayers to
    /// colour, exposes a single-channel read-out and a detection image, and surfaces
    /// its camera metadata.
    @Test
    @MainActor
    func loadsBundledCR3AsColor() async throws
    {
        let loader = RAWImageLoader( url: TestFixtures.cameraRAW )

        await loader.load()

        let image = try #require( loader.image )

        #expect( loader.error == nil )
        #expect( image.isColorFilterArray )
        #expect( image.isColor )
        #expect( image.graph == nil )

        let information = try #require( image.information )
        let instrument  = information.rows( for: [ .instrument ] ).first { $0.field == .instrument }?.value

        #expect( instrument?.contains( "Canon" ) == true )

        // The mosaic debayers to a genuine colour image through the shared pipeline.
        let source = try image.renderer.renderSourceSnapshot()
        let result = try source.makeResult( settings: image.renderer.adjustments.baseline )

        #expect( result.inputPixelFormat == .cfa )
        #expect( result.image.width > 0 )
        #expect( result.image.height > 0 )
        #expect( source.detectionImage != nil )

        // A RAW mosaic is single-channel, so the cursor read-out vends one value.
        let readOut = try #require( source.pixelValues( atX: 0, y: 0 ) )

        #expect( readOut.count == 1 )

        // The fixture carries an all-zero GPS pair ("no fix" sentinel), so it resolves
        // to no observing-site location and no GPS metadata section.
        #expect( image.coordinate == nil )
        #expect( image.metadata.sections.contains { $0.title == "GPS" } == false )
    }

    /// A file whose bytes are not a readable RAW fails the load with an error and no
    /// image, rather than crashing.
    @Test
    @MainActor
    func failsGracefullyOnUnreadableData() async
    {
        let loader = RAWImageLoader( url: TestFixtures.cameraRAW, data: Data( [ 0x00, 0x01, 0x02, 0x03 ] ) )

        await loader.load()

        #expect( loader.image == nil )
        #expect( loader.error != nil )
    }
}
