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

/// A decoded one-dimensional data series, ready to plot as a graph.
///
/// A format-neutral, `Sendable` value: a decoder (see `GraphSeries+FITS.swift`)
/// builds one off the main actor from a source file's samples, and it crosses back
/// to drive the Swift Charts graph. Non-image data — a spectrum, a light curve —
/// takes this graph branch rather than the raster pixel pipeline.
public struct GraphSeries: Sendable, Equatable
{
    /// A single plotted sample: its position on the horizontal axis and its value.
    public struct Point: Sendable, Equatable, Identifiable
    {
        /// The zero-based sample index, giving the point a stable identity for the
        /// chart independent of its (possibly non-monotonic) `x`.
        public let index: Int

        /// The horizontal-axis position: a physical world coordinate when the source
        /// carries a usable axis scaling, otherwise the one-based sample number.
        public let x: Double

        /// The sample value, with any linear rescaling (e.g. FITS `BSCALE`/`BZERO`)
        /// already applied.
        public let y: Double

        /// The stable identity, the sample's index.
        public var id: Int { self.index }

        /// Creates a plotted point.
        ///
        /// - Parameters:
        ///   - index: The zero-based sample index.
        ///   - x:     The horizontal-axis position.
        ///   - y:     The sample value.
        public init( index: Int, x: Double, y: Double )
        {
            self.index = index
            self.x     = x
            self.y     = y
        }
    }

    /// The plotted points, in sample order.
    public let points: [ Point ]

    /// The horizontal-axis label — a physical quantity (e.g. `"Wavelength (Angstrom)"`)
    /// when the source describes one, otherwise `"Sample"`.
    public let xAxisLabel: String

    /// The vertical-axis label — the sample's physical unit when the source declares
    /// one, otherwise `"Value"`.
    public let yAxisLabel: String

    /// Whether the series has no points to plot.
    public var isEmpty: Bool
    {
        self.points.isEmpty
    }

    /// Creates a graph series.
    ///
    /// - Parameters:
    ///   - points:     The plotted points, in sample order.
    ///   - xAxisLabel: The horizontal-axis label.
    ///   - yAxisLabel: The vertical-axis label.
    public init( points: [ Point ], xAxisLabel: String, yAxisLabel: String )
    {
        self.points     = points
        self.xAxisLabel = xAxisLabel
        self.yAxisLabel = yAxisLabel
    }
}
