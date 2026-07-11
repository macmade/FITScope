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
import SwiftXISF
import Testing

/// Tests the mapping from an XISF `<DisplayFunction>` to the editable
/// ``Processors/Stretch/STFParameters`` the app seeds and displays. A grayscale
/// image maps to a uniform STF from the red/gray component; an RGB image maps to
/// a per-channel STF from the red/green/blue components; an identity or otherwise
/// unusable display function maps to `nil` so the loader leaves the image linear.
@Suite( "STF display-function mapping" )
struct STFDisplayFunctionMappingTests
{
    /// A grayscale display function maps to a uniform STF built from the red/gray
    /// component, with the `m`/`s`/`h`/`l`/`r` attributes mapped onto
    /// midtones/shadows/highlights/low/high.
    @Test
    func grayscaleMapsToUniform() throws
    {
        let df     = try #require( Self.displayFunction( m: "0.2:0.2:0.2:0.2", s: "0.05:0.05:0.05:0.05", h: "0.9:0.9:0.9:0.9", l: "0:0:0:0", r: "1:1:1:1" ) )
        let params = try #require( Processors.Stretch.STFParameters( displayFunction: df, colorSpace: .gray ) )

        guard case .uniform( let channel ) = params
        else
        {
            Issue.record( "Expected a uniform STF, got \( params )" )

            return
        }

        #expect( channel == Processors.Stretch.STFParameters.Channel( shadows: 0.05, midtones: 0.2, highlights: 0.9, low: 0, high: 1 ) )
    }

    /// An RGB display function maps to a per-channel STF, each channel built from
    /// its own red/green/blue component.
    @Test
    func rgbMapsToPerChannel() throws
    {
        let df     = try #require( Self.displayFunction( m: "0.2:0.3:0.4:0.5", s: "0.01:0.02:0.03:0.04", h: "0.8:0.85:0.9:0.95", l: "0:0:0:0", r: "1:1:1:1" ) )
        let params = try #require( Processors.Stretch.STFParameters( displayFunction: df, colorSpace: .rgb ) )

        guard case .perChannel( let red, let green, let blue ) = params
        else
        {
            Issue.record( "Expected a per-channel STF, got \( params )" )

            return
        }

        #expect( red   == Processors.Stretch.STFParameters.Channel( shadows: 0.01, midtones: 0.2, highlights: 0.8,  low: 0, high: 1 ) )
        #expect( green == Processors.Stretch.STFParameters.Channel( shadows: 0.02, midtones: 0.3, highlights: 0.85, low: 0, high: 1 ) )
        #expect( blue  == Processors.Stretch.STFParameters.Channel( shadows: 0.03, midtones: 0.4, highlights: 0.9,  low: 0, high: 1 ) )
    }

    /// A three-channel non-RGB colour space (e.g. CIE L*a*b*) maps to a uniform STF
    /// from the red/gray component, not per-channel — the colour space, not the raw
    /// channel count, selects the mode, so components are never mapped onto the
    /// wrong channels.
    @Test
    func nonRGBMapsToUniform() throws
    {
        let df     = try #require( Self.displayFunction( m: "0.2:0.3:0.4:0.5", s: "0.01:0.02:0.03:0.04", h: "0.8:0.85:0.9:0.95", l: "0:0:0:0", r: "1:1:1:1" ) )
        let params = try #require( Processors.Stretch.STFParameters( displayFunction: df, colorSpace: .cieLab ) )

        guard case .uniform( let channel ) = params
        else
        {
            Issue.record( "Expected a uniform STF, got \( params )" )

            return
        }

        #expect( channel == Processors.Stretch.STFParameters.Channel( shadows: 0.01, midtones: 0.2, highlights: 0.8, low: 0, high: 1 ) )
    }

