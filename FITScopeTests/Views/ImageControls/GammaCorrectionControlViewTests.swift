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
import Testing

/// Tests for `GammaCorrectionControlView`'s slider bounds.
///
/// The control is now a single always-on slider (a gamma of `1` is the neutral
/// identity, so there is no on/off toggle); the "gamma of `1` is omitted from
/// the pipeline" behaviour is covered by ``ImageAdjustmentsTests``.
@Suite( "GammaCorrectionControlView" )
struct GammaCorrectionControlViewTests
{
    /// The gamma slider minimum stays above zero so the control can never emit
    /// a gamma the pipeline rejects, and even that minimum renders without
    /// throwing.
    @Test
    @MainActor
    func gammaMinimumIsPositiveAndRenders() throws
    {
        #expect( GammaCorrectionControlView.minimumGamma > 0, "a gamma of zero or less throws" )

        let ( data, properties ) = FITSTestData.gradient()
        let settings             = ImageProcessor.Settings( gamma: GammaCorrectionControlView.minimumGamma )
        let bytes                = try ImageProcessor.render( data: data, properties: properties, settings: settings ).bytes

        #expect( bytes.contains { $0 != 0 }, "the minimum gamma should still render" )
    }
}
