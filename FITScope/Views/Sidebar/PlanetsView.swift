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

/// The Planets tab's content: which planets were above the horizon at the
/// capture instant, and where. Every naked-eye planet (Mercury–Saturn) is listed
/// with its altitude and compass direction; those above the horizon are shown in
/// full, those below are dimmed — all computed locally from the observing site
/// and date.
///
/// It owns its empty states so its host doesn't branch on the data.
public struct PlanetsView: View
{
    /// The observing site, or `nil` when the image has no coordinates.
    private let location: GeographicLocation?

    /// The capture date, or `nil` when the image has no date.
    private let date: Date?

    /// The opacity of a below-the-horizon planet's row, dimming it relative to the
    /// visible ones.
    private static let hiddenRowOpacity = 0.4

    /// Creates the planets view.
    ///
    /// - Parameters:
    ///   - location: The observing site, or `nil` when unknown.
    ///   - date:     The capture date (e.g. a frame's `DATE-OBS`), or `nil`.
    public init( location: GeographicLocation?, date: Date? )
    {
        self.location = location
        self.date     = date
    }

    /// The view's content: the planet table when a location and date are known,
    /// otherwise a placeholder for the missing piece. Both fill a bordered card so
    /// the tab keeps a stable shape.
    public var body: some View
    {
        Group
        {
            if let location = self.location, let date = self.date
            {
                self.content( location: location, date: date )
            }
            else if self.location == nil
            {
                StatusMessageView( systemImage: "location.slash", title: "No Location Data", message: "This image has no GPS coordinates." )
            }
            else
            {
                StatusMessageView( systemImage: "calendar", title: "No Date", message: "This image has no capture date." )
            }
        }
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .clipShape( RoundedRectangle( cornerRadius: 10 ) )
        .overlay( RoundedRectangle( cornerRadius: 10 ).strokeBorder( .quaternary, lineWidth: 0.5 ) )
        .accessibilityIdentifier( AccessibilityIdentifier.PlanetsView.container )
    }

    /// The visible-planet count headline, the per-planet table and the date.
    ///
    /// - Parameters:
    ///   - location: The observing site.
    ///   - date:     The capture date.
    private func content( location: GeographicLocation, date: Date ) -> some View
    {
        let positions    = Planet.allCases.map { ( planet: $0, coordinate: PlanetPosition.horizontal( of: $0, at: date, location: location ) ) }
        let visibleCount = positions.filter { $0.coordinate.isAboveHorizon }.count

        return VStack( spacing: 8 )
        {
            Image( systemName: "circles.hexagonpath" )
                .font( .system( size: 40 ) )
                .symbolRenderingMode( .hierarchical )
                .accessibilityIdentifier( AccessibilityIdentifier.PlanetsView.icon )

            Text( Self.headline( visibleCount: visibleCount, total: positions.count ) )
                .font( .system( size: 12, weight: .semibold ) )
                .multilineTextAlignment( .center )

            self.grid( positions )
                .padding( .top, 2 )

            Text( Self.dateText( date ) )
                .font( .system( size: 10 ) )
                .foregroundStyle( .tertiary )
        }
        .padding( 12 )
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .background( .regularMaterial )
        // Let the planet names, altitudes and directions be selected and copied,
        // matching the other info panels.
        .textSelection( .enabled )
    }

    /// The per-planet table: name, altitude and compass direction, with the
    /// below-the-horizon planets dimmed.
    ///
    /// - Parameter positions: Each planet paired with its horizontal coordinate.
    private func grid( _ positions: [ ( planet: Planet, coordinate: HorizontalCoordinate ) ] ) -> some View
    {
        Grid( alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3 )
        {
            GridRow
            {
                Text( "" )
                Text( "Alt." ).foregroundStyle( .secondary )
                Text( "Dir." ).foregroundStyle( .secondary )
            }

            ForEach( positions, id: \.planet )
            {
                entry in self.row( planet: entry.planet, coordinate: entry.coordinate )
            }
        }
        .font( .system( size: 10 ) )
    }

    /// One planet row: its astronomical symbol and name, altitude and compass
    /// direction, dimmed when the planet is below the horizon.
    ///
    /// - Parameters:
    ///   - planet:     The planet.
    ///   - coordinate: Its horizontal position.
    /// - Returns: The grid row.
    private func row( planet: Planet, coordinate: HorizontalCoordinate ) -> some View
    {
        GridRow
        {
            HStack( spacing: 5 )
            {
                // The Unicode planet glyphs render smaller than the SF Symbols in
                // the other tabs' rows, so bump the size to match their weight.
                Text( planet.symbol )
                    .font( .system( size: 14 ) )
                    .foregroundStyle( .secondary )
                    .frame( width: 14 )

                Text( planet.name )
            }

            Text( Self.altitudeText( coordinate.altitude ) )
            Text( CompassDirection.abbreviation( forAzimuth: coordinate.azimuth ) )
        }
        .opacity( coordinate.isAboveHorizon ? 1 : Self.hiddenRowOpacity )
    }

    /// The visible-planet summary line, e.g. `3 of 5 above the horizon`, or a
    /// clear message when none are up.
    ///
    /// - Parameters:
    ///   - visibleCount: How many planets are above the horizon.
    ///   - total:        The total number of planets listed.
    private static func headline( visibleCount: Int, total: Int ) -> String
    {
        visibleCount == 0 ? "No planets above the horizon" : "\( visibleCount ) of \( total ) above the horizon"
    }

    /// A signed whole-degree altitude, e.g. `+34°` or `−12°`.
    ///
    /// - Parameter altitude: The altitude, in degrees.
    private static func altitudeText( _ altitude: Double ) -> String
    {
        String( format: "%+.0f°", altitude )
    }

    /// The capture date formatted in UTC (the time zone `DATE-OBS` is recorded
    /// in), e.g. `2024-01-25 22:00 UTC`.
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
    PlanetsView(
        location: GeographicLocation( latitude: 46.2, longitude: 6.15 ),
        date:     Date( timeIntervalSince1970: 1_706_220_000 )
    )
    .frame( width: 260, height: 240 )
    .padding()
}

#Preview( "No location" )
{
    PlanetsView( location: nil, date: Date() )
        .frame( width: 260, height: 240 )
        .padding()
}
