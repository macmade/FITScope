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

/// Builds a format-neutral ``LoadedImage`` from parsed photographic image info,
/// keeping the ImageIO-specific extraction out of the neutral model — the
/// photographic counterpart of the FITS and XISF bridges.
public extension LoadedImage
{
    /// Creates a loaded image from parsed photographic image info, extracting the
    /// format-neutral fields the app-wide UI consumes.
    ///
    /// A photographic image carries no WCS, so the astrometric fields (WCS, target,
    /// plate scale) are absent and the WCS overlays self-hide; the capture date and
    /// exposure come from EXIF, and the observing-site coordinate from GPS.
    ///
    /// - Parameters:
    ///   - info:     The parsed photographic image info.
    ///   - renderer: The renderer for the image.
    convenience init( imageIOInfo info: ImageIOImageInfo, renderer: ImageRenderer )
    {
        self.init(
            url:                info.url,
            metadata:           info.imageMetadata,
            wcs:                nil,
            observationDate:    info.observationDate,
            exposureTime:       info.exposureTime,
            coordinate:         info.coordinate,
            target:             nil,
            pixelScale:         nil,
            isColorFilterArray: false,
            isColor:            info.isColor,
            information:        ImageInformation( imageIOInfo: info ),
            frameTitle:         info.frameTitle,
            renderer:           renderer
        )
    }
}
