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
            // A hand-edited stretch is manual, so the app-managed "Auto engaged" mode
            // drops out — unless the change came from the managed re-derivation itself
            // (guarded by `isApplyingManagedStretch`), which stays engaged. `init` and
            // `reset()` re-seed `isAutoStretch` after their stretch assignment, so the
            // on-open / on-reset state is preserved regardless of this observer firing.
            if self.isApplyingManagedStretch == false
            {
                self.isAutoStretch = false
            }
        }
    }

    /// Whether the stretch is currently app-managed — the "Auto engaged" state.
    ///
    /// Set when the stretch is auto-derived (an image that opens auto-stretched, or the
    /// managed Auto toggle / mutual-exclusion re-derivation) and cleared the moment the
    /// user hand-edits the stretch. It is deliberately *not* part of ``settings``, so it
    /// never, on its own, makes ``hasAdjustments`` report the image as edited: an image
    /// that merely opened auto-stretched stays unedited until the user changes something.
    @Published public private( set ) var isAutoStretch = false

    /// Guards the managed re-derivation while it assigns ``stretch`` (and its
    /// normalization), so that assignment is not mistaken for a manual, hand-edited
    /// stretch and does not disengage ``isAutoStretch``.
    private var isApplyingManagedStretch = false

    /// Re-derives the auto Screen Transfer — the `{ normalize, stretch }` pair — from the
    /// image, off the main actor. `uniform` selects a single luminance mapping shared
    /// across every channel (the colour-preserving result that composes with white
    /// balance); `false` selects the colour-aware per-channel result. Returns `nil` when
    /// no derivation is possible (no image, or no detection buffer).
    ///
    /// Injected by the owning renderer, which holds the render source the model does not —
    /// the derivation itself lives in
    /// ``ImageRenderer/autoScreenTransferSettings(linking:shadowClipFactor:targetBackground:)``.
    /// Defaults to a no-op, so a model with no source (previews, or tests without a stub)
    /// simply never re-derives.
    public var deriveAutoStretch: ( _ uniform: Bool ) async -> ImageProcessor.Settings? = { _ in nil }

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

    /// The cosmetic-correction (hot/cold pixel repair) parameters, applied to the
    /// raw samples before the channel-forming stage. Enabled with conservative
    /// defaults, so isolated sensor defects are repaired when the image opens.
    @Published public var cosmeticCorrection: Processors.CosmeticCorrection.Parameters = .default

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

        self.baseline           = baseline
        self.opened             = opened
        self.normalize          = opened.normalize
        self.stretch            = opened.stretch
        self.whiteBalance       = opened.whiteBalance
        self.invert             = opened.invert
        self.brightness         = opened.brightness
        self.contrast           = opened.contrast
        self.levels             = opened.levels
        self.curves             = opened.curves
        self.colorBalance       = opened.colorBalance
        self.hue                = opened.hue
        self.saturation         = opened.saturation
        self.debayer            = opened.debayer
        self.debayerAlgorithm   = opened.debayerMode
        self.cosmeticCorrection = opened.cosmeticCorrection
        self.orientation        = opened.orientation

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

        self.normalize          = defaults.normalize
        self.stretch            = defaults.stretch
        self.whiteBalance       = defaults.whiteBalance
        self.invert             = defaults.invert
        self.brightness         = defaults.brightness
        self.contrast           = defaults.contrast
        self.levels             = defaults.levels
        self.curves             = defaults.curves
        self.colorBalance       = defaults.colorBalance
        self.hue                = defaults.hue
        self.saturation         = defaults.saturation
        self.debayer            = defaults.debayer
        self.debayerAlgorithm   = defaults.debayerAlgorithm
        self.cosmeticCorrection = defaults.cosmeticCorrection
        self.orientation        = defaults.orientation

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
            normalize:          self.normalize,
            stretch:            self.stretch,
            whiteBalance:       self.whiteBalance,
            invert:             self.invert,
            brightness:         self.brightness,
            contrast:           self.contrast,
            levels:             self.levels,
            curves:             self.curves,
            colorBalance:       self.colorBalance,
            hue:                self.hue,
            saturation:         self.saturation,
            debayer:            self.debayer,
            debayerMode:        self.debayerAlgorithm,
            cosmeticCorrection: self.cosmeticCorrection,
            orientation:        self.orientation
        )
    }

    // MARK: - Managed auto-stretch mutual exclusion

    /// How to resolve a ``PerChannelStretchRequest`` — the outcome the user picked in the
    /// white-balance-removal confirmation. Cancelling simply discards the request (nothing
    /// is applied), so it has no case here.
    public enum PerChannelStretchResolution: Sendable
    {
        /// Apply the per-channel Screen Transfer and turn white balance off, staying in
        /// managed mode — the clean exclusive result (the confirmation's default).
        case removeWhiteBalance

        /// Apply the per-channel Screen Transfer and keep white balance on, so the two
        /// coexist and the stretch drops to manual mode.
        case keepWhiteBalance
    }

    /// A pending request to engage a per-channel managed Screen Transfer that would
    /// collide with active white balance.
    ///
    /// Returned by ``requestPerChannelAutoStretch()`` so the control layer can present the
    /// white-balance-removal confirmation before anything is committed; the model applies
    /// nothing until the view calls ``resolve(_:as:)`` (or discards the request to cancel).
    /// The derived settings it carries are opaque to the view — it just hands the request
    /// back.
    public struct PerChannelStretchRequest: Sendable
    {
        /// The derived per-channel `{ normalize, stretch }` to apply once resolved.
        let settings: ImageProcessor.Settings
    }

    /// How to resolve a ``WhiteBalanceRequest`` — the outcome the user picked when adding
    /// white balance would collide with a hand-built per-channel stretch. Cancelling
    /// discards the request (white balance is not added), so it has no case here.
    public enum WhiteBalanceResolution: Sendable
    {
        /// Add white balance and re-derive the stretch as a managed uniform mapping, which
        /// composes with it — the clean result; the hand-built per-channel stretch is
        /// discarded.
        case convertStretchToUniform

        /// Add white balance and keep the hand-built per-channel stretch, so the two coexist
        /// in manual mode.
        case keepBoth
    }

    /// A pending request to add white balance that would collide with a hand-built
    /// per-channel stretch.
    ///
    /// Returned by ``setWhiteBalance(_:)`` so the control layer can confirm before anything
    /// is committed — converting a *hand-edited* per-channel stretch to uniform would lose
    /// that work, so unlike an auto stretch (which yields silently) it is not forced. The
    /// model applies nothing until the view calls ``resolve(_:as:)`` (or discards the
    /// request to cancel).
    public struct WhiteBalanceRequest: Sendable
    {
        /// The white-balance mode to add once resolved.
        let mode: Processors.WhiteBalance.Mode
    }

    /// Whether the current stretch is a per-channel (unlinked) Screen Transfer — the
    /// linking that is mutually exclusive with white balance while managed. A uniform or
    /// absent stretch composes with white balance and never collides.
    private var isPerChannelStretch: Bool
    {
        guard case .perChannel = self.stretch
        else
        {
            return false
        }

        return true
    }

    /// Disengages the managed "Auto engaged" mode, freezing the current stretch as a
    /// manual value. The stretch, its normalization and white balance are all left
    /// untouched, so the image is unchanged and re-engaging Auto simply re-derives.
    public func disengageAutoStretch()
    {
        self.isAutoStretch = false
    }

    /// Applies an app-derived `{ normalize, stretch }` and engages managed mode, without
    /// the assignment being treated as a manual edit — the guard around the ``stretch``
    /// write suppresses the observer that would otherwise disengage ``isAutoStretch``.
    ///
    /// - Parameter settings: The derived settings whose normalization and stretch to apply.
    /// - Returns: `true` when a stretch was applied; `false` when `settings` carried no
    ///            stretch, so nothing changed — the caller must not commit a state that
    ///            relies on the yield having happened.
    @discardableResult
    private func applyManagedStretch( _ settings: ImageProcessor.Settings ) -> Bool
    {
        guard let stretch = settings.stretch
        else
        {
            return false
        }

        self.isApplyingManagedStretch = true
        self.normalize                = settings.normalize
        self.stretch                  = stretch
        self.isApplyingManagedStretch = false
        self.isAutoStretch            = true

        return true
    }

    /// Enables or disables white balance, enforcing the mutual-exclusion rule symmetrically.
    ///
    /// A per-channel Screen Transfer and white balance both neutralize the colour cast, so
    /// they should not both be active. The rule converts silently when the affected stretch
    /// is *auto* (nothing is lost) and asks first when explicit user work would be lost:
    ///
    /// - **Enabling** white balance over a **managed per-channel** stretch: the stretch
    ///   yields silently to a uniform re-derive (which composes with white balance), and
    ///   white balance stays on. Returns `nil`.
    /// - **Enabling** white balance over a **hand-built (manual) per-channel** stretch:
    ///   converting it to uniform would discard that work, so nothing is committed and a
    ///   ``WhiteBalanceRequest`` is returned for the control layer to confirm.
    /// - **Disabling** white balance while a **managed uniform** stretch is active (one that
    ///   was forced uniform because white balance was on): the stretch is silently
    ///   re-derived back to per-channel, now that it no longer collides. Returns `nil`.
    /// - Any other case (uniform or absent stretch, manual mode, mono) simply sets the mode.
    ///
    /// The re-derives run off the main actor (see ``deriveAutoStretch``), so this is async.
    ///
    /// - Parameter mode: The white-balance mode to apply, or `nil` to turn it off.
    /// - Returns: A request to confirm when adding white balance would discard a hand-built
    ///            per-channel stretch, or `nil` when the change was applied directly.
    public func setWhiteBalance( _ mode: Processors.WhiteBalance.Mode? ) async -> WhiteBalanceRequest?
    {
        guard let mode
        else
        {
            // Disabling white balance.
            self.whiteBalance = nil

            // A managed stretch that was forced uniform (because white balance was on) is
            // re-derived back to per-channel now that it no longer collides — silently, since
            // it is auto. White balance is already off before the off-actor derive, so this
            // cannot commit a per-channel-plus-white-balance collision even under a
            // concurrent edit (last-write-wins is fine here).
            if self.isAutoStretch, self.isPerChannelStretch == false, self.stretch != nil, let perChannel = await self.deriveAutoStretch( false )
            {
                self.applyManagedStretch( perChannel )
            }

            return nil
        }

        guard self.isPerChannelStretch
        else
        {
            // A uniform or absent stretch composes with white balance — just set it.
            self.whiteBalance = mode

            return nil
        }

        guard self.isAutoStretch
        else
        {
            // A hand-built per-channel stretch: converting it to uniform would lose that
            // work, so confirm rather than force it silently.
            return WhiteBalanceRequest( mode: mode )
        }

        // Managed per-channel: the stretch yields silently to a uniform re-derive.
        guard let uniform = await self.deriveAutoStretch( true )
        else
        {
            // The yield cannot be produced (no source): refuse rather than commit a collision.
            return nil
        }

        // The off-actor derive suspended this method; main-actor work (e.g. a hand-edit
        // dropping to manual) may have run meanwhile. If the managed per-channel state no
        // longer holds, the collision is already gone — just set the mode, preserving that
        // concurrent edit rather than clobbering it with the now-stale yield.
        guard self.isAutoStretch, self.isPerChannelStretch
        else
        {
            self.whiteBalance = mode

            return nil
        }

        // Commit white balance only if the uniform stretch actually applied.
        guard self.applyManagedStretch( uniform )
        else
        {
            return nil
        }

        self.whiteBalance = mode

        return nil
    }

    /// Requests engaging a per-channel managed Screen Transfer (the colour-aware Auto).
    ///
    /// Derives the per-channel STF off the main actor. When it does not collide with white
    /// balance (white balance off), it is applied and managed mode is engaged directly,
    /// returning `nil`. When white balance is active the two cannot coexist while managed,
    /// so nothing is applied and a ``PerChannelStretchRequest`` is returned for the control
    /// layer to resolve through the white-balance-removal confirmation (see
    /// ``resolve(_:as:)``). Returns `nil` when no derivation is possible.
    ///
    /// - Returns: A request to resolve when white balance must be confirmed off, or `nil`
    ///            when the per-channel STF was applied directly or could not be derived.
    public func requestPerChannelAutoStretch() async -> PerChannelStretchRequest?
    {
        guard let settings = await self.deriveAutoStretch( false ), settings.stretch != nil
        else
        {
            return nil
        }

        guard self.whiteBalance != nil
        else
        {
            // No white balance to collide with: engage directly and silently. Unlike
            // `setWhiteBalance`, this deliberately does not re-check for a concurrent
            // stretch edit after the derive — engaging Auto is an explicit "make it
            // per-channel" command, so applying the derived STF (last-write-wins) is the
            // intended outcome.
            self.applyManagedStretch( settings )

            return nil
        }

        // White balance is active: commit nothing; hand the derived STF to the view to
        // confirm removing white balance first.
        return PerChannelStretchRequest( settings: settings )
    }

    /// Applies an already-derived managed Screen Transfer through the mutual-exclusion rule.
    ///
    /// Unlike ``requestPerChannelAutoStretch()``, which derives internally with the default
    /// parameters, the caller supplies the derived `{ normalize, stretch }` — the Screen
    /// Transfer editor uses this so its tunable Auto-Clip / Auto-Background feed the
    /// derivation. When a per-channel linking is requested while white balance is active the
    /// two collide: nothing is committed and a ``PerChannelStretchRequest`` is returned for
    /// the control layer to confirm. Otherwise (uniform, or white balance off) the stretch
    /// is applied and managed mode engaged. Returns `nil` when the settings carry no stretch.
    ///
    /// - Parameters:
    ///   - settings:   The derived `{ normalize, stretch }` to apply.
    ///   - perChannel: Whether the requested linking is per-channel (which excludes white
    ///                 balance while managed).
    /// - Returns: A request to resolve when white balance must be confirmed off, or `nil`
    ///            when the stretch was applied directly or could not be used.
    public func requestManagedStretch( _ settings: ImageProcessor.Settings, perChannel: Bool ) -> PerChannelStretchRequest?
    {
        guard settings.stretch != nil
        else
        {
            return nil
        }

        if perChannel, self.whiteBalance != nil
        {
            return PerChannelStretchRequest( settings: settings )
        }

        self.applyManagedStretch( settings )

        return nil
    }

    /// Commits a ``PerChannelStretchRequest`` the way the user resolved its white-balance
    /// collision.
    ///
    /// ``PerChannelStretchResolution/removeWhiteBalance`` applies the per-channel Screen
    /// Transfer and turns white balance off, staying in managed mode — the clean exclusive
    /// result. ``PerChannelStretchResolution/keepWhiteBalance`` applies it and leaves white
    /// balance on, so the two coexist and the stretch drops to manual mode. Cancelling is
    /// simply not calling this: the pending request is discarded and nothing changes.
    ///
    /// - Parameters:
    ///   - request:    The pending request from ``requestPerChannelAutoStretch()``.
    ///   - resolution: The outcome the user chose.
    public func resolve( _ request: PerChannelStretchRequest, as resolution: PerChannelStretchResolution )
    {
        switch resolution
        {
            case .removeWhiteBalance:

                self.applyManagedStretch( request.settings )

                self.whiteBalance = nil

            case .keepWhiteBalance:

                // Coexist and drop to manual: the direct stretch write disengages managed
                // mode through the observer, and white balance is left on.
                self.normalize = request.settings.normalize
                self.stretch   = request.settings.stretch
        }
    }

    /// Commits a ``WhiteBalanceRequest`` the way the user resolved the collision between
    /// adding white balance and a hand-built per-channel stretch.
    ///
    /// ``WhiteBalanceResolution/convertStretchToUniform`` re-derives the stretch as a managed
    /// uniform mapping and adds white balance — the clean result (the hand-built per-channel
    /// stretch is discarded). ``WhiteBalanceResolution/keepBoth`` adds white balance and
    /// keeps the per-channel stretch, so the two coexist in manual mode. Cancelling is simply
    /// not calling this: the request is discarded and white balance is not added.
    ///
    /// The re-derive runs off the main actor, so this is async.
    ///
    /// - Parameters:
    ///   - request:    The pending request from ``setWhiteBalance(_:)``.
    ///   - resolution: The outcome the user chose.
    public func resolve( _ request: WhiteBalanceRequest, as resolution: WhiteBalanceResolution ) async
    {
        switch resolution
        {
            case .convertStretchToUniform:

                // Add white balance only once the uniform re-derive actually applies, so a
                // hand-built per-channel stretch and white balance are never both committed.
                guard let uniform = await self.deriveAutoStretch( true ), self.applyManagedStretch( uniform )
                else
                {
                    return
                }

                self.whiteBalance = request.mode

            case .keepBoth:

                self.whiteBalance = request.mode
        }
    }
}
