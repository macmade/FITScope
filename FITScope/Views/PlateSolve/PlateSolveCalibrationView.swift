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

/// The solved field calibration, shown in a labelled box: an aligned icon
/// column, the field name, and a monospaced value.
struct PlateSolveCalibrationView: View
{
    /// A single labelled calibration value, with an icon for the field.
    private struct Field: Identifiable
    {
        /// The SF Symbol shown beside the label.
        let icon: String

        /// The field's name.
        let title: String

        /// The formatted value, shown in a monospaced font.
        let value: String

        /// Identity, the field's stable name.
        var id: String { self.title }
    }

    /// The width reserved for the field icons, so the labels align in a column
    /// regardless of the icons' differing intrinsic widths.
    private static let iconColumnWidth: CGFloat = 18

    /// The calibration to display.
    private let calibration: PlateSolveResult.Calibration

    /// Creates the calibration box.
    ///
    /// - Parameter calibration: The calibration to display.
    init( calibration: PlateSolveResult.Calibration )
    {
        self.calibration = calibration
    }

    /// The view's content.
    var body: some View
    {
        GroupBox
        {
            VStack( spacing: 8 )
            {
                ForEach( self.fields )
                {
                    field in

                    HStack( spacing: 8 )
                    {
                        Image( systemName: field.icon )
                            .foregroundStyle( .secondary )
                            .frame( width: Self.iconColumnWidth, alignment: .center )

                        Text( field.title )

                        Spacer( minLength: 16 )

                        Text( field.value )
                            .font( .system( .body, design: .monospaced ) )
                            .foregroundStyle( .secondary )
                    }
                }
            }
            .padding( 4 )
            // The calibration field labels and values are selectable/copyable;
            // the "Solution" box title is left as a plain heading.
            .textSelection( .enabled )
        }
        label:
        {
            Text( "Solution" )
                .font( .headline )
        }
    }

    /// The labelled calibration fields, in display order.
    private var fields: [ Field ]
    {
        var fields =
            [
                Field( icon: "arrow.left.and.right", title: "Right Ascension", value: Self.degrees( self.calibration.ra ) ),
                Field( icon: "arrow.up.and.down",    title: "Declination",     value: Self.degrees( self.calibration.dec ) ),
                Field( icon: "ruler",                title: "Pixel Scale",     value: String( format: "%.3f\u{2033}/px", self.calibration.pixscale ) ),
                Field( icon: "location.north.line",  title: "Orientation",     value: String( format: "%.2f\u{00B0}", self.calibration.orientation ) ),
                Field( icon: "circle.dashed",        title: "Field Radius",    value: String( format: "%.3f\u{00B0}", self.calibration.radius ) ),
            ]

        if let parity = self.calibration.parity
        {
            fields.append( Field( icon: "plusminus", title: "Parity", value: String( format: "%+.0f", parity ) ) )
        }

        return fields
    }

    /// Formats a decimal-degree value for display.
    ///
    /// - Parameter value: The value in degrees.
    private static func degrees( _ value: Double ) -> String
    {
        String( format: "%.5f\u{00B0}", value )
    }
}

#Preview
{
    PlateSolveCalibrationView( calibration: PlateSolveResult.Calibration( ra: 182.625_706, dec: 39.412_337, pixscale: 1.091, orientation: 105.749, radius: 0.811, parity: 1 ) )
        .padding()
        .frame( width: 430 )
}
