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

/// Builds a format-neutral ``LoadedImage`` from parsed FITS header info, keeping
/// the FITS-specific extraction out of the neutral model. This is the bridge the
/// FITS loader uses; other formats build a ``LoadedImage`` from their own sources.
public extension LoadedImage
{
    /// Creates a loaded image from parsed FITS header info, extracting the
    /// format-neutral fields the app-wide UI consumes.
    ///
    /// The header's ``WorldCoordinateSystem`` is carried so the astrometric
    /// overlays gate exactly as before; the typed convenience values (capture date,
    /// exposure, coordinate, plate scale) are derived from that same metadata.
    ///
    /// - Parameters:
    ///   - info:     The parsed FITS header info.
    ///   - renderer: The renderer for the image.
    convenience init( info: FITSImageInfo, renderer: ImageRenderer )
    {
        let metadata = info.metadata

        self.init(
            url:                info.url,
            metadata:           info.imageMetadata,
            wcs:                metadata.worldCoordinateSystem,
            observationDate:    metadata.observationDate,
            exposureTime:       metadata.exposureTime,
            coordinate:         metadata.coordinate,
            pixelScale:         metadata.pixelScale,
            isColorFilterArray: info.isColorFilterArray,
            information:        ImageInformation( fitsMetadata: info.imageMetadata ),
            renderer:           renderer
        )
    }
}
