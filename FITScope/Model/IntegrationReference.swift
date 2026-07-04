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

/// The baseline the session's relative-SNR figures are compared against.
///
/// The relative SNR, gain and noise are all *relative*, so they need a reference:
/// either a single sub-frame (answering "what did stacking gain me?", so `N` equal
/// frames read as `√N`), or a target integration in whole hours (answering "how far
/// am I toward my goal?").
public enum IntegrationReference: Equatable, Hashable, Sendable
{
    /// A single sub-frame — the session reads as `√N` for `N` equal frames.
    case singleFrame

    /// A target integration, in whole hours.
    case hours( Int )

    /// The target-hour options offered in the reference picker, doubling from one
    /// hour.
    public static let hourOptions = [ 1, 2, 4, 8, 16, 32, 64, 128 ]

    /// Every reference the picker offers: a single frame, then the hour targets.
    public static let all: [ IntegrationReference ] = [ .singleFrame ] + Self.hourOptions.map { .hours( $0 ) }

    /// The reference's short label, shown in the picker and as the "relative to"
    /// caption.
    public var title: String
    {
        switch self
        {
            case .singleFrame:    return "Single frame"
            case .hours( let h ): return "\( h ) h"
        }
    }
}
