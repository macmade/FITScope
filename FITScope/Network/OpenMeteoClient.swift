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

/// The HTTP transport ``OpenMeteoClient`` sends requests through.
///
/// Abstracting the network behind this seam lets the client be driven by a
/// scripted transport in tests, so request building and response decoding are
/// verified against the documented wire format without a live connection. The
/// production conformance reuses ``URLSessionTransport`` (declared below), so no
/// session glue is duplicated.
public protocol OpenMeteoTransport: Sendable
{
    /// Sends a request and returns its body and HTTP response.
    ///
    /// - Parameter request: The request to send.
    /// - Returns: The response body and the HTTP response.
    /// - Throws: Any transport-level error (e.g. no connection).
    func data( for request: URLRequest ) async throws -> ( Data, HTTPURLResponse )
}

/// The shared production transport already used for plate solving satisfies the
/// weather transport too — its `data(for:)` has the same shape — so the weather
/// client reuses it without duplicating any `URLSession` glue.
extension URLSessionTransport: OpenMeteoTransport {}

/// A client for the Open-Meteo historical-weather archive: look up the conditions
/// at a capture's time and place. The archive is free and keyless (ERA5
/// reanalysis), so no API key is needed.
///
/// All network access goes through an injected ``OpenMeteoTransport``, so the flow
/// is exercised in tests against scripted responses without a live connection.
/// Results are cached in memory by coordinate and hour — a historical reading
/// never changes — so revisiting a file does not refetch. HTTPS is used so the
/// sandboxed app's requests satisfy App Transport Security.
public actor OpenMeteoClient
{
    /// The transport requests are sent through.
    private let transport: OpenMeteoTransport

    /// The service root, e.g. `https://archive-api.open-meteo.com`.
    private let baseURL: URL

    /// Cached readings, keyed by coordinate and hour, so an identical lookup is
    /// served without another request.
    private var cache: [ String: WeatherConditions ] = [ : ]

    /// The hourly variables requested, in the wire's field names.
    private static let hourlyVariables = "temperature_2m,apparent_temperature,relative_humidity_2m,dew_point_2m,cloud_cover,surface_pressure,wind_speed_10m,wind_direction_10m,weather_code,is_day"

    /// The default service root.
    public static let defaultBaseURL = URL( string: "https://archive-api.open-meteo.com" ) ?? URL( fileURLWithPath: "/" )

    /// The shared client the UI uses, so its cache is reused across windows.
    public static let shared = OpenMeteoClient()

    /// Creates a client.
    ///
    /// - Parameters:
    ///   - transport: The HTTP transport. Defaults to a `URLSession`-backed
    ///                transport; tests inject a scripted one.
    ///   - baseURL:   The service root. Defaults to ``defaultBaseURL``.
    public init( transport: OpenMeteoTransport = URLSessionTransport(), baseURL: URL = OpenMeteoClient.defaultBaseURL )
    {
        self.transport = transport
        self.baseURL   = baseURL
    }

    /// Fetches the historical weather at a coordinate and moment.
    ///
    /// - Parameters:
    ///   - latitude:  The latitude, in decimal degrees.
    ///   - longitude: The longitude, in decimal degrees.
    ///   - date:      The capture moment; the reading for its hour (UTC) is
    ///                returned.
    /// - Returns: The conditions at that time and place.
    /// - Throws: ``OpenMeteoError`` when the service refuses the request or the
    ///   response cannot be read; or `CancellationError` if the task is cancelled.
    public func conditions( latitude: Double, longitude: Double, date: Date ) async throws -> WeatherConditions
    {
        let hourKey  = Self.hourKey( for: date )
        let cacheKey = "\( latitude ),\( longitude ),\( hourKey )"

        if let cached = self.cache[ cacheKey ]
        {
            return cached
        }

        let request = try self.archiveRequest( latitude: latitude, longitude: longitude, date: date )
        let archive = try await self.decoded( request ) as OpenMeteoResponse.Archive

        guard let conditions = Self.conditions( from: archive.hourly, atHour: hourKey )
        else
        {
            throw OpenMeteoError.noData
        }

        self.cache[ cacheKey ] = conditions

        return conditions
    }

    // MARK: - Request building

    /// Builds the `/v1/archive` GET request for a coordinate and the capture's day.
    private func archiveRequest( latitude: Double, longitude: Double, date: Date ) throws -> URLRequest
    {
        guard var components = URLComponents( url: self.baseURL.appendingPathComponent( "v1/archive" ), resolvingAgainstBaseURL: false )
        else
        {
            throw OpenMeteoError.invalidResponse
        }

        let day = Self.dayKey( for: date )

        components.queryItems =
            [
                URLQueryItem( name: "latitude",        value: "\( latitude )" ),
                URLQueryItem( name: "longitude",       value: "\( longitude )" ),
                URLQueryItem( name: "start_date",      value: day ),
                URLQueryItem( name: "end_date",        value: day ),
                URLQueryItem( name: "hourly",          value: Self.hourlyVariables ),
                URLQueryItem( name: "wind_speed_unit", value: "ms" ),
                URLQueryItem( name: "timezone",        value: "GMT" ),
            ]

        guard let url = components.url
        else
        {
            throw OpenMeteoError.invalidResponse
        }

        return URLRequest( url: url )
    }

    // MARK: - Mapping

    /// Builds the conditions for a given hour from the parallel hourly arrays, or
    /// `nil` when that hour is absent or an array is too short.
    ///
    /// - Parameters:
    ///   - hourly: The decoded hourly block.
    ///   - hour:   The hour key to find, e.g. `2024-01-25T18:00`.
    /// - Returns: The mapped conditions, or `nil` when the hour has no full reading.
    private static func conditions( from hourly: OpenMeteoResponse.Hourly, atHour hour: String ) -> WeatherConditions?
    {
        guard let index = hourly.time.firstIndex( of: hour ), let date = Self.date( fromHour: hour )
        else
        {
            return nil
        }

        let arrays: [ Int ] =
            [
                hourly.temperature2m.count,
                hourly.apparentTemperature.count,
                hourly.relativeHumidity2m.count,
                hourly.dewPoint2m.count,
                hourly.cloudCover.count,
                hourly.surfacePressure.count,
                hourly.windSpeed10m.count,
                hourly.windDirection10m.count,
                hourly.weatherCode.count,
                hourly.isDay.count,
            ]

        guard arrays.allSatisfy( { index < $0 } )
        else
        {
            return nil
        }

        return WeatherConditions(
            date:                     date,
            temperatureCelsius:       hourly.temperature2m[ index ],
            feelsLikeCelsius:         hourly.apparentTemperature[ index ],
            humidityPercent:          hourly.relativeHumidity2m[ index ],
            pressureHPa:              Int( hourly.surfacePressure[ index ].rounded() ),
            cloudCoverPercent:        hourly.cloudCover[ index ],
            windSpeedMetersPerSecond: hourly.windSpeed10m[ index ],
            windDirectionDegrees:     hourly.windDirection10m[ index ],
            dewPointCelsius:          hourly.dewPoint2m[ index ],
            weatherCode:              hourly.weatherCode[ index ],
            isDay:                    hourly.isDay[ index ] != 0
        )
    }

    // MARK: - Date keys

    /// The hour key matching a date, e.g. `2024-01-25T18:00` — the format Open-Meteo
    /// labels its hourly readings with, floored to the hour, in UTC.
    ///
    /// - Parameter date: The capture moment.
    /// - Returns: The hour key string.
    static func hourKey( for date: Date ) -> String
    {
        Self.formatter( "yyyy-MM-dd'T'HH:00" ).string( from: date )
    }

    /// The day key matching a date, e.g. `2024-01-25`, in UTC.
    ///
    /// - Parameter date: The capture moment.
    /// - Returns: The day key string.
    static func dayKey( for date: Date ) -> String
    {
        Self.formatter( "yyyy-MM-dd" ).string( from: date )
    }

    /// Parses an hour key (`yyyy-MM-dd'T'HH:mm`, UTC) back to its date.
    private static func date( fromHour hour: String ) -> Date?
    {
        Self.formatter( "yyyy-MM-dd'T'HH:mm" ).date( from: hour )
    }

    /// A fixed-format UTC formatter for the given pattern.
    private static func formatter( _ format: String ) -> DateFormatter
    {
        let formatter        = DateFormatter()
        formatter.locale     = Locale( identifier: "en_US_POSIX" )
        formatter.timeZone   = TimeZone( identifier: "UTC" )
        formatter.dateFormat = format

        return formatter
    }

    // MARK: - Sending & decoding

    /// Sends a request and decodes its JSON body into the inferred type, mapping a
    /// non-success status to ``OpenMeteoError/requestFailed(status:)``.
    private func decoded< T: Decodable >( _ request: URLRequest ) async throws -> T
    {
        let ( data, response ) = try await self.transport.data( for: request )

        guard ( 200 ..< 300 ).contains( response.statusCode )
        else
        {
            throw OpenMeteoError.requestFailed( status: response.statusCode )
        }

        do
        {
            return try JSONDecoder().decode( T.self, from: data )
        }
        catch
        {
            throw OpenMeteoError.invalidResponse
        }
    }
}
