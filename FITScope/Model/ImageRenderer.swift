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

import SwiftPixel
import SwiftUI
import SwiftUtilities

/// Renders an image (via its ``ImageRenderSource``) into a displayable image with histograms, applying
/// the user's ``ImageAdjustments`` and re-rendering on demand.
///
/// Rendering runs off the main actor and is generation-guarded so that rapid
/// re-renders (e.g. during a slider drag) cannot commit stale results. A failed
/// render keeps the last good image so controls stay usable while the user
/// adjusts away from a bad parameter.
@MainActor
public class ImageRenderer: ObservableObject
{
    /// The output of a successful render: the image plus its histograms and
    /// statistics.
    public struct Result
    {
        /// The rendered, display-ready image.
        public let image: CGImage

        /// The RGB and luminance histograms of the rendered pixels.
        public let histogram: Histogram

        /// Per-channel statistics derived from the histograms.
        public let statistics: HistogramStatistics

        /// The orientation applied to produce ``image``. Annotations registered to
        /// source space (such as the detected-star overlay) read it so they track
        /// the displayed image and only reorient once a re-render commits — never
        /// jumping ahead of the image while a rotation is still rendering.
        public let orientation: Processors.Orient.Orientation
    }

    /// The histograms computed from a rendered image.
    ///
    /// Equality is by a per-instance identity, **not** by the bin contents. The
    /// bin arrays are large, and a value-based `==` makes SwiftUI's view-graph
    /// diffing deep-compare them on the main thread on every update — the cause
    /// of a beachball when switching between already-rendered images. Because the
    /// wrapper itself is `Equatable`, SwiftUI uses this cheap `==` and never
    /// recurses into the `SwiftPixel.Histogram` bins. Each render produces a new
    /// histogram with a new identity, so a genuinely new result still compares
    /// unequal and refreshes the views.
    public struct Histogram: Equatable
    {
        /// A per-instance identity used for cheap equality.
        public let id = UUID()

        /// The per-channel (red, green, blue) histogram.
        public let rgb: SwiftPixel.Histogram

        /// The single-channel luminance histogram.
        public let luminance: SwiftPixel.Histogram

        /// The single-channel histogram of the rendered first channel, shown for
        /// monochrome images in place of the redundant RGB triple.
        public let mono: SwiftPixel.Histogram

        /// Whether the source image was monochrome (a mono input format). The
        /// pipeline always emits a 3-channel buffer (a colour-filter-array image is
        /// demosaiced to RGB, anything else is replicated from one channel to RGB),
        /// so this can't be read back from the channel count — it records whether
        /// the source was monochrome, not whether debayering ran. When `true`, the
        /// inspector presents ``mono`` rather than ``rgb``/``luminance``.
        public let isMono: Bool

        public static func == ( lhs: Histogram, rhs: Histogram ) -> Bool
        {
            lhs.id == rhs.id
        }
    }

    /// Summary statistics for each histogram channel.
    public struct HistogramStatistics
    {
        /// Statistics for the red channel.
        public let red: SwiftPixel.HistogramStatistics

        /// Statistics for the green channel.
        public let green: SwiftPixel.HistogramStatistics

        /// Statistics for the blue channel.
        public let blue: SwiftPixel.HistogramStatistics

        /// Statistics for the luminance channel.
        public let luminance: SwiftPixel.HistogramStatistics

        /// Statistics for the single (mono) channel, shown for monochrome images.
        public let mono: SwiftPixel.HistogramStatistics
    }

    /// A histogram paired with its statistics, used to retain the original,
    /// unprocessed image's distribution alongside the live processed result.
    public struct HistogramSet
    {
        /// The RGB and luminance histograms.
        public let histogram: Histogram

        /// Per-channel statistics derived from the histograms.
        public let statistics: HistogramStatistics
    }

    /// The most recent successful render, or `nil` before the first render.
    /// Retained across a subsequent failure.
    @Published public private( set ) var result: Result?

    /// The histogram of the original image — the file as captured, debayered if
    /// necessary, with no stretch, gamma or white balance — computed once on the
    /// first render and cached for the file's lifetime, or `nil` before then.
    @Published public private( set ) var original: HistogramSet?

