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
import SwiftUI
import SwiftUtilities

/// A loaded FITS image, pairing its header metadata with the renderer that
/// produces displayable pixels.
///
/// Acts as a façade: it re-publishes the renderer's `objectWillChange` so a view
/// observing the image refreshes when the rendered result changes, without
/// observing the renderer directly.
@MainActor
public class FITSImage: ObservableObject
{
    /// The file's header metadata, grouped into sections.
    @Published public private( set ) var info:     FITSImageInfo

    /// The renderer that turns the image HDU into displayable pixels and
    /// histograms.
    @Published public private( set ) var renderer: FITSImageRenderer

    /// Forwards the renderer's change notifications to this object's observers.
    private var rendererObserver: AnyCancellable?

    /// Creates an image from its metadata and renderer, wiring up change
    /// forwarding.
    ///
    /// - Parameters:
    ///   - info:     The file's header metadata.
    ///   - renderer: The renderer for the image HDU.
    public init( info: FITSImageInfo, renderer: FITSImageRenderer )
    {
        self.info             = info
        self.renderer         = renderer
        self.rendererObserver = self.renderer.objectWillChange.sink
        {
            [ weak self ] _ in self?.objectWillChange.send()
        }
    }
}
