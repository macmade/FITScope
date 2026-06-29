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

/// The historical weather at a capture's time and place: the decoded, unit-bearing
/// reading the Weather tab shows. Temperatures are in °C and wind speed in m/s,
/// matching the units ``OpenMeteoClient`` requests.
///
/// A `Sendable`, `Equatable` value: the non-`Sendable` decoding types never leave
/// the client, only this mapped result does.
public struct WeatherConditions: Sendable, Equatable
{
    /// The moment the reading describes (the capture hour, in UTC).
    public let date: Date

    /// The temperature, in °C.
    public let temperatureCelsius: Double

    /// The apparent ("feels like") temperature, in °C.
    public let feelsLikeCelsius: Double

    /// The relative humidity, as a percentage.
    public let humidityPercent: Int

    /// The atmospheric pressure, in hPa.
    public let pressureHPa: Int

    /// The cloud cover, as a percentage.
    public let cloudCoverPercent: Int

    /// The wind speed, in m/s.
    public let windSpeedMetersPerSecond: Double

    /// The wind direction, in meteorological degrees (the direction the wind blows
    /// from).
    public let windDirectionDegrees: Int

    /// The dew point, in °C.
    public let dewPointCelsius: Double

    /// The WMO weather-interpretation code.
    public let weatherCode: Int

    /// Whether the reading is during daytime — selects the day or night symbol.
    public let isDay: Bool

    /// The human-readable condition, derived from ``weatherCode``, e.g.
    /// `"Partly cloudy"`.
    public var conditionDescription: String
    {
        Self.description( forWMOCode: self.weatherCode )
    }

    /// The SF Symbol representing the condition, derived from ``weatherCode`` and
    /// ``isDay``.
    public var systemImageName: String
    {
        Self.symbolName( forWMOCode: self.weatherCode, isDay: self.isDay )
    }

    /// Creates a conditions value.
    public init(
        date:                     Date,
        temperatureCelsius:       Double,
        feelsLikeCelsius:         Double,
        humidityPercent:          Int,
        pressureHPa:              Int,
        cloudCoverPercent:        Int,
        windSpeedMetersPerSecond: Double,
        windDirectionDegrees:     Int,
        dewPointCelsius:          Double,
        weatherCode:              Int,
        isDay:                    Bool
    )
    {
        self.date                     = date
        self.temperatureCelsius       = temperatureCelsius
        self.feelsLikeCelsius         = feelsLikeCelsius
        self.humidityPercent          = humidityPercent
        self.pressureHPa              = pressureHPa
        self.cloudCoverPercent        = cloudCoverPercent
        self.windSpeedMetersPerSecond = windSpeedMetersPerSecond
        self.windDirectionDegrees     = windDirectionDegrees
        self.dewPointCelsius          = dewPointCelsius
        self.weatherCode              = weatherCode
        self.isDay                    = isDay
    }

    /// The SF Symbol for a WMO weather code.
    ///
    /// Clear-sky and partly-cloudy codes use distinct day / night SF Symbols via
    /// ``isDay``; the rest are independent of the time of day. An unrecognised code
    /// falls back to a generic cloud.
    ///
    /// - Parameters:
    ///   - code:  The WMO weather code.
    ///   - isDay: Whether the reading is during daytime.
    /// - Returns: The SF Symbol name.
    public static func symbolName( forWMOCode code: Int, isDay: Bool ) -> String
    {
        switch code
        {
            case 0,
                 1:          return isDay ? "sun.max"        : "moon.stars"  // Clear / mainly clear
            case 2:             return isDay ? "cloud.sun"      : "cloud.moon"  // Partly cloudy
            case 3:             return "cloud.fill"                             // Overcast
            case 45,
                 48:        return "cloud.fog"                              // Fog
            case 51,
                 53,
                 55:    return "cloud.drizzle"                          // Drizzle
            case 56,
                 57:        return "cloud.sleet"                            // Freezing drizzle
            case 61,
                 63,
                 65:    return "cloud.rain"                             // Rain
            case 66,
                 67:        return "cloud.sleet"                            // Freezing rain
            case 71,
                 73,
                 75,
                 77: return "cloud.snow"                           // Snow
            case 80,
                 81,
                 82:    return isDay ? "cloud.sun.rain" : "cloud.moon.rain"  // Rain showers
            case 85,
                 86:        return "cloud.snow"                             // Snow showers
            case 95,
                 96,
                 99:    return "cloud.bolt.rain"                        // Thunderstorm
            default:            return "cloud"
        }
    }

    /// The human-readable description for a WMO weather code, following Open-Meteo's
    /// documented interpretation.
    ///
    /// - Parameter code: The WMO weather code.
    /// - Returns: A short description, e.g. `"Partly cloudy"`.
    public static func description( forWMOCode code: Int ) -> String
    {
        switch code
        {
            case 0:  return "Clear sky"
            case 1:  return "Mainly clear"
            case 2:  return "Partly cloudy"
            case 3:  return "Overcast"
            case 45: return "Fog"
            case 48: return "Depositing rime fog"
            case 51: return "Light drizzle"
            case 53: return "Moderate drizzle"
            case 55: return "Dense drizzle"
            case 56: return "Light freezing drizzle"
            case 57: return "Dense freezing drizzle"
            case 61: return "Slight rain"
            case 63: return "Moderate rain"
            case 65: return "Heavy rain"
            case 66: return "Light freezing rain"
            case 67: return "Heavy freezing rain"
            case 71: return "Slight snowfall"
            case 73: return "Moderate snowfall"
            case 75: return "Heavy snowfall"
            case 77: return "Snow grains"
            case 80: return "Slight rain showers"
            case 81: return "Moderate rain showers"
            case 82: return "Violent rain showers"
            case 85: return "Slight snow showers"
            case 86: return "Heavy snow showers"
            case 95: return "Thunderstorm"
            case 96: return "Thunderstorm with slight hail"
            case 99: return "Thunderstorm with heavy hail"
            default: return "Unknown"
        }
    }
}
