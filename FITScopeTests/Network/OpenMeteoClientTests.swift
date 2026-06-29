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

@testable import FITScope
import Foundation
import Testing

/// Tests for ``OpenMeteoClient``: the Open-Meteo historical-archive flow. Every
/// request is served by a scripted ``MockOpenMeteoTransport`` so the client's
/// request building, response decoding, hour selection, error mapping, and caching
/// are verified against the documented wire format without ever touching the
/// network.
@Suite( "OpenMeteoClient" )
struct OpenMeteoClientTests
{
    /// A capture at 18:30 UTC on 2024-01-25 — within the fixture's 18:00 hour.
    private static let date = Date( timeIntervalSince1970: 1_706_207_400 )

    /// The fixture's 18:00 reading is at index 2.
    private static let captureHour = Date( timeIntervalSince1970: 1_706_205_600 )

    /// A request builds the documented `/v1/archive` URL: the path with `latitude`,
    /// `longitude`, the capture day as `start_date`/`end_date`, the `hourly`
    /// variables, `wind_speed_unit=ms`, and `timezone=GMT`.
    @Test
    func buildsArchiveRequest() async throws
    {
        let transport = MockOpenMeteoTransport { _ in ( 200, OpenMeteoFixtures.archiveSuccess ) }
        let client    = OpenMeteoClient( transport: transport )

        _ = try await client.conditions( latitude: 46.2, longitude: 6.15, date: Self.date )

        let request    = try #require( await transport.requests.first )
        let url        = try #require( request.url )
        let components = try #require( URLComponents( url: url, resolvingAgainstBaseURL: false ) )
        let items      = Dictionary( uniqueKeysWithValues: ( components.queryItems ?? [] ).compactMap { item in item.value.map { ( item.name, $0 ) } } )

        #expect( components.path == "/v1/archive" )
        #expect( items[ "latitude" ] == "46.2" )
        #expect( items[ "longitude" ] == "6.15" )
        #expect( items[ "start_date" ] == "2024-01-25" )
        #expect( items[ "end_date" ] == "2024-01-25" )
        #expect( items[ "wind_speed_unit" ] == "ms" )
        #expect( items[ "timezone" ] == "GMT" )
        #expect( items[ "hourly" ]?.contains( "cloud_cover" ) == true )
        #expect( items[ "hourly" ]?.contains( "weather_code" ) == true )
    }

    /// The response decodes into the mapped ``WeatherConditions`` for the capture
    /// hour (18:00, index 2), with the surface pressure rounded to a whole hPa and
    /// the night `is_day` flag mapped to `false`.
    @Test
    func decodesConditionsForCaptureHour() async throws
    {
        let transport  = MockOpenMeteoTransport { _ in ( 200, OpenMeteoFixtures.archiveSuccess ) }
        let client     = OpenMeteoClient( transport: transport )
        let conditions = try await client.conditions( latitude: 46.2, longitude: 6.15, date: Self.date )

        #expect( conditions.date == Self.captureHour )
        #expect( conditions.temperatureCelsius == 6.1 )
        #expect( conditions.feelsLikeCelsius == 3.7 )
        #expect( conditions.humidityPercent == 92 )
        #expect( conditions.pressureHPa == 982 )
        #expect( conditions.cloudCoverPercent == 73 )
        #expect( conditions.windSpeedMetersPerSecond == 2.13 )
        #expect( conditions.windDirectionDegrees == 229 )
        #expect( conditions.dewPointCelsius == 4.8 )
        #expect( conditions.weatherCode == 2 )
        #expect( conditions.isDay == false )
    }

    /// The client selects the capture's hour, not the first reading in the array:
    /// a 17:00 capture maps to index 1.
    @Test
    func picksTheCaptureHourNotTheFirst() async throws
    {
        let transport  = MockOpenMeteoTransport { _ in ( 200, OpenMeteoFixtures.archiveSuccess ) }
        let client     = OpenMeteoClient( transport: transport )
        let seventeen  = Date( timeIntervalSince1970: 1_706_202_000 )
        let conditions = try await client.conditions( latitude: 46.2, longitude: 6.15, date: seventeen )

        #expect( conditions.temperatureCelsius == 6.5 )
        #expect( conditions.cloudCoverPercent == 60 )
    }

    /// A non-success status surfaces as ``OpenMeteoError/requestFailed(status:)``.
    @Test
    func httpErrorThrowsRequestFailed() async
    {
        let transport = MockOpenMeteoTransport { _ in ( 500, Data() ) }
        let client    = OpenMeteoClient( transport: transport )

        await #expect( throws: OpenMeteoError.requestFailed( status: 500 ) )
        {
            _ = try await client.conditions( latitude: 46.2, longitude: 6.15, date: Self.date )
        }
    }

    /// A capture whose hour is absent from the returned day maps to
    /// ``OpenMeteoError/noData``.
    @Test
    func missingHourThrowsNoData() async
    {
        let transport = MockOpenMeteoTransport { _ in ( 200, OpenMeteoFixtures.archiveSuccess ) }
        let client    = OpenMeteoClient( transport: transport )
        let fiveAM    = Date( timeIntervalSince1970: 1_706_158_800 )

        await #expect( throws: OpenMeteoError.noData )
        {
            _ = try await client.conditions( latitude: 46.2, longitude: 6.15, date: fiveAM )
        }
    }

    /// A body that cannot be decoded maps to ``OpenMeteoError/invalidResponse``.
    @Test
    func invalidJSONThrowsInvalidResponse() async
    {
        let transport = MockOpenMeteoTransport { _ in ( 200, Data( "not json".utf8 ) ) }
        let client    = OpenMeteoClient( transport: transport )

        await #expect( throws: OpenMeteoError.invalidResponse )
        {
            _ = try await client.conditions( latitude: 46.2, longitude: 6.15, date: Self.date )
        }
    }

    /// A second request for the same coordinate and hour is served from the
    /// in-memory cache, so the historical value (which never changes) is fetched
    /// only once.
    @Test
    func cachesByCoordinateAndHour() async throws
    {
        let transport = MockOpenMeteoTransport { _ in ( 200, OpenMeteoFixtures.archiveSuccess ) }
        let client    = OpenMeteoClient( transport: transport )

        let first  = try await client.conditions( latitude: 46.2, longitude: 6.15, date: Self.date )
        let second = try await client.conditions( latitude: 46.2, longitude: 6.15, date: Self.date )

        #expect( first == second )
        #expect( await transport.requests.count == 1 )
    }
}
