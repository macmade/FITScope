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

/// A namespace for the decoded Open-Meteo historical-archive responses. The shapes
/// mirror the documented response at
/// `https://open-meteo.com/en/docs/historical-weather-api`, captured here so the
/// client decodes the real wire format. The wire uses the service's own snake-case
/// field names, mapped to Swift names via `CodingKeys`.
enum OpenMeteoResponse
{
    /// The `/v1/archive` response: an `hourly` block of parallel arrays, one entry
    /// per hour of the requested day.
    struct Archive: Decodable
    {
        /// The hourly readings.
        let hourly: Hourly
    }

    /// The hourly block: parallel arrays sharing the index of ``time``. Numeric
    /// units follow the request (the client requests °C, hPa and m/s).
    struct Hourly: Decodable
    {
        /// The reading times, as ISO-8601 `yyyy-MM-dd'T'HH:mm` strings in UTC.
        let time: [ String ]

        /// The air temperature at 2 m, in °C.
        let temperature2m: [ Double ]

        /// The apparent ("feels like") temperature, in °C.
        let apparentTemperature: [ Double ]

        /// The relative humidity at 2 m, as a percentage.
        let relativeHumidity2m: [ Int ]

        /// The dew point at 2 m, in °C.
        let dewPoint2m: [ Double ]

        /// The total cloud cover, as a percentage.
        let cloudCover: [ Int ]

        /// The surface pressure, in hPa.
        let surfacePressure: [ Double ]

        /// The wind speed at 10 m, in m/s.
        let windSpeed10m: [ Double ]

        /// The wind direction at 10 m, in meteorological degrees.
        let windDirection10m: [ Int ]

        /// The WMO weather-interpretation code.
        let weatherCode: [ Int ]

        /// Whether each hour is daytime (`1`) or night (`0`).
        let isDay: [ Int ]

        private enum CodingKeys: String, CodingKey
        {
            case time
            case temperature2m       = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case relativeHumidity2m  = "relative_humidity_2m"
            case dewPoint2m          = "dew_point_2m"
            case cloudCover          = "cloud_cover"
            case surfacePressure     = "surface_pressure"
            case windSpeed10m        = "wind_speed_10m"
            case windDirection10m    = "wind_direction_10m"
            case weatherCode         = "weather_code"
            case isDay               = "is_day"
        }
    }
}