    /// The "before" image for the before/after comparison: the file as captured
    /// (default adjustments — the same linear, unstretched view the histogram's
    /// ``original`` describes) rendered at the *current* orientation so it stays
    /// registered pixel-for-pixel with the processed ``result``. Captured eagerly
    /// as part of ``render()`` — reusing the original already rendered for the
    /// histogram — so the comparison is ready the moment the image displays; `nil`
    /// only until the first render commits. A later orientation change re-renders it
    /// within the same ``render()`` pass, so it always tracks the result.
    @Published public private( set ) var originalImage: CGImage?

    /// The orientation ``originalImage`` was rendered at, so ``render()`` can tell an
    /// orientation change (a rotate or flip) — which must re-render the before image
    /// to keep it registered with the processed result — from an unchanged
    /// orientation, which reuses the captured image.
    private var originalImageOrientation: Processors.Orient.Orientation?

    /// The error from the most recent failed render, or `nil` on success.
    @Published public private( set ) var error: Error?

    /// Whether a render is currently in flight — set when a render claims its
    /// generation and cleared when the latest generation commits. Stays set
    /// across a re-render even though the previous result is retained, so the UI
    /// can show a processing state (sidebar spinner, status pill, disabled
    /// controls, canvas overlay) for every render, not just the first.
    @Published public private( set ) var isRendering = false

    /// The user-tunable adjustments driving the render. Bind controls to these
    /// and call ``scheduleReRender()`` to apply changes. Seeded with the render's
    /// baseline so the image opens on its as-captured view.
    public let adjustments: ImageAdjustments

    /// How long to coalesce rapid re-render requests before rendering.
    private static let reRenderDebounce = Duration.milliseconds( 150 )

    /// The render source, or the error captured while extracting it from the
    /// file. Stored as a `Result` so an extraction failure surfaces at render
    /// time rather than at construction.
    private let source: Swift.Result< any ImageRenderSource, any Error >

    /// The in-flight debounced re-render, cancelled when a newer one is
    /// scheduled.
    private( set ) var pendingRender: Task< Void, Never >?

    /// Monotonic render counter. Each ``render()`` claims the next value at
    /// start; only the most recently claimed render may commit its outcome.
    private var currentRenderGeneration = 0

    /// Creates a renderer from a render source or the error captured while
    /// extracting it.
    ///
    /// - Parameters:
    ///   - source:   The render source, or the extraction failure.
    ///   - defaults: The unstretched baseline the image resets to. Defaults to the
    ///               pipeline defaults (a linear min/max normalization); a format
    ///               whose samples are already display-ready seeds a different
    ///               baseline so the image resets to its authored view.
    ///   - opened:   The state the image opens in, when it differs from the baseline
    ///               (a stretch applied automatically on open). Defaults to `nil`, so
    ///               the image opens on its baseline.
    public init( source: Swift.Result< any ImageRenderSource, any Error >, defaults: ImageProcessor.Settings = ImageProcessor.Settings(), opened: ImageProcessor.Settings? = nil )
    {
        self.source      = source
        self.adjustments = ImageAdjustments( baseline: defaults, opened: opened )

        // Give the model the phone line to the derivation it cannot run itself (it holds
        // no source): re-derive the auto Screen Transfer at a uniform or per-channel
        // linking, off the main actor, for the managed mutual-exclusion rule.
        self.adjustments.deriveAutoStretch = { [ weak self ] uniform in

            await self?.autoScreenTransferSettings( linking: uniform ? .uniform : .automatic )
        }
    }

    /// Creates a renderer from an already-extracted render source.
    ///
    /// - Parameters:
    ///   - source:   The render source.
    ///   - defaults: The unstretched baseline the image resets to. Defaults to the
    ///               pipeline defaults.
    ///   - opened:   The state the image opens in, when it differs from the baseline.
    ///               Defaults to `nil`.
    public convenience init( source: any ImageRenderSource, defaults: ImageProcessor.Settings = ImageProcessor.Settings(), opened: ImageProcessor.Settings? = nil )
    {
        self.init( source: .success( source ), defaults: defaults, opened: opened )
    }

