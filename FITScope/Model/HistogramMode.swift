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

/// Which histogram channels are displayed: the per-channel RGB triple, a single
/// luminance curve, or a single mono curve for a monochrome image.
public enum HistogramMode: CaseIterable, CustomStringConvertible
{
    /// The per-channel red/green/blue histogram.
    case rgb

    /// The single-channel luminance histogram.
    case luminance

    /// The single-channel histogram of a monochrome image.
    case mono

    /// The picker label for the mode.
    public var description: String
    {
        switch self
        {
            case .rgb:       return "RGB"
            case .luminance: return "Luminance"
            case .mono:      return "Mono"
        }
    }

    /// The modes a histogram offers for an image, given whether it is monochrome:
    /// a single ``mono`` mode for mono images, or the RGB and luminance choice for
    /// colour images.
    ///
    /// - Parameter isMono: Whether the rendered image is monochrome.
    /// - Returns: The selectable modes, in display order.
    public static func availableModes( isMono: Bool ) -> [ HistogramMode ]
    {
        isMono ? [ .mono ] : [ .rgb, .luminance ]
    }

    /// Resolves the mode actually shown for an image, clamping a stored mode that
    /// no longer applies: a mono image is always shown in ``mono`` mode, and a
    /// stale ``mono`` selection carried over to a colour image falls back to
    /// ``rgb``.
    ///
    /// - Parameters:
    ///   - stored: The mode last selected by the user.
    ///   - isMono: Whether the rendered image is monochrome.
    /// - Returns: The mode to display.
    public static func effectiveMode( stored: HistogramMode, isMono: Bool ) -> HistogramMode
    {
        if isMono
        {
            return .mono
        }

        return stored == .mono ? .rgb : stored
    }
}
