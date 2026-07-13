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
import Testing

/// Tests for `ThumbnailLayout`: the shared, pure sizing used by the QuickLook
/// thumbnail extension to pick the reply's context size. It scales a rendered
/// image's pixel dimensions down to fit within QuickLook's requested maximum
/// size while preserving aspect ratio — the extension then fills that context
/// with the image, so the fitted aspect ratio is what keeps the thumbnail free
/// of margins and free of distortion.
@Suite( "ThumbnailLayout" )
struct ThumbnailLayoutTests
{
    @Test
    func preservesAspectRatioWhenTheWidthBinds() throws
    {
        // 800×600 within 400×400: the width binds (scale 0.5) → 400×300, 4:3 kept.
        let size = ThumbnailLayout.fittedSize( imageWidth: 800, imageHeight: 600, within: CGSize( width: 400, height: 400 ) )

        #expect( size.width == 400 )
        #expect( size.height == 300 )
    }

    @Test
    func preservesAspectRatioWhenTheHeightBinds() throws
    {
        // 600×800 within 400×400: the height binds (scale 0.5) → 300×400, 3:4 kept.
        let size = ThumbnailLayout.fittedSize( imageWidth: 600, imageHeight: 800, within: CGSize( width: 400, height: 400 ) )

        #expect( size.width == 300 )
        #expect( size.height == 400 )
    }

    @Test
    func neverExceedsTheMaximumSize() throws
    {
        let maximumSize = CGSize( width: 400, height: 400 )

        // A deliberately fractional fit (777×555): both axes must stay within the
        // maximum so QuickLook does not clamp and reintroduce a margin.
        let size = ThumbnailLayout.fittedSize( imageWidth: 777, imageHeight: 555, within: maximumSize )

        #expect( size.width  <= maximumSize.width )
        #expect( size.height <= maximumSize.height )
    }

    @Test
    func fallsBackToMaximumSizeForADegenerateImage() throws
    {
        let maximumSize = CGSize( width: 400, height: 400 )

        #expect( ThumbnailLayout.fittedSize( imageWidth: 0,   imageHeight: 100, within: maximumSize ) == maximumSize )
        #expect( ThumbnailLayout.fittedSize( imageWidth: 100, imageHeight: 0,   within: maximumSize ) == maximumSize )
    }

    @Test
    func renderMaxDimensionTakesTheLongerSideToDevicePixelsWithHeadroom() throws
    {
        // 512×384 points at scale 2 → 1024 device px on the long side, ×2 supersample.
        let dimension = ThumbnailLayout.renderMaxDimension( maximumSize: CGSize( width: 512, height: 384 ), scale: 2 )

        #expect( dimension == Int( 512 * 2 * ThumbnailLayout.renderSupersample ) )
    }

    @Test
    func renderMaxDimensionUsesTheHeightWhenItBinds() throws
    {
        let dimension = ThumbnailLayout.renderMaxDimension( maximumSize: CGSize( width: 200, height: 800 ), scale: 1 )

        #expect( dimension == Int( 800 * ThumbnailLayout.renderSupersample ) )
    }

    @Test
    func renderMaxDimensionTreatsAnUnsetScaleAsOne() throws
    {
        // A zero/sub-1 scale must not collapse the cap to zero.
        let dimension = ThumbnailLayout.renderMaxDimension( maximumSize: CGSize( width: 256, height: 256 ), scale: 0 )

        #expect( dimension == Int( 256 * ThumbnailLayout.renderSupersample ) )
    }
}
