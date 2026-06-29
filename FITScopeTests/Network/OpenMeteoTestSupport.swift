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

/// A scripted ``OpenMeteoTransport`` for exercising ``OpenMeteoClient`` without any
/// live network.
///
/// Every request is recorded for later assertions, and the response is produced by
/// an injected handler that receives the request — so a test can assert the
/// constructed URL and return a chosen status and body. It is an `actor` so the
/// recorded requests stay race-free across the client's concurrent use.
actor MockOpenMeteoTransport: OpenMeteoTransport
{
    /// Produces a response for a request.
    ///
    /// - Returns: The HTTP status code and the raw response body.
    typealias Handler = @Sendable ( URLRequest ) throws -> ( status: Int, body: Data )

    /// The injected response producer.
    private let handler: Handler

    /// Every request the client has made, in order, for assertions.
    private( set ) var requests: [ URLRequest ] = []

    /// Creates a transport driven by the given handler.
    ///
    /// - Parameter handler: Produces a status and body per request.
    init( handler: @escaping Handler )
    {
        self.handler = handler
    }

    func data( for request: URLRequest ) async throws -> ( Data, HTTPURLResponse )
    {
        self.requests.append( request )

        let ( status, body ) = try self.handler( request )

        guard let url = request.url,
              let response = HTTPURLResponse( url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil )
        else
        {
            throw URLError( .badServerResponse )
        }

        return ( body, response )
    }
}

/// Recorded JSON response bodies from the Open-Meteo historical archive, used as
/// fixtures.
///
/// The shape mirrors the documented `/v1/archive` response at
/// `https://open-meteo.com/en/docs/historical-weather-api`, captured here so the
/// client's decoding and hour-selection are verified against the real wire format
/// without a live call. Three hours are included so a test can confirm the client
/// picks the capture hour rather than the first reading.
enum OpenMeteoFixtures
{
    /// A successful `/v1/archive` response covering 16:00–18:00 UTC on
    /// 2024-01-25, in the requested units (°C, hPa, m/s).
    static let archiveSuccess = Self.data(
        #"""
        {
            "latitude": 46.2,
            "longitude": 6.15,
            "utc_offset_seconds": 0,
            "timezone": "GMT",
            "hourly_units": {
                "time": "iso8601",
                "temperature_2m": "°C",
                "wind_speed_10m": "m/s"
            },
            "hourly": {
                "time": [ "2024-01-25T16:00", "2024-01-25T17:00", "2024-01-25T18:00" ],
                "temperature_2m": [ 7.0, 6.5, 6.1 ],
                "apparent_temperature": [ 4.5, 4.0, 3.7 ],
                "relative_humidity_2m": [ 90, 91, 92 ],
                "dew_point_2m": [ 4.2, 4.5, 4.8 ],
                "cloud_cover": [ 40, 60, 73 ],
                "surface_pressure": [ 982.0, 981.8, 981.5 ],
                "wind_speed_10m": [ 2.0, 2.1, 2.13 ],
                "wind_direction_10m": [ 200, 215, 229 ],
                "weather_code": [ 1, 2, 2 ],
                "is_day": [ 1, 0, 0 ]
            }
        }
        """#
    )

    /// Encodes a JSON string literal as UTF-8 data.
    private static func data( _ json: String ) -> Data
    {
        Data( json.utf8 )
    }
}