    /// The `l`/`r` shadows/highlights dynamic-range expansion maps onto the STF's
    /// low/high bounds.
    @Test
    func rangeExpansionMapsToLowHigh() throws
    {
        let df     = try #require( Self.displayFunction( m: "0.3:0.3:0.3:0.3", s: "0.1:0.1:0.1:0.1", h: "0.9:0.9:0.9:0.9", l: "0.05:0.05:0.05:0.05", r: "0.95:0.95:0.95:0.95" ) )
        let params = try #require( Processors.Stretch.STFParameters( displayFunction: df, colorSpace: .gray ) )

        guard case .uniform( let channel ) = params
        else
        {
            Issue.record( "Expected a uniform STF, got \( params )" )

            return
        }

        #expect( channel.low  == 0.05 )
        #expect( channel.high == 0.95 )
    }

    /// The identity display function (the XISF default) maps to `nil`, so the
    /// image is left linear rather than opening with a no-op stretch.
    @Test
    func identityMapsToNil() throws
    {
        let df = try #require( Self.displayFunction( m: "0.5:0.5:0.5:0.5", s: "0:0:0:0", h: "1:1:1:1", l: "0:0:0:0", r: "1:1:1:1" ) )

        #expect( Processors.Stretch.STFParameters( displayFunction: df, colorSpace: .gray ) == nil )
        #expect( Processors.Stretch.STFParameters( displayFunction: df, colorSpace: .rgb ) == nil )
    }

    /// A display function whose highlights clip is at or below its shadows clip is
    /// unusable and maps to `nil`.
    @Test
    func invalidClipWindowMapsToNil() throws
    {
        let df = try #require( Self.displayFunction( m: "0.5:0.5:0.5:0.5", s: "0.8:0.8:0.8:0.8", h: "0.2:0.2:0.2:0.2", l: "0:0:0:0", r: "1:1:1:1" ) )

        #expect( Processors.Stretch.STFParameters( displayFunction: df, colorSpace: .gray ) == nil )
    }

    /// A display function whose high expansion bound is at or below its low bound
    /// is unusable and maps to `nil`.
    @Test
    func invalidExpansionMapsToNil() throws
    {
        let df = try #require( Self.displayFunction( m: "0.4:0.4:0.4:0.4", s: "0.1:0.1:0.1:0.1", h: "0.9:0.9:0.9:0.9", l: "1:1:1:1", r: "0:0:0:0" ) )

        #expect( Processors.Stretch.STFParameters( displayFunction: df, colorSpace: .gray ) == nil )
    }

    /// A per-channel display function with a single unusable channel maps to
    /// `nil`, since the per-channel apply path validates every channel.
    @Test
    func perChannelWithOneInvalidChannelMapsToNil() throws
    {
        let df = try #require( Self.displayFunction( m: "0.3:0.3:0.3:0.3", s: "0.1:0.1:0.9:0.1", h: "0.9:0.9:0.2:0.9", l: "0:0:0:0", r: "1:1:1:1" ) )

        #expect( Processors.Stretch.STFParameters( displayFunction: df, colorSpace: .rgb ) == nil )
    }

    /// Parses a one-image XISF file carrying the given display-function attributes
    /// and returns its parsed ``XISFDisplayFunction``. The channel count of the
    /// mapping is passed separately, so a single grayscale file suffices for every
    /// case.
    ///
    /// - Parameters:
    ///   - m: The midtones-balance attribute (`rk:g:b:l`).
    ///   - s: The shadows-clipping attribute.
    ///   - h: The highlights-clipping attribute.
    ///   - l: The shadows-expansion attribute.
    ///   - r: The highlights-expansion attribute.
    /// - Returns: The parsed display function, or `nil` when the file carried none.
    private static func displayFunction( m: String, s: String, h: String, l: String, r: String ) -> XISFDisplayFunction?
    {
        let image = XISFTestData.Image( geometry: "1:1:1", sampleFormat: "UInt16", colorSpace: "Gray", displayFunction: ( m, s, h, l, r ), hexData: XISFTestData.hex( XISFTestData.uInt16LE( [ 0 ] ) ) )
        let file  = try? XISFFile( data: XISFTestData.file( images: [ image ] ), options: .lenient )

        return file?.images.first?.displayFunction
    }
}
