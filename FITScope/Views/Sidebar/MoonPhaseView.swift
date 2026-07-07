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

/// The Moon tab's content: the capture's lunar phase — a drawn moon disc, the
/// phase name and the illuminated fraction — together with where the Moon was in
/// the sky: its altitude and compass direction (when the observing site is known),
/// its distance from the Earth, and its angular separation from the imaged target
/// (when the image records one). All computed locally, or, when the image carries
/// no date, a "No Date" placeholder.
///
/// It owns its states so its host doesn't branch on the data: the altitude and
/// direction appear only with a location, and the target separation only with a
/// target, while the phase, illumination and distance need only the date.
public struct MoonPhaseView: View
{
    /// The observing site, or `nil` when the image has no coordinates. Drives the
    /// altitude and direction; without it those rows are omitted.
    private let location: GeographicLocation?

    /// The capture date the phase and positions are computed for and shown, or `nil`
    /// when the image has no date.
    private let date: Date?

    /// The imaged target's celestial coordinate, or `nil` when the image records
    /// none. Drives the Moon-to-target separation; without it that row is omitted.
    private let target: EquatorialCoordinate?

    /// Creates the moon-phase view.
    ///
    /// - Parameters:
    ///   - location: The observing site, or `nil` when unknown.
    ///   - date:     The capture date (e.g. a frame's `DATE-OBS`), or `nil`.
    ///   - target:   The imaged target's celestial coordinate, or `nil`.
    public init( location: GeographicLocation?, date: Date?, target: EquatorialCoordinate? )
    {
        self.location = location
        self.date     = date
        self.target   = target
    }

    /// The view's content: the phase and positions when a date is known, otherwise a
    /// placeholder. Both fill a bordered card so the tab keeps a stable shape.
    public var body: some View
    {
        Group
        {
            if let date = self.date
            {
                self.phase( for: date )
            }
            else
            {
                StatusMessageView( systemImage: "calendar", title: "No Date", message: "This image has no capture date." )
            }
        }
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .clipShape( RoundedRectangle( cornerRadius: 10 ) )
        .overlay( RoundedRectangle( cornerRadius: 10 ).strokeBorder( .quaternary, lineWidth: 0.5 ) )
        .accessibilityIdentifier( AccessibilityIdentifier.MoonPhaseView.container )
    }

    /// The lunar phase for a date: the disc, the phase name, the illumination, the
    /// sky-position details and the date.
    ///
    /// - Parameter date: The capture date.
    private func phase( for date: Date ) -> some View
    {
        let moonPhase = MoonPhase( date: date )

        return VStack( spacing: 8 )
        {
            MoonPhaseDisc( fraction: moonPhase.fraction )
                .frame( width: 92, height: 92 )
                // The disc fills its frame edge-to-edge, unlike the SF Symbol
                // headers in the other tabs (which carry intrinsic whitespace), so
                // add a little bottom padding to match their optical gap to the text.
                .padding( .bottom, 6 )
                .accessibilityIdentifier( AccessibilityIdentifier.MoonPhaseView.icon )

            Text( moonPhase.phase.name )
                .font( .system( size: 12, weight: .semibold ) )

            Text( Self.illuminationText( moonPhase ) )
                .font( .system( size: 10 ) )
                .foregroundStyle( .secondary )

            self.details( for: date )
                .padding( .top, 2 )

            Text( Self.dateText( date ) )
                .font( .system( size: 10 ) )
                .foregroundStyle( .tertiary )
        }
        .padding( 12 )
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .background( .regularMaterial )
        // Let the phase name, illumination, positions and date be selected and
        // copied, matching the Image Information panel.
        .textSelection( .enabled )
    }

    /// The Moon's sky-position details for a date: its altitude and direction (only
    /// with an observing site), its distance from the Earth, and its separation from
    /// the imaged target (only with a target).
    ///
    /// - Parameter date: The capture date.
    private func details( for date: Date ) -> some View
    {
        Grid( alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3 )
        {
            if let location = self.location
            {
                let horizontal = LunarPosition.horizontal( at: date, location: location )

                self.row( systemImage: "arrow.up",            label: "Altitude",  value: Self.altitudeText( horizontal.altitude ) )
                self.row( systemImage: "location.north.line", label: "Direction", value: CompassDirection.abbreviation( forAzimuth: horizontal.azimuth ) )
            }

            self.row( systemImage: "ruler", label: "Distance", value: Self.distanceText( LunarPosition.distance( at: date ) ) )

            if let target = self.target
            {
                let separation = LunarPosition.position( at: date ).angularSeparation( to: target )

                self.row( systemImage: "scope", label: "From target", value: Self.separationText( separation ) )
            }
        }
        .font( .system( size: 10 ) )
    }

