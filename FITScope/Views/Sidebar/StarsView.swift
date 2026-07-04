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

import SwiftAstro
import SwiftUI

/// The Stars tab's content: the results of the automatic star detection — the
/// star count and the median FWHM, half-flux radius and eccentricity, the usual
/// measures of focus and tracking quality. The canvas overlay is unaffected.
///
/// It owns its states so its host doesn't branch on the data: a spinner while
/// detection runs, the metrics once stars are found, or a placeholder when none
/// are.
public struct StarsView: View
{
    /// The detected star field, or `nil` before detection has produced one.
    private let starField: StarField?

    /// Whether star detection has completed for this image. While it is `false`
    /// — detection still running, not yet started, or no image — the view shows
    /// progress rather than a misleading "no stars", which is only correct once
    /// detection has actually run.
    private let hasDetected: Bool

    /// Creates the stars view.
    ///
    /// - Parameters:
    ///   - starField:   The detected star field, or `nil` when not yet available.
    ///   - hasDetected: Whether detection has completed.
    public init( starField: StarField?, hasDetected: Bool )
    {
        self.starField   = starField
        self.hasDetected = hasDetected
    }

    /// The view's content: the metrics once detection has found stars, a "no
    /// stars" placeholder once it has run and found none, otherwise a spinner
    /// while it runs (or before it has). All fill a bordered card so the tab keeps
    /// a stable shape.
    public var body: some View
    {
        Group
        {
            if self.hasDetected == false
            {
                self.detecting
            }
            else if let starField = self.starField, starField.count > 0
            {
                self.metrics( starField )
            }
            else
            {
                StatusMessageView( systemImage: "sparkles", title: "No Stars Detected", message: "No stars were found in this image." )
            }
        }
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .clipShape( RoundedRectangle( cornerRadius: 10 ) )
        .overlay( RoundedRectangle( cornerRadius: 10 ).strokeBorder( .quaternary, lineWidth: 0.5 ) )
        .accessibilityIdentifier( AccessibilityIdentifier.StarsView.container )
    }

    /// The in-progress state: a spinner and label while detection runs.
    private var detecting: some View
    {
        VStack( spacing: 8 )
        {
            ProgressView()
                .controlSize( .small )

            Text( "Detecting Stars\u{2026}" )
                .font( .system( size: 11 ) )
                .foregroundStyle( .secondary )
        }
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .background( .regularMaterial )
    }

    /// The detection metrics: the star count headline and the median shape
    /// measures.
    ///
    /// - Parameter starField: The detected star field (with at least one star).
    private func metrics( _ starField: StarField ) -> some View
    {
        VStack( spacing: 8 )
        {
            Image( systemName: "sparkles" )
                .font( .system( size: 40 ) )
                .symbolRenderingMode( .hierarchical )
                .accessibilityIdentifier( AccessibilityIdentifier.StarsView.icon )

            Text( Self.countText( starField.count ) )
                .font( .system( size: 12, weight: .semibold ) )

            Grid( alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3 )
            {
                GridRow
                {
                    Text( "" )
                    Text( "Median" ).foregroundStyle( .secondary )
                    Text( "Min" ).foregroundStyle( .secondary )
                    Text( "Max" ).foregroundStyle( .secondary )
                }

                self.row( systemImage: "circle.dotted",             label: "FWHM",         median: Self.pixelText( starField.medianFWHM ),          range: starField.fwhmRange )
                self.row( systemImage: "smallcircle.filled.circle", label: "HFR",          median: Self.pixelText( starField.medianHFR ),           range: starField.hfrRange )
                self.row( systemImage: "oval",                      label: "Eccentricity", median: Self.numberText( starField.medianEccentricity ), range: starField.eccentricityRange )
            }
            .font( .system( size: 10 ) )
            .padding( .top, 2 )
        }
        .padding( 12 )
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .background( .regularMaterial )
        // Let the count and metrics be selected and copied, matching the other
        // info panels.
        .textSelection( .enabled )
    }

    /// One metric row: an icon and the metric's name, then its median, minimum
    /// and maximum in their own columns, matching the other tabs' column layout.
    ///
    /// - Parameters:
    ///   - systemImage: The SF Symbol shown beside the label.
    ///   - label:       The metric's name.
    ///   - median:      The formatted median value.
    ///   - range:       The value range, whose bounds fill the Min and Max
    ///                  columns.
    /// - Returns: The grid row.
    private func row( systemImage: String, label: String, median: String, range: ClosedRange< Double >? ) -> some View
    {
        GridRow
        {
            HStack( spacing: 5 )
            {
                Image( systemName: systemImage )
                    .foregroundStyle( .secondary )
                    .frame( width: 12 )

                Text( label )
                    .foregroundStyle( .secondary )
            }

            Text( median )
            Text( Self.boundText( range?.lowerBound ) )
            Text( Self.boundText( range?.upperBound ) )
        }
    }

    /// The star count as a grouped, pluralized sentence, e.g. `1,247 stars`.
    ///
    /// - Parameter count: The number of detected stars.
    private static func countText( _ count: Int ) -> String
    {
        let formatter         = NumberFormatter()
        formatter.numberStyle = .decimal
        let number            = formatter.string( from: NSNumber( value: count ) ) ?? "\( count )"

        return count == 1 ? "\( number ) star" : "\( number ) stars"
    }

    /// A pixel measure to two decimals, e.g. `3.42 px`, or a dash when absent.
    ///
    /// - Parameter value: The measure, in pixels, or `nil`.
    private static func pixelText( _ value: Double? ) -> String
    {
        value.map { String( format: "%.2f px", $0 ) } ?? "\u{2014}"
    }

    /// A dimensionless measure to two decimals, e.g. `0.32`, or a dash when absent.
    ///
    /// - Parameter value: The measure, or `nil`.
    private static func numberText( _ value: Double? ) -> String
    {
        value.map { String( format: "%.2f", $0 ) } ?? "\u{2014}"
    }

    /// A single bound (minimum or maximum) to two decimals, e.g. `2.10`, or a
    /// dash when absent.
    ///
    /// - Parameter value: The bound value, or `nil`.
    private static func boundText( _ value: Double? ) -> String
    {
        value.map { String( format: "%.2f", $0 ) } ?? "\u{2014}"
    }
}

#Preview( "Detecting" )
{
    StarsView( starField: nil, hasDetected: false )
        .frame( width: 260, height: 240 )
        .padding()
}

#Preview( "Detected" )
{
    let stars: [ Star ] = ( 0 ..< 640 ).map
    {
        index in

        let position      = Double( index )
        let fwhm          = 3.1 + Double( index % 5 ) * 0.1
        let hfr           = 1.8 + Double( index % 4 ) * 0.1
        let eccentricity  = 0.2 + Double( index % 3 ) * 0.05

        return Star( x: position, y: position, flux: 1, hfr: hfr, fwhm: fwhm, eccentricity: eccentricity )
    }

    return StarsView( starField: StarField( stars: stars ), hasDetected: true )
        .frame( width: 260, height: 240 )
        .padding()
}

#Preview( "None" )
{
    StarsView( starField: StarField( stars: [] ), hasDetected: true )
        .frame( width: 260, height: 240 )
        .padding()
}
