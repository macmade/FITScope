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

/// The per-image histogram view options the inspector reads and writes. Held per
/// image (see ``LoadedImage``) so a file keeps its own choices — selected channels,
/// and which panels are shown — as the user switches between open images and the
/// inspector is rebuilt for each.
@MainActor
public final class HistogramViewOptions: ObservableObject
{
    /// The selected channel mode.
    @Published public var mode: HistogramMode = .rgb

    /// Whether the original (unprocessed) histogram is shown instead of the
    /// processed one.
    @Published public var showOriginal = false

    /// Whether the summary statistics panel is shown.
    @Published public var showStatistics = false

    /// Whether the RGB channels are drawn stacked separately rather than overlaid.
    @Published public var separateChannels = false

    /// Whether bar heights are scaled logarithmically rather than linearly.
    @Published public var logScale = false

    /// Creates an options set with the default view (RGB, no panels shown).
    public init()
    {}
}
