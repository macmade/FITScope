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

/// Shared visual style for the canvas annotation overlays.
///
/// The overlays draw over the image, so their colours are kept semi-transparent
/// to read as annotations *layered over* the picture rather than sitting heavily
/// on top of it. Centralising the alpha here — instead of each overlay hard-coding
/// its own — keeps every overlay consistent and makes the balance adjustable in
/// one place.
public enum CanvasOverlayStyle
{
    /// The shared opacity for the annotation overlays (reticle, stars, objects,
    /// scale bar, north, and the equatorial grid's labels), so the image shows
    /// through while the annotation stays legible.
    public static let alpha: Double = 0.7

    /// The opacity for secondary, de-emphasised overlay elements — the equatorial
    /// grid's lines, which sit beneath its brighter labels. Expressed as a fixed
    /// fraction of ``alpha`` so both tiers track the single source of truth
    /// together.
    public static let secondaryAlpha: Double = alpha * 0.4
}