    /// Whether an auto Screen Transfer Function can be derived — that is, whether
    /// the source extracted and exposes a detection image. A cheap check the UI can
    /// call every render to enable or disable the Auto action, without running the
    /// derivation.
    public var canAutoScreenTransfer: Bool
    {
        ( try? self.source.get() )?.detectionImage != nil
    }

    /// How an auto Screen Transfer chooses between a linked (uniform) and an unlinked
    /// (per-channel) result.
    public enum ScreenTransferLinking: Sendable
    {
        /// Per-channel (unlinked) for a colour source and uniform for a mono one —
        /// reproducing exactly how the image opened. The inspector's one-click Auto
        /// uses this so opening and clicking Auto agree.
        case automatic

        /// A single uniform (linked) mapping applied to every channel, derived from
        /// the luminance regardless of whether the source is colour — the
        /// colour-preserving "uniform Auto" the Screen Transfer editor offers when its
        /// per-channel toggle is off.
        case uniform
    }

    /// Derives auto Screen Transfer settings from the source, as the `{ normalize,
    /// stretch }` pair to apply as a whole.
    ///
    /// The `linking` mode chooses the shape of the result. ``ScreenTransferLinking/automatic``
    /// routes through the source's per-channel capability
    /// (``ImageRenderSource/autoStretchSettings(shadowClipFactor:targetBackground:)``):
    /// a colour source yields a per-channel (unlinked) STF and a mono source a uniform
    /// one, *exactly* the auto-stretch-on-open result, so clicking Auto reproduces how
    /// the image opened. ``ScreenTransferLinking/uniform`` instead derives a single
    /// uniform mapping from the ``ImageRenderSource/detectionImage`` luminance even for
    /// a colour source, preserving the colour ratios. Returns `nil` when the source
    /// failed to extract or exposes no detection image.
    ///
    /// **Domain.** The STF is derived — and returned to be applied — in the source's
    /// own domain, matching the on-open path so it is not brighter than opening the
    /// image: the native full-scale `[0, 1]` domain over ``Processors/Normalize/Mode/identity``
    /// when the source has a known ``ImageRenderSource/fullScale`` (an integer FITS /
    /// XISF / RAW), or the ``Processors/Normalize/Mode/minMax`` domain otherwise (a
    /// floating-point format, or a RAW with no white level). The `linking` shape is
    /// independent of the domain — a colour source derives per-channel in either.
    /// Returning the normalization alongside the stretch keeps the derivation domain
    /// and the apply domain in step; the caller applies both.
    ///
    /// The derivation is an `O(n log n)` pass (a normalize plus a median and a
    /// median-absolute-deviation) over the full-resolution source data, so it runs on a
    /// detached task off the main actor — matching how ``render()`` offloads its pixel
    /// work — and the caller `await`s the result. Gate the UI (e.g. a busy state)
    /// around the call, and check ``canAutoScreenTransfer`` first to avoid enabling an
    /// action that would return `nil`.
    ///
    /// - Parameters:
    ///   - linking:          Whether to derive an ``ScreenTransferLinking/automatic``
    ///                       (per-channel for colour) or a ``ScreenTransferLinking/uniform``
    ///                       result. Defaults to ``ScreenTransferLinking/automatic``.
    ///   - shadowClipFactor: How many median-absolute-deviations below the median
    ///                       to clip the shadows. Defaults to `2.8`.
    ///   - targetBackground: The value the median should map to. Defaults to `0.25`.
    /// - Returns: The `{ normalize, stretch }` settings to apply, or `nil` when
    ///   unavailable.
    public func autoScreenTransferSettings( linking: ScreenTransferLinking = .automatic, shadowClipFactor: Double = 2.8, targetBackground: Double = 0.25 ) async -> ImageProcessor.Settings?
    {
        guard let source = try? self.source.get(), let detection = source.detectionImage
        else
        {
            return nil
        }

        return await Task.detached
        {
            switch linking
            {
                case .automatic:

                    // Colour-aware: per-channel for a colour source, uniform for a mono
                    // one, in the source's own domain (full-scale or min/max) — exactly
                    // the auto-stretch-on-open derivation, so open == click-Auto.
                    return source.autoStretchSettings( shadowClipFactor: shadowClipFactor, targetBackground: targetBackground )

                case .uniform:

                    // A single luminance-derived uniform mapping, preserving the colour
                    // ratios even for a colour source, in the same domain.
                    return ImageProcessor.autoStretchSettings( colorSource: .mono( detection ), domain: source.autoStretchDomain, shadowClipFactor: shadowClipFactor, targetBackground: targetBackground )
            }
        }
        .value
    }

