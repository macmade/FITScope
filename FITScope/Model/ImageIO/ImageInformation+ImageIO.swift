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

/// Builds the neutral ``ImageInformation`` summary for a photographic image,
/// mirroring the FITS and XISF adapters: the geometry comes from the decoded
/// layout, and the remaining fields (capture date, exposure, ISO, camera and lens)
/// from the image's EXIF/TIFF metadata.
public extension ImageInformation
{
    /// Builds the summary from a photographic image's info snapshot.
    ///
    /// - Parameter imageIOInfo: The parsed photographic image info.
    init( imageIOInfo: ImageIOImageInfo )
    {
        var values: [ InfoField: String ] =
            [
                .dimensions: imageIOInfo.dimensions,
                .bitDepth:   imageIOInfo.bitDepth,
                .channels:   imageIOInfo.channels,
            ]

        // The EXIF/TIFF-derived fields (date, exposure, ISO, camera, lens) take
        // precedence over the structural geometry only where they overlap (they do
        // not), so a plain merge keeping the new value is safe.
        values.merge( imageIOInfo.summaryValues ) { _, new in new }

        self.init( dimensions: imageIOInfo.dimensions, bitDepth: imageIOInfo.bitDepth, channels: imageIOInfo.channels, values: values )
    }
}
