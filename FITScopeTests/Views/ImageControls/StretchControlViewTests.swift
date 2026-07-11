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
import SwiftPixel
import Testing

/// Tests for `StretchControlView`'s pure selection-to-stretch mapping.
@Suite( "StretchControlView" )
struct StretchControlViewTests
{
    /// The control maps its selection to the applied stretch: None yields no
    /// stretch, Screen Transfer yields the control's current STF parameters.
    @Test
    @MainActor
    func stretchControlMapsToStretch() throws
    {
        let parameters = Processors.Stretch.STFParameters.uniform( .init( shadows: 0.1, midtones: 0.3, highlights: 0.95 ) )

        #expect( StretchControlView.stretch( mode: .none,           screenTransfer: parameters ) == nil )
        #expect( StretchControlView.stretch( mode: .screenTransfer, screenTransfer: parameters ) == parameters )
    }

    /// The reverse mapping — the applied stretch back to the control's mode — that
    /// seeds the control and re-syncs its displayed mode when the shared
    /// adjustments change from outside it (e.g. a Reset). A wrong mapping would
    /// leave the picker showing the wrong mode after an external change.
    @Test
    @MainActor
    func stretchControlMapsStretchBackToMode() throws
    {
        #expect( StretchControlView.mode( nil )                   == .none )
        #expect( StretchControlView.mode( .uniform( .identity ) ) == .screenTransfer )
        #expect( StretchControlView.mode( .perChannel( red: .identity, green: .identity, blue: .identity ) ) == .screenTransfer )
    }

    /// A Screen Transfer stretch renders to a varied (non-flat, non-black) image
    /// rather than throwing or blanking.
    @Test
    @MainActor
    func screenTransferRendersNonDegenerate() throws
    {
        let ( data, properties ) = FITSTestData.gradient()
        let parameters           = Processors.Stretch.STFParameters.uniform( .init( shadows: 0.1, midtones: 0.3, highlights: 0.95 ) )
        let settings             = ImageProcessor.Settings( stretch: parameters )
        let bytes                = try ImageProcessor.render( data: data, properties: properties, settings: settings ).bytes

        #expect( bytes.contains { $0 != 0 },          "the Screen Transfer should not render all black" )
        #expect( bytes.contains { $0 != bytes[ 0 ] }, "the Screen Transfer should not render flat" )
    }
}