    /// Renders the image with the current adjustments and commits the result.
    ///
    /// The pixel work and histogram/statistics computation run on a background
    /// queue; the outcome is committed through ``commit(_:generation:)`` so a
    /// render superseded by a newer one cannot overwrite it.
    public func render() async
    {
        let generation = self.nextRenderGeneration()

        do
        {
            let source         = try self.source.get()
            let settings       = self.adjustments.settings

            // The unstretched "as captured" baseline the image resets to and the
            // before/after slider shows as the "original": for most formats the linear
            // min/max default, but a photographic image resets to its authored view, so
            // the baseline is captured here rather than assuming the pipeline default.
            // (An auto-applied stretch on open lives in the current settings, not here.)
            // Captured as an immutable value; the background render applies the current
            // orientation to a copy so the before/after image registers with the
            // processed result.
            let baseline = self.adjustments.baseline

            // The histogram's original is orientation-independent, so it is computed
            // once. The before/after image must match the *current* orientation to
            // register with the processed result, so it is re-rendered whenever the
            // orientation changes — but both come from the one original render below.
            let needsHistogram = self.original == nil
            let needsImage     = self.originalImage == nil || self.originalImageOrientation != settings.orientation
            let needsOriginal  = needsHistogram || needsImage

            let outcome = try await withCheckedThrowingContinuation
            {
                ( continuation: CheckedContinuation< ( result: Result, original: Result? ), any Error > ) in

                DispatchQueue.global( qos: .userInitiated ).async
                {
                    do
                    {
                        // The original is the file as captured: a render with the
                        // image's baseline settings, but the current orientation, so
                        // its image registers pixel-for-pixel with the processed
                        // result for the before/after comparison.
                        var originalSettings         = baseline
                        originalSettings.orientation = settings.orientation

                        let result   = try Self.makeResult( from: source, settings: settings )
                        let original = needsOriginal ? try Self.makeResult( from: source, settings: originalSettings ) : nil

                        continuation.resume( returning: ( result, original ) )
                    }
                    catch
                    {
                        continuation.resume( throwing: error )
                    }
                }
            }

            if let original = outcome.original
            {
                if needsHistogram
                {
                    self.original = HistogramSet( histogram: original.histogram, statistics: original.statistics )
                }

                // Capture the "before" image eagerly, as part of this render — at
                // load and again whenever the orientation changes — so the
                // comparison is always ready the moment the image displays, with no
                // lazy render when it is entered.
                self.originalImage            = original.image
                self.originalImageOrientation = settings.orientation
            }

            self.commit( .success( outcome.result ), generation: generation )
        }
        catch
        {
            self.commit( .failure( error ), generation: generation )
        }
    }

