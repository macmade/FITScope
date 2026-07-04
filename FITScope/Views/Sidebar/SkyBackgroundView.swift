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

/// The robust sky-background read-out as a self-contained section: the background
/// level and noise, each as a fraction of the frame's value range and in raw linear
/// units (ADU), a relative measure of the sky quality independent of the display
/// pipeline. Styled like the info tabs — a centered icon and headline over a
/// metrics grid.
///
/// It owns all its states so its host doesn't branch on the data: a spinner while
/// the background is being measured, the metrics once it is, or an "unavailable"
/// message once the measurement has run without a usable result.
public struct SkyBackgroundView: View
{
    /// The sky-background estimate, or `nil` before the measurement has produced
    /// one (or when the image is degenerate).
    private let skyBackground: SkyBackground?

    /// Whether the background measurement has completed for this image. While it
    /// is `false` — still measuring, not yet started, or no image — the view shows
    /// progress rather than a misleading "unavailable", which is only correct once
    /// the measurement has actually run.
    private let hasMeasured: Bool

    /// Creates the sky-background view.
    ///
    /// - Parameters:
    ///   - skyBackground: The sky-background estimate, or `nil` when not yet
    ///                    available.
    ///   - hasMeasured:   Whether the measurement has completed.
    public init( skyBackground: SkyBackground?, hasMeasured: Bool )
    {
        self.skyBackground = skyBackground
        self.hasMeasured   = hasMeasured
    }

    /// The view's content: the icon, headline and metrics grid once measured, a
    /// spinner while it is still being measured, or the icon and an "unavailable"
    /// headline once the measurement has run without a usable result.
    public var body: some View
    {
        VStack( spacing: 8 )
        {
            if let skyBackground = self.skyBackground
            {
                self.icon

                Text( "Sky Background" )
                    .font( .system( size: 12, weight: .semibold ) )

                self.grid( skyBackground )
                    .padding( .top, 2 )
            }
            else if self.hasMeasured == false
            {
                ProgressView()
                    .controlSize( .small )

                Text( "Measuring Background\u{2026}" )
                    .font( .system( size: 11 ) )
                    .foregroundStyle( .secondary )
            }
            else
            {
                self.icon

                Text( "Background Unavailable" )
                    .font( .system( size: 12, weight: .semibold ) )
            }
        }
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .accessibilityIdentifier( AccessibilityIdentifier.SkyBackgroundView.container )
    }

    /// The section's header symbol.
    private var icon: some View
    {
        Image( systemName: "circle.lefthalf.filled" )
            .font( .system( size: 40 ) )
            .symbolRenderingMode( .hierarchical )
            .accessibilityIdentifier( AccessibilityIdentifier.SkyBackgroundView.icon )
    }

    /// The metrics grid: the background level and noise, each as a fraction of the
    /// frame's value range and in raw linear units (ADU).
    ///
    /// - Parameter background: The sky-background estimate.
    /// - Returns: The metrics grid.
    private func grid( _ background: SkyBackground ) -> some View
    {
        Grid( alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3 )
        {
            GridRow
            {
                Text( "" )
                Text( "Relative" ).foregroundStyle( .secondary )
                Text( "ADU" ).foregroundStyle( .secondary )
            }

            self.row( systemImage: "circle.lefthalf.filled", label: "Background", relative: background.relativeLevel, raw: background.level )
            self.row( systemImage: "waveform",               label: "Noise",      relative: background.relativeNoise, raw: background.noise )
        }
        .font( .system( size: 10 ) )
    }

    /// One metric row: an icon and the metric's name, then its value as a fraction
    /// of the frame's value range and in raw linear units.
    ///
    /// - Parameters:
    ///   - systemImage: The SF Symbol shown beside the label.
    ///   - label:       The metric's name.
    ///   - relative:    The value as a fraction of the frame's range, or `nil`.
    ///   - raw:         The value in raw linear units (ADU).
    /// - Returns: The grid row.
    private func row( systemImage: String, label: String, relative: Double?, raw: Double ) -> some View
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

            Text( Self.percentText( relative ) )
            Text( Self.aduText( raw ) )
        }
    }

    /// A fraction as a percentage to one decimal, e.g. `8.2%`, or a dash when
    /// absent (a flat frame with no range).
    ///
    /// - Parameter value: The fraction in `0 ... 1`, or `nil`.
    private static func percentText( _ value: Double? ) -> String
    {
        value.map { String( format: "%.1f%%", $0 * 100 ) } ?? "\u{2014}"
    }

    /// A raw linear value as a grouped integer, e.g. `1,532`.
    ///
    /// - Parameter value: The value in linear units (ADU).
    private static func aduText( _ value: Double ) -> String
    {
        let formatter                   = NumberFormatter()
        formatter.numberStyle           = .decimal
        formatter.maximumFractionDigits = 0

        return formatter.string( from: NSNumber( value: value ) ) ?? String( format: "%.0f", value )
    }
}

#Preview( "Measuring" )
{
    SkyBackgroundView( skyBackground: nil, hasMeasured: false )
        .frame( width: 260, height: 160 )
        .padding()
}

#Preview( "Measured" )
{
    let background = SkyBackground( level: 1_532, noise: 48, minimum: 96, maximum: 65_535 )

    return SkyBackgroundView( skyBackground: background, hasMeasured: true )
        .frame( width: 260, height: 160 )
        .padding()
}

#Preview( "Unavailable" )
{
    SkyBackgroundView( skyBackground: nil, hasMeasured: true )
        .frame( width: 260, height: 160 )
        .padding()
}
