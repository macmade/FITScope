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

import MapKit
import SwiftUI

/// The Weather tab's content: the historical weather at the capture's time and
/// place, fetched from Open-Meteo's free archive — the condition, temperature,
/// cloud cover, humidity, wind, pressure and dew point — or a placeholder when
/// there is nothing to fetch (no coordinates, no date) or the lookup fails.
///
/// It owns all of its states so its host doesn't branch on the data. It fetches
/// only while its tab is active, and the client caches each reading so revisiting
/// the tab does not refetch.
public struct WeatherView: View
{
    /// The fetch state of the weather lookup.
    private enum Phase
    {
        /// Not yet fetched, or fetching.
        case loading

        /// Fetched successfully.
        case loaded( WeatherConditions )

        /// The fetch failed; carries the message to show.
        case failed( String )
    }

    /// The capture coordinate, or `nil` when the image has no observing-site
    /// coordinates.
    private let coordinate: CLLocationCoordinate2D?

    /// The capture date, or `nil` when the image has no date.
    private let date: Date?

    /// Whether this tab is the visible one. The fetch runs only while active so an
    /// unviewed tab never makes a request.
    private let isActive: Bool

    /// The client the conditions are fetched from.
    private let client: OpenMeteoClient

    /// The current fetch state.
    @State private var phase = Phase.loading

    /// The ``dataKey`` the current ``phase`` was loaded for, so a re-run for the
    /// same image (e.g. switching tabs away and back) is not refetched, while a
    /// re-run for a different image (selecting another file) is.
    @State private var loadedKey: String?

    /// Creates the weather view.
    ///
    /// - Parameters:
    ///   - coordinate: The capture location, or `nil` when unknown.
    ///   - date:       The capture date, or `nil` when unknown.
    ///   - isActive:   Whether the tab is currently visible (gates the fetch).
    ///   - client:     The client to fetch from. Defaults to the shared client.
    public init( coordinate: CLLocationCoordinate2D?, date: Date?, isActive: Bool, client: OpenMeteoClient = .shared )
    {
        self.coordinate = coordinate
        self.date       = date
        self.isActive   = isActive
        self.client     = client
    }

    /// The view's content: the conditions when a coordinate and date are present and
    /// the lookup succeeds, otherwise a placeholder for the missing piece or the
    /// failure. Filling a bordered card so the tab keeps a stable shape.
    public var body: some View
    {
        Group
        {
            if self.coordinate == nil
            {
                StatusMessageView( systemImage: "location.slash", title: "No Location Data", message: "This image has no GPS coordinates." )
            }
            else if self.date == nil
            {
                StatusMessageView( systemImage: "calendar", title: "No Date", message: "This image has no capture date." )
            }
            else
            {
                self.fetchedContent
            }
        }
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .clipShape( RoundedRectangle( cornerRadius: 10 ) )
        .overlay( RoundedRectangle( cornerRadius: 10 ).strokeBorder( .white.opacity( 0.08 ), lineWidth: 1 ) )
        .accessibilityIdentifier( AccessibilityIdentifier.WeatherView.container )
    }

    /// The fetched state: a spinner while loading, the conditions when loaded, or
    /// the failure placeholder — driving the lookup from a tab-gated task.
    private var fetchedContent: some View
    {
        Group
        {
            switch self.phase
            {
                case .loading:

                    ProgressView()
                        .controlSize( .small )
                        .frame( maxWidth: .infinity, maxHeight: .infinity )
                        .background( .regularMaterial )

                case .loaded( let conditions ):

                    self.conditions( conditions )

                case .failed( let message ):

                    StatusMessageView( systemImage: "wifi.slash", title: "Weather Unavailable", message: message )
            }
        }
        .task( id: self.taskID )
        {
            await self.load()
        }
    }

    /// The conditions layout: the condition symbol and description, the temperature
    /// and date, then a grid of the values that matter for imaging (cloud cover,
    /// humidity, wind, pressure, dew point).
    ///
    /// - Parameter conditions: The fetched conditions.
    private func conditions( _ conditions: WeatherConditions ) -> some View
    {
        VStack( spacing: 8 )
        {
            Image( systemName: conditions.systemImageName )
                .font( .system( size: 40 ) )
                .symbolRenderingMode( .multicolor )
                .accessibilityIdentifier( AccessibilityIdentifier.WeatherView.icon )

            Text( conditions.conditionDescription )
                .font( .system( size: 12, weight: .semibold ) )
                .multilineTextAlignment( .center )

            Text( Self.temperatureText( conditions ) )
                .font( .system( size: 11 ) )
                .foregroundStyle( .secondary )

            Grid( alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3 )
            {
                self.row( systemImage: "cloud",                  label: "Clouds",    value: "\( conditions.cloudCoverPercent )%" )
                self.row( systemImage: "humidity",               label: "Humidity",  value: "\( conditions.humidityPercent )%" )
                self.row( systemImage: "wind",                   label: "Wind",      value: Self.windText( conditions ) )
                self.row( systemImage: "barometer",              label: "Pressure",  value: "\( conditions.pressureHPa ) hPa" )
                self.row( systemImage: "thermometer.snowflake",  label: "Dew Point", value: Self.temperature( conditions.dewPointCelsius ) )
            }
            .padding( .top, 2 )

            Text( Self.dateText( conditions.date ) )
                .font( .system( size: 10 ) )
                .foregroundStyle( .tertiary )

            self.attribution
        }
        .padding( 12 )
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .background( .regularMaterial )
        // Let the condition, temperature, per-metric rows and date be selected
        // and copied, matching the Image Information panel.
        .textSelection( .enabled )
    }