    /// Renders the image with the given settings and computes its histograms and
    /// statistics. Pure and `nonisolated` so it can run off the main actor.
    ///
    /// - Parameters:
    ///   - producer: The source or pre-decoded frame to render.
    ///   - settings: The render settings to apply.
    /// - Returns: The rendered image with its histograms and statistics.
    /// - Throws: Any error thrown by the pixel pipeline.
    private nonisolated static func makeResult( from producer: any RenderResultProducing, settings: ImageProcessor.Settings ) throws -> Result
    {
        let render             = try producer.makeResult( settings: settings )
        let channels           = render.outputPixelFormat.channels
        let rgbHistogram       = Benchmark.run( label: "Histogram (RGB)", output: Benchmarking.log ) { SwiftPixel.Histogram( bytes: render.bytes, channels: channels, mode: .rgb ) }
        let luminanceHistogram = Benchmark.run( label: "Histogram (L)",   output: Benchmarking.log ) { SwiftPixel.Histogram( bytes: render.bytes, channels: channels, mode: .luminance ) }
        let monoHistogram      = Benchmark.run( label: "Histogram (Mono)", output: Benchmarking.log ) { SwiftPixel.Histogram( bytes: render.bytes, channels: channels, mode: .mono ) }
        let histogram          = Histogram( rgb: rgbHistogram, luminance: luminanceHistogram, mono: monoHistogram, isMono: render.inputPixelFormat == .mono )
        let statistics         = HistogramStatistics(
            red:       Benchmark.run( label: "Statistics (R)", output: Benchmarking.log ) { SwiftPixel.HistogramStatistics( data: rgbHistogram.data[ 0 ] ) },
            green:     Benchmark.run( label: "Statistics (G)", output: Benchmarking.log ) { SwiftPixel.HistogramStatistics( data: rgbHistogram.data[ 1 ] ) },
            blue:      Benchmark.run( label: "Statistics (B)", output: Benchmarking.log ) { SwiftPixel.HistogramStatistics( data: rgbHistogram.data[ 2 ] ) },
            luminance: Benchmark.run( label: "Statistics (L)", output: Benchmarking.log ) { SwiftPixel.HistogramStatistics( data: luminanceHistogram.data[ 0 ] ) },
            mono:      Benchmark.run( label: "Statistics (Mono)", output: Benchmarking.log ) { SwiftPixel.HistogramStatistics( data: monoHistogram.data[ 0 ] ) }
        )

        return Result( image: render.image, histogram: histogram, statistics: statistics, orientation: settings.orientation )
    }

    /// Claims and returns the next render generation. Only the most recently
    /// claimed generation may ``commit(_:generation:)`` its outcome; earlier
    /// in-flight renders are superseded.
    ///
    /// Claiming a generation marks the renderer as in flight (``isRendering``);
    /// the matching ``commit(_:generation:)`` clears it.
    func nextRenderGeneration() -> Int
    {
        self.currentRenderGeneration += 1
        self.isRendering              = true

        return self.currentRenderGeneration
    }

    /// Commits a render outcome, but only while its generation is still the
    /// latest, so a superseded render — success or failure — cannot overwrite a
    /// newer result or resurrect a cleared error.
    ///
    /// On success the result is set and the error cleared; on failure the error
    /// is set and the last good result retained, so the image and its controls
    /// survive a bad parameter while the user adjusts away from it.
    func commit( _ outcome: Swift.Result< Result, any Error >, generation: Int )
    {
        guard generation == self.currentRenderGeneration
        else
        {
            return
        }

        switch outcome
        {
            case .success( let result ):
                self.result = result
                self.error  = nil

            case .failure( let error ):
                self.error = error
        }

        // The latest render has committed, so nothing is in flight. A superseded
        // generation returns above without clearing the flag, so a newer render
        // still in progress keeps the processing state shown.
        self.isRendering = false
    }

    /// Re-renders the image with the current adjustments, debounced to coalesce
    /// rapid changes such as a slider drag. Any pending re-render is cancelled
    /// first, so only the latest settings are applied.
    public func scheduleReRender()
    {
        self.pendingRender?.cancel()
        self.pendingRender = Task
        {
            [ weak self ] in

            try? await Task.sleep( for: Self.reRenderDebounce )

            guard Task.isCancelled == false
            else
            {
                return
            }

            await self?.render()
        }
    }

    /// Returns the render source for read-only uses such as decoding the raw value
    /// under the cursor, or reaching the detection image for star detection.
    ///
    /// - Returns: The render source.
    /// - Throws: The extraction error captured at construction, if any.
    public func renderSourceSnapshot() throws -> any ImageRenderSource
    {
        try self.source.get()
    }
}
