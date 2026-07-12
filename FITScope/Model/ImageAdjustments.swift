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
    ///
    /// Any direct change here is treated as a manual, hand-edited stretch and
    /// disengages the managed ``isAutoStretch`` mode — a new curve, a mode change,
    /// or clearing the stretch all drop out of "Auto engaged".
    @Published public var stretch: Processors.Stretch.STFParameters? = nil
    {
        didSet
        {
            // A hand-edited stretch is manual, so the app-managed "Auto engaged"
            // mode drops out. `init` and `reset()` re-seed `isAutoStretch` after the
            // stretch assignment, so the on-open / on-reset state is preserved
            // regardless of this observer firing.
            self.isAutoStretch = false
        }
    }

    /// Whether the stretch is currently app-managed — the "Auto engaged" state.
    ///
    /// Set when the stretch is auto-derived (an image that opens auto-stretched;
    /// later, the managed Auto toggle) and cleared the moment the user hand-edits the
    /// stretch. It is deliberately *not* part of ``settings``, so it never, on its
    /// own, makes ``hasAdjustments`` report the image as edited: an image that merely
    /// opened auto-stretched stays unedited until the user changes something.
    @Published public private( set ) var isAutoStretch = false

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

    /// The unstretched "as captured" view the image resets to. ``reset()`` and the
    /// per-control resets return to it, and the before/after slider renders it as
    /// the "original". Defaults to the pipeline defaults (a linear min/max
    /// normalization), but a format whose samples are already display-ready (e.g. a
    /// photographic image) seeds a different baseline so the image opens as authored
    /// rather than range-stretched.
    ///
    /// This is deliberately *unstretched*: an auto-applied stretch on open (an auto
    /// Screen Transfer, or an XISF display function) is carried by ``opened``, not
    /// here, so it counts as an adjustment the user can reset away and compare
    /// against.
    public let baseline: ImageProcessor.Settings

    /// The state the image actually opened in — the ``baseline`` plus any stretch
    /// applied automatically on open (an auto Screen Transfer, or an XISF display
    /// function). Equal to ``baseline`` when the image opened unstretched.
    ///
    /// ``hasAdjustments`` compares against this rather than ``baseline``, so an image
    /// that merely opened auto-stretched is not reported as edited (no sidebar marker,
    /// no close-confirmation alert) until the user changes something — while
    /// ``reset()`` still returns to the unstretched ``baseline``.
    public let opened: ImageProcessor.Settings

    /// Creates an adjustment set seeded from a baseline and, optionally, a distinct
    /// opened state.
    ///
    /// The current values start at `opened` (the "as opened" view), while `baseline`
    /// is retained as the unstretched reset target. When `opened` is `nil`, the image
    /// opened exactly on its baseline (no auto-applied stretch), so the two coincide.
    ///
    /// - Parameters:
    ///   - baseline: The unstretched settings the image resets to. Defaults to the
    ///               pipeline defaults, which render the file as captured.
    ///   - opened:   The settings the image opened with, when it differs from the
    ///               baseline (an auto-applied stretch). Defaults to `nil` (opens on
    ///               the baseline).
    public init( baseline: ImageProcessor.Settings = ImageProcessor.Settings(), opened: ImageProcessor.Settings? = nil )
    {
        let opened = opened ?? baseline

        self.baseline         = baseline
        self.opened           = opened
        self.normalize        = opened.normalize
        self.stretch          = opened.stretch
        self.whiteBalance     = opened.whiteBalance
        self.invert           = opened.invert
        self.brightness       = opened.brightness
        self.contrast         = opened.contrast
        self.levels           = opened.levels
        self.curves           = opened.curves
        self.colorBalance     = opened.colorBalance
        self.hue              = opened.hue
        self.saturation       = opened.saturation
        self.debayer          = opened.debayer
        self.debayerAlgorithm = opened.debayerMode
        self.orientation      = opened.orientation

        // The image opened auto-stretched — and so starts "Auto engaged" — exactly
        // when its opened state carries a stretch (the baseline is always unstretched,
        // so a stretch in `opened` is an auto-applied one). The `stretch` observer does
        // not run for the assignments above — property observers do not fire during a
        // type's own initializer — so this is a plain seed, not a re-derivation.
        self.isAutoStretch = opened.stretch != nil
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

        // Track the baseline like every other field: reset returns to the unstretched
        // baseline, which is never auto-stretched. Set last so it wins over the
        // `stretch` observer that the assignment above triggered.
        self.isAutoStretch = defaults.isAutoStretch
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

    /// Whether the user has changed any adjustment from the state the image opened
    /// in, i.e. the image is no longer rendered exactly as it opened.
    ///
    /// Compares the current ``settings`` snapshot to ``opened`` rather than
    /// ``baseline``, so an image that opened auto-stretched (an auto Screen Transfer,
    /// or an XISF display function) is *not* flagged as edited on open — only a
    /// genuine user change makes it dirty. Compares the whole snapshot rather than
    /// tracking a separate flag, so it can never drift out of sync with the individual
    /// values and automatically covers every field the settings encode. Drives the
    /// sidebar's "edited" marker and the close/trash confirmation.
    public var hasAdjustments: Bool
    {
        self.settings != self.opened
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
