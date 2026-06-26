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
import SwiftAstro

/// Bridges the app's FITS data to SwiftAstro's star detection: it decodes the
/// linear mono buffer from a render input and runs a detector over it.
///
/// The entry point is `nonisolated` and works on `Sendable` inputs, so a caller
/// can run it off the main actor (detection is independent of the display
/// pipeline — it uses the linear sensor values, not the rendered image).
public enum StarDetection
{
    /// Detects stars in the raw FITS image data.
    ///
    /// - Parameters:
    ///   - data:       The image HDU's raw pixel bytes.
    ///   - properties: The owning header's property snapshots.
    ///   - detector:   The detector to use; defaults to ``MomentStarDetector``.
    /// - Returns: The detected stars and their aggregate metrics, or `nil` when
    ///   the data cannot be decoded into an image.
    public static func detectStars( data: Data, properties: [ FITSPropertySnapshot ], using detector: any StarDetecting = MomentStarDetector() ) -> StarField?
    {
        guard let samples    = ImageProcessor.linearMonoSamples( data: data, properties: properties ),
              let dimensions = ImageProcessor.imageDimensions( from: properties ),
              let image      = try? GrayscaleImage( width: dimensions.width, height: dimensions.height, pixels: samples )
        else
        {
            return nil
        }

        return try? detector.detectStars( in: image )
    }
}
