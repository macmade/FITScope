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

import SwiftUI

/// The capture location's latitude and longitude, rendered as icon / label /
/// value rows in the same style as the Image Information panel — shown in the
/// Map tab beneath the map.
public struct LocationInfoView: View
{
    /// The latitude, in decimal degrees (positive north).
    private let latitude: Double

    /// The longitude, in decimal degrees (positive east).
    private let longitude: Double

    /// Creates the location-info rows.
    ///
    /// - Parameters:
    ///   - latitude:  The latitude, in decimal degrees.
    ///   - longitude: The longitude, in decimal degrees.
    public init( latitude: Double, longitude: Double )
    {
        self.latitude  = latitude
        self.longitude = longitude
    }

    /// The view's content.
    public var body: some View
    {
        Grid( alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3 )
        {
            self.row( systemImage: "arrow.up.arrow.down",     label: "Latitude",  value: Self.format( self.latitude,  positive: "N", negative: "S" ) )
            self.row( systemImage: "arrow.left.arrow.right",  label: "Longitude", value: Self.format( self.longitude, positive: "E", negative: "W" ) )
        }
        .frame( maxWidth: .infinity, alignment: .leading )
        // Let the coordinate labels and values be selected and copied, matching
        // the Image Information panel.
        .textSelection( .enabled )
    }

    /// One icon / label / value row, matching the Image Information panel's rows.
    ///
    /// - Parameters:
    ///   - systemImage: The SF Symbol shown beside the label.
    ///   - label:       The field's name.
    ///   - value:       The formatted value.
    /// - Returns: The grid row.
    private func row( systemImage: String, label: String, value: String ) -> some View
    {
        GridRow
        {
            HStack( spacing: 5 )
            {
                Image( systemName: systemImage )
                    .foregroundStyle( Color.secondary )
                    .frame( width: 12 )

                Text( label )
                    .foregroundStyle( Color.secondary )
            }

            Text( value )
        }
        .font( .system( size: 10 ) )
    }

    /// Formats a signed degree value as a sign-free magnitude with a hemisphere
    /// suffix, e.g. `46.2000° N` or `6.1500° W`.
    ///
    /// - Parameters:
    ///   - degrees:  The signed value, in decimal degrees.
    ///   - positive: The suffix for a non-negative value (`N` or `E`).
    ///   - negative: The suffix for a negative value (`S` or `W`).
    /// - Returns: The formatted, hemisphere-suffixed string.
    nonisolated static func format( _ degrees: Double, positive: String, negative: String ) -> String
    {
        let suffix = degrees >= 0 ? positive : negative

        return String( format: "%.4f° %@", abs( degrees ), suffix )
    }
}

#Preview
{
    LocationInfoView( latitude: 46.2, longitude: -6.15 )
        .padding()
        .frame( width: 260 )
}
