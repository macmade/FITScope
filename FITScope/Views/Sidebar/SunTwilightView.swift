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

/// The Sun tab's content: the sky darkness at the capture instant (the key "was
/// it dark?" answer for an astrophotographer), followed by the day's
/// sunrise/sunset and the civil, nautical and astronomical twilight times — all
/// computed locally from the observing site and date — or a placeholder when the
/// image carries no location or date.
///
/// It owns both states so its host doesn't branch on the data.
public struct SunTwilightView: View
{
    /// The observing site, or `nil` when the image has no coordinates.
    private let location: GeographicLocation?

    /// The capture date, or `nil` when the image has no date.
    private let date: Date?

    /// Creates the sun & twilight view.
    ///
    /// - Parameters:
    ///   - location: The observing site, or `nil` when unknown.
    ///   - date:     The capture date (e.g. a frame's `DATE-OBS`), or `nil`.
    public init( location: GeographicLocation?, date: Date? )
    {
        self.location = location
        self.date     = date
    }

    /// The view's content: the sky darkness and twilight times when a location and
    /// date are known, otherwise a placeholder for the missing piece. Both fill a
    /// bordered card so the tab keeps a stable shape.
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
        .accessibilityIdentifier( AccessibilityIdentifier.SunTwilightView.container )
    }

    /// The capture-time sky condition, the twilight times grid and the date.
    ///
    /// - Parameters:
    ///   - location: The observing site.
    ///   - date:     The capture date.
    private func content( location: GeographicLocation, date: Date ) -> some View
    {
        let events    = TwilightEvents.compute( date: date, location: location )
        let altitude  = SolarPosition.horizontal( at: date, location: location ).altitude
        let condition = SkyCondition.forSunAltitude( altitude )

        return VStack( spacing: 8 )
        {
            Image( systemName: condition.systemImageName )
                .font( .system( size: 40 ) )
                .symbolRenderingMode( .multicolor )
                .accessibilityIdentifier( AccessibilityIdentifier.SunTwilightView.icon )

            Text( condition.label )
                .font( .system( size: 12, weight: .semibold ) )

            Text( Self.altitudeText( altitude ) )
                .font( .system( size: 10 ) )
                .foregroundStyle( .secondary )

            self.timesGrid( events )
                .padding( .top, 2 )

            Text( Self.dateText( date ) )
                .font( .system( size: 10 ) )
                .foregroundStyle( .tertiary )
        }
        .padding( 12 )
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .background( .regularMaterial )
        // Let the condition, altitude, times and date be selected and copied,
        // matching the other info panels.
        .textSelection( .enabled )
    }

    /// The dawn (morning) and dusk (evening) times, one row per threshold, with a
    /// dash for any event that does not occur that day (polar day/night).
    ///
    /// - Parameter events: The computed twilight events.
    private func timesGrid( _ events: TwilightEvents ) -> some View
    {
        Grid( alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3 )
        {
            GridRow
            {
                Text( "" )
                Text( "Dawn" ).foregroundStyle( .secondary )
                Text( "Dusk" ).foregroundStyle( .secondary )
            }

            self.row( systemImage: "sun.horizon", label: "Sun",          dawn: events.sunrise,          dusk: events.sunset )
            self.row( systemImage: "building",    label: "Civil",        dawn: events.civilDawn,        dusk: events.civilDusk )
            self.row( systemImage: "sailboat",    label: "Nautical",     dawn: events.nauticalDawn,     dusk: events.nauticalDusk )
            self.row( systemImage: "moon.stars",  label: "Astronomical", dawn: events.astronomicalDawn, dusk: events.astronomicalDusk )
        }
        .font( .system( size: 10 ) )
    }

    /// One threshold row: an icon evoking what the twilight is named for, its
    /// name, and its morning and evening times.
    ///
    /// - Parameters:
    ///   - systemImage: The SF Symbol shown beside the label.
    ///   - label:       The threshold's name.
    ///   - dawn:        The morning time, or `nil`.
    ///   - dusk:        The evening time, or `nil`.
    /// - Returns: The grid row.
    private func row( systemImage: String, label: String, dawn: Date?, dusk: Date? ) -> some View
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

            Text( Self.timeText( dawn ) )
            Text( Self.timeText( dusk ) )
        }
    }

    /// The Sun's altitude as a sentence, e.g. `Sun 12.3° below horizon`.
    ///
    /// - Parameter altitude: The Sun's altitude, in degrees.
    private static func altitudeText( _ altitude: Double ) -> String
    {
        let magnitude = abs( altitude )
        let direction = altitude >= 0 ? "above" : "below"

        return String( format: "Sun %.1f° %@ horizon", magnitude, direction )
    }

    /// A time formatted in UTC, e.g. `05:24`, or a dash when the event is absent.
    ///
    /// - Parameter date: The event time, or `nil`.
    private static func timeText( _ date: Date? ) -> String
    {
        guard let date
        else
        {
            return "—"
        }

        let formatter        = DateFormatter()
        formatter.locale     = Locale( identifier: "en_US_POSIX" )
        formatter.timeZone   = TimeZone( identifier: "UTC" )
        formatter.dateFormat = "HH:mm"

        return formatter.string( from: date )
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
    SunTwilightView(
        location: GeographicLocation( latitude: 46.2, longitude: 6.15 ),
        date:     Date( timeIntervalSince1970: 1_706_220_000 )
    )
    .frame( width: 260, height: 240 )
    .padding()
}

#Preview( "No location" )
{
    SunTwilightView( location: nil, date: Date() )
        .frame( width: 260, height: 240 )
        .padding()
}
