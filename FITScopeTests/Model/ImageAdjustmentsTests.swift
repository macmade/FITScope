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

/// Tests for `ImageAdjustments`: the observable model that drives the pipeline
/// configuration the renderer consumes.
@Suite( "ImageAdjustments" )
struct ImageAdjustmentsTests
{
    /// The adjustments model builds a pipeline configuration whose fields map
    /// across from the settings, and changes to the model flow into the config.
    @Test
    @MainActor
    func adjustmentsBuildPipelineConfig() throws
    {
        let adjustments = ImageAdjustments()

        // The model's defaults equal the settings' defaults.
        #expect( adjustments.settings == ImageProcessor.Settings() )

        let config = adjustments.settings.config( scale: 2, offset: 3, headerPattern: .rggb )

        // Header-derived affine scaling passes through unchanged.
        #expect( config.scale?.scale  == 2 )
        #expect( config.scale?.offset == 3 )

        // The defaults render the file as captured: linear normalization only,
        // with no stretch, gamma, white balance or inversion.
        #expect( config.stretch      == nil )
        #expect( config.correctGamma == nil )
        #expect( config.whiteBalance == nil )
        #expect( config.normalize    == .minMax )
        #expect( config.invert       == false )

        // Enabling inversion flows into a freshly built config.
        adjustments.invert = true

        #expect( adjustments.settings.config( scale: 1, offset: 0, headerPattern: nil ).invert )

        // Orientation defaults to identity and is omitted from the config (the
        // image renders as captured).
        #expect( adjustments.orientation.isIdentity )
        #expect( config.orient == nil )

        // A rotation flows into a freshly built config.
        adjustments.orientation = .init( rotation: .clockwise90, mirroredHorizontally: false )

        #expect( adjustments.settings.config( scale: 1, offset: 0, headerPattern: nil ).orient == .init( rotation: .clockwise90, mirroredHorizontally: false ) )

        // The default .auto debayer selection uses the header pattern.
        let debayer = try #require( config.debayer )

        #expect( debayer.pattern == .rggb )
        #expect( debayer.mode    == .bilinear )

        // A changed setting flows into a freshly built config, and an explicit
        // debayer pattern overrides the header.
        adjustments.stretch = .arcsinh( 12 )
        adjustments.debayer = .pattern( .grbg )

        let updated        = adjustments.settings.config( scale: 1, offset: 0, headerPattern: .bggr )
        let updatedDebayer = try #require( updated.debayer )

        #expect( updated.stretch        == .arcsinh( 12 ) )
        #expect( updatedDebayer.pattern == .grbg )
        #expect( updatedDebayer.mode    == .bilinear )
    }
}
