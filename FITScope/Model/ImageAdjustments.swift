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
    @Published public var stretch: Processors.Stretch.STFParameters? = nil

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

    /// The tonal-range colour balance (per-channel shifts for shadows, midtones
    /// and highlights). Neutral by default.
    @Published public var colorBalance: Processors.ColorBalance.Ranges = .identity

    /// The hue-rotation angle in degrees. Neutral (`0`) by default.
    @Published public var hue: Double = 0

    /// The colour-saturation factor. Neutral (`1`) by default.
    @Published public var saturation: Double = 1

    /// How to debayer a colour-filter-array image into RGB.
    @Published public var debayer: ImageProcessor.DebayerSelection = .auto

    /// The demosaic algorithm used when debayering.
    @Published public var debayerAlgorithm: Processors.Debayer.Mode = .bilinear

    /// The net orientation (rotation + optional mirror) applied to the image.
    /// Identity by default, so the image opens as captured.
    @Published public var orientation: Processors.Orient.Orientation = .identity

    /// The baseline the image opens on — its "as captured" view. ``reset()``
    /// returns to it and ``hasAdjustments`` compares against it. Defaults to the
    /// pipeline defaults (a linear min/max normalization), but a format whose
    /// samples are already display-ready (e.g. a photographic image) seeds a
    /// different baseline so the image opens as authored rather than
    /// range-stretched.
    public let baseline: ImageProcessor.Settings

    /// Creates an adjustment set seeded from a baseline.
    ///
    /// - Parameter baseline: The settings the image opens on. Defaults to the
    ///                       pipeline defaults, which render the file as captured.
    public init( baseline: ImageProcessor.Settings = ImageProcessor.Settings() )
    {
        self.baseline         = baseline
        self.normalize        = baseline.normalize
        self.stretch          = baseline.stretch
        self.whiteBalance     = baseline.whiteBalance
        self.invert           = baseline.invert
        self.brightness       = baseline.brightness
        self.contrast         = baseline.contrast
        self.levels           = baseline.levels
        self.curves           = baseline.curves
        self.colorBalance     = baseline.colorBalance
        self.hue              = baseline.hue
        self.saturation       = baseline.saturation
        self.debayer          = baseline.debayer
        self.debayerAlgorithm = baseline.debayerMode
        self.orientation      = baseline.orientation
    }

    /// Restores every adjustment to the image's baseline, rendering the file as
    /// captured.
    ///
    /// A single reset for the whole pipeline configuration, so the inspector's
    /// Reset View button and the *Image* menu share it rather than each
    /// duplicating the field-by-field copy. Values are copied from a fresh
    /// instance seeded with the same baseline, so the reset tracks the baseline
    /// automatically and can never omit a field as it grows.
    public func reset()
    {
        let defaults = ImageAdjustments( baseline: self.baseline )

        self.normalize        = defaults.normalize
        self.stretch          = defaults.stretch
        self.whiteBalance     = defaults.whiteBalance
        self.invert           = defaults.invert
        self.brightness       = defaults.brightness
        self.contrast         = defaults.contrast
        self.levels           = defaults.levels
        self.curves           = defaults.curves
        self.colorBalance     = defaults.colorBalance
        self.hue              = defaults.hue
        self.saturation       = defaults.saturation
        self.debayer          = defaults.debayer
        self.debayerAlgorithm = defaults.debayerAlgorithm
        self.orientation      = defaults.orientation
    }

    /// Whether the value at `keyPath` differs from the image's baseline, driving
    /// the visibility of a single control's reset affordance.
    ///
    /// - Parameter keyPath: The adjustment field to test.
    /// - Returns: `true` when the field has been changed from the baseline.
    public func isModified< Value: Equatable >( _ keyPath: KeyPath< ImageAdjustments, Value > ) -> Bool
    {
        self[ keyPath: keyPath ] != ImageAdjustments( baseline: self.baseline )[ keyPath: keyPath ]
    }

    /// Resets the value at `keyPath` to the image's baseline, so one control can be
    /// reset without resetting the whole view. The other fields are left untouched.
    ///
    /// The baseline value is read from a fresh instance seeded with the same
    /// baseline, the same single source of truth ``reset()`` and
    /// ``hasAdjustments`` use, so it can never drift from the baseline.
    ///
    /// - Parameter keyPath: The adjustment field to reset.
    public func reset< Value >( _ keyPath: ReferenceWritableKeyPath< ImageAdjustments, Value > )
    {
        self[ keyPath: keyPath ] = ImageAdjustments( baseline: self.baseline )[ keyPath: keyPath ]
    }

    /// Whether any adjustment deviates from the image's baseline, i.e. the image
    /// is no longer rendered exactly as captured.
    ///
    /// Compares the current ``settings`` snapshot to the baseline rather than
    /// tracking a separate flag, so it can never drift out of sync with the
    /// individual values and automatically covers every field the settings
    /// encode. Drives the sidebar's "edited" marker.
    public var hasAdjustments: Bool
    {
        self.settings != self.baseline
    }

    /// A `Sendable` snapshot of the current adjustments, safe to hand to the
    /// render pipeline across the concurrency boundary.
    public var settings: ImageProcessor.Settings
    {
        ImageProcessor.Settings(
            normalize:    self.normalize,
            stretch:      self.stretch,
            whiteBalance: self.whiteBalance,
            invert:       self.invert,
            brightness:   self.brightness,
            contrast:     self.contrast,
            levels:       self.levels,
            curves:       self.curves,
            colorBalance: self.colorBalance,
            hue:          self.hue,
            saturation:   self.saturation,
            debayer:      self.debayer,
            debayerMode:  self.debayerAlgorithm,
            orientation:  self.orientation
        )
    }
}
