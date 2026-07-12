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

/// Tests for `CosmeticCorrectionControlView`'s pure model ↔ UI mapping and derived
/// enable state.
@Suite( "CosmeticCorrectionControlView" )
struct CosmeticCorrectionControlViewTests
{
    /// The parameters map to the picker mode, with a disabled — or enabled but
    /// inert — value reading as Off.
    @Test
    @MainActor
    func parametersMapToMode() throws
    {
        func parameters( _ isEnabled: Bool, _ correctHot: Bool, _ correctCold: Bool ) -> Processors.CosmeticCorrection.Parameters
        {
            Processors.CosmeticCorrection.Parameters( isEnabled: isEnabled, correctHot: correctHot, hotThreshold: 8.0, correctCold: correctCold, coldThreshold: 8.0 )
        }

        #expect( CosmeticCorrectionControlView.mode( for: parameters( true, true, true ) )   == .hotAndCold )
        #expect( CosmeticCorrectionControlView.mode( for: parameters( true, true, false ) )  == .hotOnly )
        #expect( CosmeticCorrectionControlView.mode( for: parameters( true, false, true ) )  == .coldOnly )
        #expect( CosmeticCorrectionControlView.mode( for: parameters( false, true, true ) )  == .off )
        #expect( CosmeticCorrectionControlView.mode( for: parameters( true, false, false ) ) == .off )
    }

    /// A picked mode updates only the enable and hot/cold flags, preserving the
    /// thresholds so toggling Off and back on keeps the chosen strength.
    @Test
    @MainActor
    func modeAppliesToParametersPreservingThresholds() throws
    {
        let base = Processors.CosmeticCorrection.Parameters( isEnabled: true, correctHot: true, hotThreshold: 6.0, correctCold: true, coldThreshold: 7.0 )

        let off = CosmeticCorrectionControlView.parameters( for: .off, applyingTo: base )

        #expect( off.isEnabled == false )
        #expect( off.hotThreshold == 6.0 )
        #expect( off.coldThreshold == 7.0 )

        let hotOnly = CosmeticCorrectionControlView.parameters( for: .hotOnly, applyingTo: off )

        #expect( hotOnly.isEnabled )
        #expect( hotOnly.correctHot )
        #expect( hotOnly.correctCold == false )
        #expect( hotOnly.hotThreshold == 6.0, "the strength must survive a round trip through Off" )

        let coldOnly = CosmeticCorrectionControlView.parameters( for: .coldOnly, applyingTo: base )

        #expect( coldOnly.correctHot == false )
        #expect( coldOnly.correctCold )
    }

    /// Reading a mode back from the parameters it produced round-trips for every
    /// non-Off mode.
    @Test
    @MainActor
    func modeRoundTrips() throws
    {
        let base = Processors.CosmeticCorrection.Parameters.default

        [ CosmeticCorrectionControlView.Mode.hotAndCold, .hotOnly, .coldOnly, .off ].forEach
        {
            let applied = CosmeticCorrectionControlView.parameters( for: $0, applyingTo: base )

            #expect( CosmeticCorrectionControlView.mode( for: applied ) == $0 )
        }
    }
}
