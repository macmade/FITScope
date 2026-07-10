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

/// A decoded data series, ready to plot as a graph of one or more lines.
///
/// A format-neutral, `Sendable` value: a decoder (see `GraphSeries+FITS.swift`)
/// builds one off the main actor from a source file's samples, and it crosses back
/// to drive the Swift Charts graph. Non-image data — a single spectrum or light
/// curve (one line), or a stack of spectra sharing a dispersion axis (one line per
/// spectrum) — takes this graph branch rather than the raster pixel pipeline.
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

    /// One plotted line of the graph: its samples and an optional name.
    ///
    /// A single-spectrum graph has exactly one, unnamed line; a stacked-spectra graph
    /// has one named line per spectrum (`"Row 1"`, `"Row 2"`, …), all sharing the
    /// series' axes.
    public struct Line: Sendable, Equatable, Identifiable
    {
        /// The zero-based line index, giving the line a stable identity for the chart.
        public let index: Int

        /// The line's name, used to colour and label it when the graph has more than
        /// one line; `nil` for a single, unnamed line.
        public let name: String?

        /// The line's plotted points, in sample order.
        public let points: [ Point ]

        /// The stable identity, the line's index.
        public var id: Int { self.index }

        /// Creates a plotted line.
        ///
        /// - Parameters:
        ///   - index:  The zero-based line index.
        ///   - name:   The line's name, or `nil` for a single unnamed line.
        ///   - points: The line's plotted points, in sample order.
        public init( index: Int, name: String?, points: [ Point ] )
        {
            self.index  = index
            self.name   = name
            self.points = points
        }
    }

    /// The plotted lines, in order. A single-spectrum graph has one line; a
    /// stacked-spectra graph has one line per spectrum.
    public let lines: [ Line ]

    /// The horizontal-axis label — a physical quantity (e.g. `"Wavelength (Angstrom)"`)
    /// when the source describes one, otherwise `"Sample"`. Shared by every line.
    public let xAxisLabel: String

    /// The vertical-axis label — the sample's physical unit when the source declares
    /// one, otherwise `"Value"`. Shared by every line.
    public let yAxisLabel: String

    /// Every plotted point across all lines, in line then sample order — for
    /// computing the overall axis domains that must bound all lines.
    public var points: [ Point ]
    {
        self.lines.flatMap { $0.points }
    }

    /// Whether the graph has more than one line, so the view colours and legends the
    /// lines rather than drawing a single accent-coloured line.
    public var isMultiLine: Bool
    {
        self.lines.count > 1
    }

    /// Whether the series has no points to plot.
    public var isEmpty: Bool
    {
        self.lines.allSatisfy { $0.points.isEmpty }
    }

    /// Creates a graph series from its lines.
    ///
    /// - Parameters:
    ///   - lines:      The plotted lines, in order.
    ///   - xAxisLabel: The horizontal-axis label.
    ///   - yAxisLabel: The vertical-axis label.
    public init( lines: [ Line ], xAxisLabel: String, yAxisLabel: String )
    {
        self.lines      = lines
        self.xAxisLabel = xAxisLabel
        self.yAxisLabel = yAxisLabel
    }

    /// Creates a single-line graph series from its points.
    ///
    /// - Parameters:
    ///   - points:     The plotted points, in sample order.
    ///   - xAxisLabel: The horizontal-axis label.
    ///   - yAxisLabel: The vertical-axis label.
    public init( points: [ Point ], xAxisLabel: String, yAxisLabel: String )
    {
        self.lines      = [ Line( index: 0, name: nil, points: points ) ]
        self.xAxisLabel = xAxisLabel
        self.yAxisLabel = yAxisLabel
    }
}