    /// One detail row: an icon evoking the quantity, its label in the secondary
    /// color, and its value in the primary — matching the other info panels' rows.
    ///
    /// - Parameters:
    ///   - systemImage: The SF Symbol shown beside the label.
    ///   - label:       The row's label.
    ///   - value:       The row's value.
    /// - Returns: The grid row.
    private func row( systemImage: String, label: String, value: String ) -> some View
    {
        GridRow
        {
            HStack( spacing: 5 )
            {
                Image( systemName: systemImage )
                    .foregroundStyle( .secondary )
                    .frame( width: 12 )

                Text( label ).foregroundStyle( .secondary )
            }

            Text( value )
        }
    }

    /// The illuminated fraction as a whole-percent sentence, e.g.
    /// `73% illuminated`.
    ///
    /// - Parameter moonPhase: The phase to describe.
    private static func illuminationText( _ moonPhase: MoonPhase ) -> String
    {
        let percent = Int( ( moonPhase.illumination * 100 ).rounded() )

        return "\( percent )% illuminated"
    }

    /// A signed whole-degree altitude, e.g. `+34°` or `−12°` (negative below the
    /// horizon), matching the Planets tab.
    ///
    /// - Parameter altitude: The altitude, in degrees.
    private static func altitudeText( _ altitude: Double ) -> String
    {
        String( format: "%+.0f°", altitude )
    }

    /// The Earth–Moon distance rounded to the nearest hundred kilometres and grouped,
    /// e.g. `384,400 km` — the method's distance is not precise to the kilometre.
    ///
    /// - Parameter kilometres: The distance, in kilometres.
    private static func distanceText( _ kilometres: Double ) -> String
    {
        let rounded   = ( kilometres / 100 ).rounded() * 100
        let formatter = NumberFormatter()

        formatter.numberStyle          = .decimal
        formatter.maximumFractionDigits = 0

        let number = formatter.string( from: NSNumber( value: rounded ) ) ?? String( Int( rounded ) )

        return "\( number ) km"
    }

    /// An angular separation as whole degrees, e.g. `42°`.
    ///
    /// - Parameter degrees: The separation, in degrees.
    private static func separationText( _ degrees: Double ) -> String
    {
        String( format: "%.0f°", degrees )
    }

    /// A date formatted in UTC (the time zone `DATE-OBS` is recorded in), e.g.
    /// `2024-01-25 17:54 UTC`.
    ///
    /// - Parameter date: The date to format.
    private static func dateText( _ date: Date ) -> String
    {
        let formatter        = DateFormatter()
        formatter.locale     = Locale( identifier: "en_US_POSIX" )
        formatter.timeZone   = TimeZone( identifier: "UTC" )
        formatter.dateFormat = "yyyy-MM-dd HH:mm 'UTC'"

        return formatter.string( from: date )
    }
}

#Preview( "With data" )
{
    MoonPhaseView(
        location: GeographicLocation( latitude: 46.2, longitude: 6.15 ),
        date:     Date( timeIntervalSince1970: 1_706_204_040 ),
        target:   EquatorialCoordinate( rightAscension: 83.8221, declination: -5.3911 )
    )
    .frame( width: 260, height: 260 )
    .padding()
}

#Preview( "No location" )
{
    MoonPhaseView(
        location: nil,
        date:     Date( timeIntervalSince1970: 1_706_204_040 ),
        target:   EquatorialCoordinate( rightAscension: 83.8221, declination: -5.3911 )
    )
    .frame( width: 260, height: 260 )
    .padding()
}

#Preview( "No date" )
{
    MoonPhaseView( location: nil, date: nil, target: nil )
        .frame( width: 260, height: 200 )
        .padding()
}
