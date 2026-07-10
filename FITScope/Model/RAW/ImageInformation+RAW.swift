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

import Foundation

/// Builds the neutral ``ImageInformation`` summary for a camera RAW image, mirroring
/// the FITS, XISF and ImageIO adapters: the geometry comes from the cropped mosaic's
/// layout, and the remaining fields (camera, lens, ISO, focal length, capture date,
/// exposure) from the RAW file's structured metadata.
public extension ImageInformation
{
    /// Builds the summary from a RAW image's info snapshot.
    ///
    /// - Parameter rawInfo: The parsed RAW image info.
    init( rawInfo: RAWImageInfo )
    {
        var values: [ InfoField: String ] =
            [
                .dimensions: rawInfo.dimensions,
                .bitDepth:   rawInfo.bitDepth,
                .channels:   rawInfo.channels,
            ]

        // The metadata-derived fields (camera, lens, ISO, focal length, date,
        // exposure) do not overlap the structural geometry, so a plain merge keeping
        // the new value is safe.
        values.merge( rawInfo.summaryValues ) { _, new in new }

        self.init( dimensions: rawInfo.dimensions, bitDepth: rawInfo.bitDepth, channels: rawInfo.channels, values: values )
    }
}
