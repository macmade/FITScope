/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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

import Testing
@testable import FITScope

/// Tests for `WhiteBalanceControlView`'s pure selection-to-mode mapping.
@Suite( "WhiteBalanceControlView" )
struct WhiteBalanceControlViewTests
{
    /// The white-balance control maps its selection and sliders to a mode.
    @Test
    @MainActor
    func whiteBalanceControlMapsToMode() throws
    {
        #expect( WhiteBalanceControlView.mode( .none,   red: 1, green: 2, blue: 3 ) == nil )
        #expect( WhiteBalanceControlView.mode( .auto,   red: 1, green: 2, blue: 3 ) == .auto )
        #expect( WhiteBalanceControlView.mode( .manual, red: 1, green: 2, blue: 3 ) == .manual( red: 1, green: 2, blue: 3 ) )
    }

    /// The seeded manual gains are identity (1.0): switching to Manual leaves
    /// the image unchanged rather than blanking every channel to black.
    @Test
    @MainActor
    func seededManualGainsAreIdentityAndRender() throws
    {
        #expect( WhiteBalanceControlView.defaultManualGain == 1.0, "manual gains must default to identity, not zero" )

        let gain = WhiteBalanceControlView.defaultManualGain
        let mode = WhiteBalanceControlView.mode( .manual, red: gain, green: gain, blue: gain )

        #expect( mode == .manual( red: 1, green: 1, blue: 1 ) )

        let ( data, properties ) = FITSTestData.gradient()
        let settings             = ImageProcessor.Settings( whiteBalance: mode )
        let bytes                = try ImageProcessor.render( data: data, properties: properties, settings: settings ).bytes

        #expect( bytes.contains { $0 != 0 }, "manual white balance must not blank the image to black" )
    }
}
