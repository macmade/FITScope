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

import Combine
import SwiftPixel

/// The observable, user-tunable image-adjustment parameters that drive the
/// render pipeline.
///
/// The controls bind to these values; the renderer reads a `Sendable`
/// `ImageProcessor.Settings` snapshot from ``settings`` to build its pipeline
/// configuration. The defaults reproduce the pipeline's previously hard-coded
/// values, so the initial render is unchanged.
@MainActor
public final class ImageAdjustments: ObservableObject
{
    /// How to normalize pixel values to the display range, or `nil` to skip
    /// normalization.
    @Published public var normalize:    Processors.Normalize.Mode?      = .minMax

    /// The non-linear stretch applied to bring out faint detail, or `nil` for a
    /// linear image.
    @Published public var stretch:      Processors.Stretch.Algorithm?   = .log( 50 )

    /// The gamma-correction exponent, or `nil` to leave gamma uncorrected.
    @Published public var gamma:        Double?                         = 1.8

    /// How to white-balance the colour channels, or `nil` to leave them
    /// untouched.
    @Published public var whiteBalance: Processors.WhiteBalance.Mode?   = .auto

    /// How to debayer a colour-filter-array image into RGB.
    @Published public var debayer:      ImageProcessor.DebayerSelection = .auto

    /// Creates an adjustment set seeded with the pipeline's default values.
    public init()
    {}

    /// A `Sendable` snapshot of the current adjustments, safe to hand to the
    /// render pipeline across the concurrency boundary.
    public var settings: ImageProcessor.Settings
    {
        ImageProcessor.Settings(
            normalize:    self.normalize,
            stretch:      self.stretch,
            gamma:        self.gamma,
            whiteBalance: self.whiteBalance,
            debayer:      self.debayer
        )
    }
}
