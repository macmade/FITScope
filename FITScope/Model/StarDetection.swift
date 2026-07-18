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
import SwiftPixel

/// Runs SwiftAstro's star detection over a detection-ready image.
///
/// The detection-ready, single-channel linear buffer is produced at load time by
/// the format loaders (one-shot-colour frames demosaiced to luminance); this only
/// selects a detector and runs it. The entry point is `nonisolated` and
/// works on the `Sendable` ``SwiftPixel/PixelBuffer``, so a caller can run it off
/// the main actor.
public enum StarDetection
{
    /// Detects stars in a detection-ready image.
    ///
    /// - Parameters:
    ///   - image:    The detection-ready single-channel linear image, or `nil`
    ///               when none is available (detection is then skipped).
    ///   - detector: The detector to use; defaults to
    ///               ``MatchedFilterStarDetector``.
    /// - Returns: The detected stars and their aggregate metrics, or `nil` when
    ///   no image is given or detection fails.
    public static func detectStars( in image: PixelBuffer?, using detector: any StarDetecting = MatchedFilterStarDetector() ) -> StarField?
    {
        guard let image
        else
        {
            return nil
        }

        return try? detector.detectStars( in: image )
    }
}
