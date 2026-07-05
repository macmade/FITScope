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

/// One user-adjustable opacity channel of an overlay's appearance: a display
/// label paired with the ``OverlayAppearance`` component it controls.
///
/// Most overlays expose a single channel — their stroke ``OverlayAppearance/opacity``.
/// An overlay that draws more than one tier declares one channel per tier: the
/// equatorial grid, for instance, exposes its labels (``OverlayAppearance/opacity``)
/// and its fainter lines (``OverlayAppearance/secondaryOpacity``). Each overlay
/// owns this declaration, so the Preferences editor renders one opacity slider per
/// channel with no overlay-specific special-casing.
public struct OverlayOpacityChannel: Identifiable
{
    /// The channel's display label (e.g. "Opacity", "Labels", "Lines").
    public let label: String

    /// The appearance component this channel reads and writes.
    public let keyPath: WritableKeyPath< OverlayAppearance, Double >

    /// The channel's identity for `ForEach` — its label, unique within an overlay.
    public var id: String
    {
        self.label
    }

    /// Creates an opacity channel.
    ///
    /// - Parameters:
    ///   - label:   The channel's display label.
    ///   - keyPath: The appearance component the channel controls.
    public init( label: String, keyPath: WritableKeyPath< OverlayAppearance, Double > )
    {
        self.label   = label
        self.keyPath = keyPath
    }
}
