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

/// A key the files sidebar can sort by: the order the files were opened, the file
/// name, the computed weight, or one of the per-image metrics.
public enum FileSortKey: String, CaseIterable, Identifiable, Sendable
{
    /// The order the files were opened in — the list's natural order.
    case opened

    /// The file name.
    case name

    /// The computed per-image weight.
    case weight

    /// The median star FWHM.
    case fwhm

    /// The median star half-flux radius.
    case hfr

    /// The median star eccentricity.
    case eccentricity

    /// The number of detected stars.
    case stars

    /// The signal-to-noise weight.
    case snrWeight

    /// A stable identity, so the key can drive a SwiftUI `ForEach`/`Picker`.
    public var id: String
    {
        self.rawValue
    }

    /// The label shown for the key in the sort menu.
    public var title: String
    {
        switch self
        {
            case .opened:       return "Order Opened"
            case .name:         return "Name"
            case .weight:       return "Weight"
            case .fwhm:         return "FWHM"
            case .hfr:          return "HFR"
            case .eccentricity: return "Eccentricity"
            case .stars:        return "Stars"
            case .snrWeight:    return "SNR Weight"
        }
    }

    /// The metric variable a numeric metric key reads, or `nil` for the keys that
    /// are not backed by a metric (opened, name, weight).
    private var metricVariable: WeightFormula.Variable?
    {
        switch self
        {
            case .fwhm:         return .fwhm
            case .hfr:          return .hfr
            case .eccentricity: return .eccentricity
            case .stars:        return .stars
            case .snrWeight:    return .snrWeight
            default:            return nil
        }
    }

    /// The text shown in the sidebar pill for a file under this sort key: the
    /// selected metric's value for the metric keys (`nil` when the file lacks
    /// it), or the file's weight for the keys not backed by a metric (`opened`,
    /// `name`, `weight`), so sorting by a metric surfaces the values being
    /// compared.
    ///
    /// - Parameters:
    ///   - file:            The file to read.
    ///   - formattedWeight: The file's display-formatted weight, passed in so
    ///                      weight keeps a single formatting source of truth.
    /// - Returns: The pill text, or `nil` when there is nothing to show.
    @MainActor
    public func pillText< Element: FileSortable >( for file: Element, formattedWeight: String? ) -> String?
    {
        guard let variable = self.metricVariable
        else
        {
            return formattedWeight
        }

        guard let value = file.metrics[ variable ]
        else
        {
            return nil
        }

        return Self.formatted( value, for: variable )
    }

    /// The tooltip for the sidebar pill under this sort key: the selected metric's
    /// description, or the weight's for the keys not backed by a metric.
    public var pillTooltip: String
    {
        self.metricVariable?.tooltip ?? "Image weight, ranked against the other open files"
    }

    /// Formats a metric value for the pill: an integer star count, one decimal for
    /// the SNR weight, two decimals for the seeing metrics (FWHM, HFR,
    /// eccentricity).
    ///
    /// - Parameters:
    ///   - value:    The metric value.
    ///   - variable: The metric it belongs to.
    /// - Returns: The formatted value.
    private static func formatted( _ value: Double, for variable: WeightFormula.Variable ) -> String
    {
        switch variable
        {
            case .stars:     return String( Int( value.rounded() ) )
            case .snrWeight: return String( format: "%.1f", value )
            default:         return String( format: "%.2f", value )
        }
    }

    /// Sorts the files by this key.
    ///
    /// - `opened` keeps the natural order, reversed when descending.
    /// - `name` compares names case- and locale-insensitively.
    /// - The numeric keys (`weight` and the metric keys) order by value; a file
    ///   missing the value always sorts **last**, in both directions, so absent
    ///   metrics never intersperse with present ones. Equal values — and the
    ///   trailing files with no value — keep a stable order: by name, then by
    ///   their opened position.
    ///
    /// - Parameters:
    ///   - files:     The files to sort.
    ///   - ascending: Whether to sort ascending (smallest / A-first) or descending.
    /// - Returns: The files in sorted order.
    @MainActor
    public func sorted< Element: FileSortable >( _ files: [ Element ], ascending: Bool ) -> [ Element ]
    {
        if self == .opened
        {
            return ascending ? files : files.reversed()
        }

        let indexed = Array( files.enumerated() )

        let ordered = indexed.sorted
        {
            lhs, rhs in self.precedes( lhs.element, before: rhs.element, ascending: ascending, lhsIndex: lhs.offset, rhsIndex: rhs.offset )
        }

        return ordered.map { $0.element }
    }

    /// Whether `lhs` should be ordered before `rhs` for this key.
    ///
    /// - Parameters:
    ///   - lhs:       The left-hand file.
    ///   - rhs:       The right-hand file.
    ///   - ascending: The sort direction.
    ///   - lhsIndex:  The left-hand file's opened position, used as a final tiebreak.
    ///   - rhsIndex:  The right-hand file's opened position, used as a final tiebreak.
    /// - Returns: `true` if `lhs` precedes `rhs`.
    @MainActor
    private func precedes< Element: FileSortable >( _ lhs: Element, before rhs: Element, ascending: Bool, lhsIndex: Int, rhsIndex: Int ) -> Bool
    {
        if self == .name
        {
            let comparison = lhs.displayName.localizedCaseInsensitiveCompare( rhs.displayName )

            guard comparison == .orderedSame
            else
            {
                return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
            }

            return lhsIndex < rhsIndex
        }

        let lhsValue = self.value( of: lhs )
        let rhsValue = self.value( of: rhs )

        switch ( lhsValue, rhsValue )
        {
            case ( nil, nil ): return self.tieBreak( lhs, rhs, lhsIndex: lhsIndex, rhsIndex: rhsIndex )
            case ( _, nil ):   return true
            case ( nil, _ ):   return false

            case ( let left?, let right? ):

                guard left == right
                else
                {
                    return ascending ? left < right : left > right
                }

                return self.tieBreak( lhs, rhs, lhsIndex: lhsIndex, rhsIndex: rhsIndex )
        }
    }

    /// The numeric value this key reads from a file, or `nil` when absent.
    ///
    /// - Parameter file: The file to read.
    /// - Returns: The value, or `nil` for a non-numeric key or a missing metric.
    @MainActor
    private func value< Element: FileSortable >( of file: Element ) -> Double?
    {
        if self == .weight
        {
            return file.weight
        }

        guard let variable = self.metricVariable
        else
        {
            return nil
        }

        return file.metrics[ variable ]
    }

    /// Breaks a tie — equal values, or both values missing — stably: by name, then
    /// by the files' opened positions.
    ///
    /// - Parameters:
    ///   - lhs:      The left-hand file.
    ///   - rhs:      The right-hand file.
    ///   - lhsIndex: The left-hand file's opened position.
    ///   - rhsIndex: The right-hand file's opened position.
    /// - Returns: `true` if `lhs` precedes `rhs`.
    @MainActor
    private func tieBreak< Element: FileSortable >( _ lhs: Element, _ rhs: Element, lhsIndex: Int, rhsIndex: Int ) -> Bool
    {
        let comparison = lhs.displayName.localizedCaseInsensitiveCompare( rhs.displayName )

        guard comparison == .orderedSame
        else
        {
            return comparison == .orderedAscending
        }

        return lhsIndex < rhsIndex
    }
}
