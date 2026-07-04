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

/// Turns the session's per-file samples into an ordered, plottable series for one
/// metric.
///
/// The frames are placed in acquisition order — sorted by `DATE-OBS` when **every**
/// frame carries one, otherwise kept in the order they were opened (a mix of dated
/// and undated frames cannot be meaningfully sorted, so it is left alone). Each
/// frame is numbered 1…N; a frame that lacks the requested metric is skipped but
/// keeps its number, so a ruined frame reads as a gap in the trend rather than
/// shifting every later point one place to the left.
public enum SessionMetricSeries
{
    /// A single plottable point: a frame's value for a metric, at its position in
    /// the session.
    public struct Point: Identifiable, Equatable, Sendable
    {
        /// The originating file's identifier.
        public let id: UUID

        /// The frame's 1-based position in the ordered session.
        public let position: Int

        /// The frame's display name, for labelling.
        public let name: String

        /// The metric's value for this frame.
        public let value: Double

        /// Creates a point.
        ///
        /// - Parameters:
        ///   - id:       The originating file's identifier.
        ///   - position: The 1-based session position.
        ///   - name:     The frame's display name.
        ///   - value:    The metric's value.
        public init( id: UUID, position: Int, name: String, value: Double )
        {
            self.id       = id
            self.position = position
            self.name     = name
            self.value    = value
        }
    }

    /// Builds the ordered points for a metric.
    ///
    /// - Parameters:
    ///   - metric:  The metric to extract.
    ///   - samples: The session's per-file samples, in the order they were opened.
    /// - Returns: One point per frame that has the metric, in acquisition order.
    public static func points( for metric: SessionMetric, from samples: [ SessionMetricSample ] ) -> [ Point ]
    {
        Self.ordered( samples ).enumerated().compactMap
        {
            index, sample in

            guard let value = metric.value( in: sample )
            else
            {
                return nil
            }

            return Point( id: sample.id, position: index + 1, name: sample.name, value: value )
        }
    }

    /// Builds the cumulative relative-SNR curve across the session.
    ///
    /// Walking the frames in acquisition order, the running total integration grows,
    /// and each frame's point is the relative SNR that much integration has reached
    /// versus the reference: `√(cumulative exposure / reference)`. Frames without an
    /// exposure contribute nothing and get no point (a gap), keeping their position.
    ///
    /// - Parameters:
    ///   - samples:          The session's per-file samples, in opened order.
    ///   - referenceSeconds: The reference integration to divide by (must be > 0).
    /// - Returns: The rising cumulative relative-SNR points, in acquisition order.
    public static func cumulativeRelativeSNRPoints( from samples: [ SessionMetricSample ], referenceSeconds: Double ) -> [ Point ]
    {
        guard referenceSeconds > 0
        else
        {
            return []
        }

        var cumulative = 0.0

        return Self.ordered( samples ).enumerated().compactMap
        {
            index, sample in

            guard let exposure = sample.exposure, exposure > 0
            else
            {
                return nil
            }

            cumulative += exposure

            let value = ( cumulative / referenceSeconds ).squareRoot()

            return Point( id: sample.id, position: index + 1, name: sample.name, value: value )
        }
    }

    /// Orders the samples for plotting: chronologically when every frame carries an
    /// observation date, otherwise unchanged (their opened order).
    ///
    /// - Parameter samples: The samples to order.
    /// - Returns: The samples in acquisition order.
    private static func ordered( _ samples: [ SessionMetricSample ] ) -> [ SessionMetricSample ]
    {
        guard samples.allSatisfy( { $0.observationDate != nil } )
        else
        {
            return samples
        }

        return samples.sorted
        {
            ( $0.observationDate ?? .distantPast ) < ( $1.observationDate ?? .distantPast )
        }
    }
}