    /// The data-source credit shown at the bottom of the conditions card: a small
    /// clickable link to Open-Meteo, whose free archive supplies the data (and whose
    /// licence asks for attribution).
    private var attribution: some View
    {
        Text( "Weather data by [Open-Meteo.com](https://open-meteo.com)" )
            .font( .system( size: 9 ) )
            .foregroundStyle( .tertiary )
            .tint( .secondary )
            .padding( .top, 2 )
            // The attribution credit/link is not informational data, so exclude
            // it from the selection enabled on the conditions card above.
            .textSelection( .disabled )
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
                    .foregroundStyle( .secondary )
                    .frame( width: 12 )

                Text( label )
                    .foregroundStyle( .secondary )
            }

            Text( value )
        }
        .font( .system( size: 10 ) )
    }

    /// The identity of the image being described: the coordinate and capture hour.
    /// Drives both the cache check and the task identity, so a different image
    /// refetches while the same image does not.
    private var dataKey: String
    {
        let latitude  = self.coordinate?.latitude  ?? 0
        let longitude = self.coordinate?.longitude ?? 0
        let timestamp = self.date.map { Int( $0.timeIntervalSince1970 ) } ?? 0

        return "\( latitude )|\( longitude )|\( timestamp )"
    }

    /// An identity for the fetch task: it re-runs when the image or the active state
    /// changes, so both selecting another file and activating the tab trigger the
    /// (cached) lookup.
    private var taskID: String
    {
        "\( self.isActive )|\( self.dataKey )"
    }

    /// Fetches the conditions, but only while the tab is active, and skips the fetch
    /// when this image is already loaded (so toggling tabs doesn't refetch) while
    /// still fetching when a different image is selected. Maps any failure to a
    /// presentable message.
    private func load() async
    {
        guard self.isActive, let coordinate = self.coordinate, let date = self.date
        else
        {
            return
        }

        let key = self.dataKey

        if self.loadedKey == key, case .loaded = self.phase
        {
            return
        }

        self.phase = .loading

        do
        {
            let conditions = try await self.client.conditions( latitude: coordinate.latitude, longitude: coordinate.longitude, date: date )

            self.phase     = .loaded( conditions )
            self.loadedKey = key
        }
        catch is CancellationError
        {
            // The task was superseded; leave the state for the new task to set.
        }
        catch
        {
            let message = ( error as? LocalizedError )?.errorDescription ?? error.localizedDescription

            self.phase     = .failed( message )
            self.loadedKey = nil
        }
    }

    /// The temperature line, e.g. `3°C (feels like 0°C)`.
    ///
    /// - Parameter conditions: The conditions to describe.
    private static func temperatureText( _ conditions: WeatherConditions ) -> String
    {
        "\( Self.temperature( conditions.temperatureCelsius ) ) (feels like \( Self.temperature( conditions.feelsLikeCelsius ) ))"
    }

    /// A temperature rounded to a whole degree Celsius, e.g. `3°C`.
    ///
    /// - Parameter celsius: The temperature, in °C.
    private static func temperature( _ celsius: Double ) -> String
    {
        "\( Int( celsius.rounded() ) )°C"
    }

    /// The wind line, e.g. `4 m/s WSW`.
    ///
    /// - Parameter conditions: The conditions to describe.
    private static func windText( _ conditions: WeatherConditions ) -> String
    {
        "\( Int( conditions.windSpeedMetersPerSecond.rounded() ) ) m/s \( Self.compass( conditions.windDirectionDegrees ) )"
    }

    /// The 16-point compass abbreviation for a meteorological wind direction.
    ///
    /// - Parameter degrees: The direction the wind blows from, in degrees.
    /// - Returns: The compass abbreviation, e.g. `WSW`.
    private static func compass( _ degrees: Int ) -> String
    {
        let points = [ "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW" ]
        let index  = Int( ( Double( degrees ).truncatingRemainder( dividingBy: 360 ) / 22.5 ).rounded() ) % points.count

        return points[ index ]
    }

    /// A date formatted in UTC (the time zone `DATE-OBS` is recorded in), e.g.
    /// `2024-01-25 17:00 UTC`.
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

#Preview
{
    WeatherView(
        coordinate: CLLocationCoordinate2D( latitude: 46.2, longitude: 6.15 ),
        date:       Date( timeIntervalSince1970: 1_706_204_040 ),
        isActive:   true
    )
    .frame( width: 260, height: 320 )
}
