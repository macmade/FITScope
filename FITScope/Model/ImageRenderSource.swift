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
import SwiftPixel

/// The renderable source of an image, decoupling ``ImageRenderer`` from any file
/// format: the renderer drives the pixel pipeline, computes histograms and manages
/// re-rendering through this protocol without knowing whether the pixels came from
/// FITS, XISF, or a photographic format.
///
/// A `Sendable` value so it can cross the render concurrency boundary without
/// sharing a format's non-`Sendable` parsed file.
public protocol ImageRenderSource: Sendable
{
    /// Renders the source with the given user settings, producing the display
    /// image plus the bytes and pixel formats the histogram stages consume. Pure,
    /// so it runs off the main actor.
    ///
    /// - Parameter settings: The user-tunable render settings to apply.
    /// - Returns: The render result.
    /// - Throws: Any error thrown while decoding or running the pipeline.
    func makeResult( settings: ImageProcessor.Settings ) throws -> ImageProcessor.RenderResult

    /// The decoded sample value(s) at source-image coordinates `(x, y)`, for the
    /// cursor read-out: one value for a single-channel source, or one per channel
    /// (red, green, blue) for a colour source, or `nil` for out-of-bounds
    /// coordinates or a source that exposes no per-pixel values.
    ///
    /// - Parameters:
    ///   - x: The zero-based column, left to right.
    ///   - y: The zero-based row, top to bottom.
    /// - Returns: The decoded per-channel values, or `nil`.
    func pixelValues( atX x: Int, y: Int ) -> [ ImageProcessor.PixelValue ]?

    /// The source image's pixel dimensions, or `nil` when they cannot be
    /// determined. Used to map a display coordinate back to source space under a
    /// non-identity orientation.
    var dimensions: ( width: Int, height: Int )? { get }

    /// The detection-ready single-channel linear image for star detection and the
    /// sky-background measurement, or `nil` when none is available.
    var detectionImage: PixelBuffer? { get }

    /// The format's full-scale maximum — the value the render scales samples into
    /// the native `[0, 1]` domain by — or `nil` when the format has no fixed full
    /// scale (a photographic or floating-point source).
    ///
    /// It lets a live auto Screen Transfer be derived in the *same* full-scale
    /// domain the auto-stretch-on-open path uses, so clicking "Auto" reproduces
    /// what opening the image did, rather than deriving in the min/max domain and
    /// producing a different (brighter) result.
    var fullScale: Double? { get }

    /// The colour data an auto Screen Transfer derives from — a colour source's
    /// per-channel input (a raw mosaic or co-located channels) or a mono source's
    /// single luminance channel — or `nil` when the source exposes no derivation
    /// input.
    ///
    /// The single place each format declares whether its auto-STF is per-channel
    /// (colour) or uniform (mono). The default reduces the source to its mono
    /// ``detectionImage``; a colour source overrides it to expose the per-channel
    /// input, so the shared derivation
    /// (``ImageProcessor/autoStretchSettings(colorSource:fullScale:shadowClipFactor:targetBackground:)``)
    /// produces a per-channel STF for it.
    var autoStretchColorSource: ImageProcessor.AutoStretchColorSource? { get }
}

public extension ImageRenderSource
{
    /// The default derivation input: the source's single-channel ``detectionImage``
    /// reduced to a uniform (linked) STF. A colour source overrides this to expose
    /// its per-channel input.
    var autoStretchColorSource: ImageProcessor.AutoStretchColorSource?
    {
        self.detectionImage.map { .mono( $0 ) }
    }

    /// The auto Screen Transfer settings for this source — per-channel for a colour
    /// source, uniform for a mono one — in the native full-scale `[0, 1]` domain.
    ///
    /// The single entry every consumer reaches so opening the image, the inspector's
    /// Auto and the Screen Transfer editor's Auto all agree. It resolves the source's
    /// ``autoStretchColorSource`` through the shared
    /// ``ImageProcessor/autoStretchSettings(colorSource:fullScale:shadowClipFactor:targetBackground:)``.
    /// Returns `nil` for a source without a fixed ``fullScale`` (a photographic or
    /// floating-point one); such a source is stretched over the min/max domain by the
    /// caller instead.
    ///
    /// - Parameters:
    ///   - shadowClipFactor: How many median-absolute-deviations below the median to
    ///                       clip the shadows. Defaults to `2.8`.
    ///   - targetBackground: The value the median should map to. Defaults to `0.25`.
    /// - Returns: The `{ normalize: .identity, stretch: <auto STF> }` settings, or
    ///   `nil` when the source has no fixed full scale or the derivation fails.
    func autoStretchSettings( shadowClipFactor: Double = 2.8, targetBackground: Double = 0.25 ) -> ImageProcessor.Settings?
    {
        guard let fullScale = self.fullScale
        else
        {
            return nil
        }

        return ImageProcessor.autoStretchSettings( colorSource: self.autoStretchColorSource, fullScale: fullScale, shadowClipFactor: shadowClipFactor, targetBackground: targetBackground )
    }
}
