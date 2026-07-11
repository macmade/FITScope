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
import SwiftXISF

public extension Processors.Stretch.STFParameters
{
    /// Maps a parsed XISF display function onto the editable Screen Transfer
    /// parameters, so a stored display function and an auto-derived STF converge on
    /// the same representation.
    ///
    /// The XISF `m`/`s`/`h`/`l`/`r` attributes map directly onto a channel's
    /// midtones / shadows / highlights / low / high — the model
    /// ``Processors/Stretch/STFParameters/Channel`` was built to mirror. The RGB/K
    /// mode is honoured by the colour space: an RGB image maps to a per-channel STF,
    /// each channel taking its own red/green/blue component, while any other colour
    /// space (grayscale, and the linked-K case) maps to a uniform STF from the
    /// red/gray component. The colour space — rather than the raw channel count —
    /// selects the mode, so a three-channel non-RGB image (e.g. CIE L*a*b*) does not
    /// map its components onto the wrong channels. The lightness component is not
    /// represented, as the STF has no separate lightness channel.
    ///
    /// The initializer fails (returns `nil`) when the display function is the
    /// identity — leaving the image linear rather than opening it with a no-op
    /// stretch — or when any channel is not a usable mapping, since the apply path
    /// requires validated parameters.
    ///
    /// - Parameters:
    ///   - displayFunction: The parsed XISF display function.
    ///   - colorSpace:      The image's colour space, selecting per-channel (RGB) or
    ///                      uniform mapping.
    init?( displayFunction: XISFDisplayFunction, colorSpace: XISFColorSpace )
    {
        let params: Processors.Stretch.STFParameters

        if colorSpace == .rgb
        {
            params = .perChannel(
                red:   Self.channel( from: displayFunction, \.rk ),
                green: Self.channel( from: displayFunction, \.g ),
                blue:  Self.channel( from: displayFunction, \.b )
            )
        }
        else
        {
            params = .uniform( Self.channel( from: displayFunction, \.rk ) )
        }

        guard params.isIdentity == false, Self.isUsable( params )
        else
        {
            return nil
        }

        self = params
    }

    /// Builds one channel's STF mapping from a display function, selecting each
    /// parameter vector's per-component value through `component`.
    ///
    /// - Parameters:
    ///   - displayFunction: The display function to map.
    ///   - component:       The per-component value to read from each parameter
    ///                      vector (red/gray, green or blue).
    /// - Returns: The channel mapping for that component.
    private static func channel( from displayFunction: XISFDisplayFunction, _ component: KeyPath< XISFDisplayFunction.Components, Double > ) -> Channel
    {
        Channel(
            shadows:    displayFunction.shadowsClipping[ keyPath: component ],
            midtones:   displayFunction.midtonesBalance[ keyPath: component ],
            highlights: displayFunction.highlightsClipping[ keyPath: component ],
            low:        displayFunction.shadowsExpansion[ keyPath: component ],
            high:       displayFunction.highlightsExpansion[ keyPath: component ]
        )
    }

    /// Whether every channel of `params` is a usable mapping — mirroring the
    /// per-channel validation the apply path performs — so the seeded baseline
    /// cannot make the render throw.
    ///
    /// - Parameter params: The mapped parameters.
    /// - Returns: `true` when every channel is usable.
    private static func isUsable( _ params: Processors.Stretch.STFParameters ) -> Bool
    {
        switch params
        {
            case .uniform( let channel ):            return Self.isUsable( channel )
            case .perChannel( let r, let g, let b ): return Self.isUsable( r ) && Self.isUsable( g ) && Self.isUsable( b )
            @unknown default:                        return false
        }
    }

    /// Whether a single channel is a usable mapping: a non-empty clip window, a
    /// non-empty expansion range, and midtones within `[0, 1]`.
    ///
    /// - Parameter channel: The channel mapping to check.
    /// - Returns: `true` when the channel is usable.
    private static func isUsable( _ channel: Channel ) -> Bool
    {
        channel.highlights > channel.shadows && channel.high > channel.low && channel.midtones >= 0 && channel.midtones <= 1
    }
}
