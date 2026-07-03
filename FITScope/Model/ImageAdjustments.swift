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

import Combine
import SwiftPixel

/// The observable, user-tunable image-adjustment parameters that drive the
/// render pipeline.
///
/// The controls bind to these values; the renderer reads a `Sendable`
/// `ImageProcessor.Settings` snapshot from ``settings`` to build its pipeline
/// configuration. The defaults render the file as captured: a linear min/max
/// normalization so the data is visible, with no stretch, gamma or white
/// balance, and debayering applied only when the file is a colour-filter array.
@MainActor
public final class ImageAdjustments: ObservableObject
{
    /// How to normalize pixel values to the display range, or `nil` to skip
    /// normalization. Defaults to a linear min/max mapping, which the 8-bit
    /// conversion requires to make the data visible.
    @Published public var normalize: Processors.Normalize.Mode? = .minMax

    /// The non-linear stretch applied to bring out faint detail, or `nil` for a
    /// linear image. Off by default, so the image opens linear.
    @Published public var stretch: Processors.Stretch.Algorithm? = nil

    /// The gamma-correction exponent. Neutral (`1`) by default, which is the
    /// identity and leaves the image uncorrected — so gamma needs no separate
    /// on/off toggle.
    @Published public var gamma: Double = 1

    /// How to white-balance the colour channels, or `nil` to leave them
    /// untouched. Off by default.
    @Published public var whiteBalance: Processors.WhiteBalance.Mode? = nil

    /// Whether to invert the image (photographic negative). Off by default.
    @Published public var invert: Bool = false

    /// The additive brightness offset. Neutral (`0`) by default.
    @Published public var brightness: Double = 0

    /// The multiplicative contrast factor about the midpoint. Neutral (`1`) by
    /// default.
    @Published public var contrast: Double = 1

    /// The levels remap (input black/white, midtone gamma, output range),
    /// applied uniformly or per channel. An identity uniform mapping by default,
    /// so the image opens with no levels adjustment.
    @Published public var levels: Processors.Levels.Channels = .uniform( .identity )

    /// The tone curve (control points interpolated with a monotone cubic spline),
    /// applied uniformly or per channel. An identity curve by default, so the
    /// image opens with no curve adjustment.
    @Published public var curves: Processors.Curves.Channels = .uniform( .identity )

    /// The colour-saturation factor. Neutral (`1`) by default.
    @Published public var saturation: Double = 1

    /// How to debayer a colour-filter-array image into RGB.
    @Published public var debayer: ImageProcessor.DebayerSelection = .auto

    /// The demosaic algorithm used when debayering.
    @Published public var debayerAlgorithm: Processors.Debayer.Mode = .bilinear

    /// The net orientation (rotation + optional mirror) applied to the image.
    /// Identity by default, so the image opens as captured.
    @Published public var orientation: Processors.Orient.Orientation = .identity

    /// Creates an adjustment set seeded with the pipeline's default values.
    public init()
    {}

    /// Restores every adjustment to its default, rendering the file as captured.
    ///
    /// A single reset for the whole pipeline configuration, so the inspector's
    /// Reset View button and the *Image* menu share it rather than each
    /// duplicating the field-by-field copy. Values are copied from a fresh
    /// instance, so the reset tracks the defaults automatically and can never omit
    /// a field as it grows.
    public func reset()
    {
        let defaults = ImageAdjustments()

        self.normalize        = defaults.normalize
        self.stretch          = defaults.stretch
        self.gamma            = defaults.gamma
        self.whiteBalance     = defaults.whiteBalance
        self.invert           = defaults.invert
        self.brightness       = defaults.brightness
        self.contrast         = defaults.contrast
        self.levels           = defaults.levels
        self.curves           = defaults.curves
        self.saturation       = defaults.saturation
        self.debayer          = defaults.debayer
        self.debayerAlgorithm = defaults.debayerAlgorithm
        self.orientation      = defaults.orientation
    }

    /// Whether any adjustment deviates from the pipeline defaults, i.e. the image
    /// is no longer rendered exactly as captured.
    ///
    /// Compares the current ``settings`` snapshot to a default one rather than
    /// tracking a separate flag, so it can never drift out of sync with the
    /// individual values and automatically covers every field the settings
    /// encode. Drives the sidebar's "edited" marker.
    public var hasAdjustments: Bool
    {
        self.settings != ImageProcessor.Settings()
    }

    /// A `Sendable` snapshot of the current adjustments, safe to hand to the
    /// render pipeline across the concurrency boundary.
    public var settings: ImageProcessor.Settings
    {
        ImageProcessor.Settings(
            normalize:    self.normalize,
            stretch:      self.stretch,
            gamma:        self.gamma,
            whiteBalance: self.whiteBalance,
            invert:       self.invert,
            brightness:   self.brightness,
            contrast:     self.contrast,
            levels:       self.levels,
            curves:       self.curves,
            saturation:   self.saturation,
            debayer:      self.debayer,
            debayerMode:  self.debayerAlgorithm,
            orientation:  self.orientation
        )
    }
}
