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

extension BinaryFloatingPoint
{
    /// The default tolerance for ``isApproximatelyEqual(to:tolerance:)``.
    ///
    /// Small enough that a genuine, perceptible adjustment is never mistaken for
    /// its neutral value, but large enough to absorb the floating-point drift a
    /// continuous slider produces when dragged back toward neutral.
    static var defaultComparisonTolerance: Self { 1e-6 }

    /// Whether the value is within `tolerance` of `other`, so tiny
    /// floating-point differences read as equal.
    ///
    /// Exact `==` is unsafe when deciding whether an adjustment sits at its
    /// neutral value: a slider dragged back toward neutral rarely lands on the
    /// exact constant, so an exact check would keep applying a stage that has no
    /// visible effect (for gamma, an expensive per-pixel `pow`). Comparing with a
    /// small tolerance instead lets such a value be recognised as neutral and
    /// omitted from the pipeline.
    ///
    /// Defined on ``BinaryFloatingPoint`` so it works with any real
    /// floating-point type (`Double`, `Float`, `CGFloat`, …).
    ///
    /// - Parameters:
    ///   - other:     The value to compare against.
    ///   - tolerance: The maximum absolute difference treated as equal. Defaults
    ///                to ``defaultComparisonTolerance``.
    /// - Returns: `true` when the two values differ by at most `tolerance`.
    func isApproximatelyEqual( to other: Self, tolerance: Self = Self.defaultComparisonTolerance ) -> Bool
    {
        ( self - other ).magnitude <= tolerance
    }
}
