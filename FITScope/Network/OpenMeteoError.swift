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

/// The failures a historical-weather lookup can surface, each with a message
/// suitable for presentation to the user.
///
/// Open-Meteo's historical archive is free and keyless, so there is no
/// missing-key or subscription failure — only request, data, and decoding
/// failures.
public enum OpenMeteoError: LocalizedError, Equatable
{
    /// The service returned a non-success HTTP status.
    case requestFailed( status: Int )

    /// The service returned no reading for the requested moment.
    case noData

    /// A response could not be decoded into the expected shape.
    case invalidResponse

    public var errorDescription: String?
    {
        switch self
        {
            case .requestFailed( let status ):

                return "Open-Meteo returned an unexpected response (HTTP \( status ))."

            case .noData:

                return "Open-Meteo has no weather reading for this date and location."

            case .invalidResponse:

                return "Open-Meteo returned a response that could not be read."
        }
    }
}
