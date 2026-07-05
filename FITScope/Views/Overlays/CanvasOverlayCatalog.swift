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

/// The customisable canvas overlays, in display order — the single registration
/// point the Overlays preferences tab and the appearance defaults enumerate.
///
/// Each entry is a representative overlay carrying no image data (empty stars, no
/// WCS, …): it is never drawn, only read for its appearance metadata — its
/// ``CanvasOverlay/id``, ``CanvasOverlay/title``, ``CanvasOverlay/defaultAppearance``,
/// and ``CanvasOverlay/opacityChannels``. Each overlay therefore *declares its own*
/// appearance; this catalog only fixes the order they are listed in. It is a
/// computed list (not a stored constant) so its transient elements need not be
/// concurrency-safe global state.
public enum CanvasOverlayCatalog
{
    /// The customisable overlays, in display order.
    public static var all: [ any CanvasOverlay ]
    {
        [
            ReticleOverlay(),
            StarsOverlay( stars: [] ),
            ObjectsOverlay( annotations: [] ),
            ScaleBarOverlay( pixelScale: nil ),
            NorthOverlay( wcs: nil ),
            EquatorialGridOverlay( wcs: nil ),
        ]
    }

    /// Every overlay's default appearance, keyed by its identifier — the
    /// configuration used when the user has customised nothing.
    public static var defaultAppearances: [ String: OverlayAppearance ]
    {
        Dictionary( uniqueKeysWithValues: self.all.map { ( $0.id, type( of: $0 ).defaultAppearance ) } )
    }
}
