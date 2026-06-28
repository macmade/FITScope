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

/// The failures a plate solve can surface, each with a message suitable for
/// presentation to the user.
public enum AstrometryError: LocalizedError, Equatable
{
    /// No Astrometry.net API key has been entered in Preferences.
    case missingAPIKey

    /// The service rejected the API key or otherwise refused to authenticate.
    case authenticationFailed( String? )

    /// The service returned a non-success HTTP status.
    case requestFailed( status: Int )

    /// The service replied with an application-level error message (its JSON
    /// `status` was not `success`).
    case serviceError( String )

    /// The service finished solving but could not solve the image.
    case solveFailed

    /// A response could not be decoded into the expected shape.
    case invalidResponse

    public var errorDescription: String?
    {
        switch self
        {
            case .missingAPIKey:

                return "No Astrometry.net API key is set. Add one in Preferences ▸ API Keys."

            case .authenticationFailed( let message ):

                return message.map { "Authentication with Astrometry.net failed: \( $0 )" } ?? "Authentication with Astrometry.net failed."

            case .requestFailed( let status ):

                return "Astrometry.net returned an unexpected response (HTTP \( status ))."

            case .serviceError( let message ):

                return "Astrometry.net reported an error: \( message )"

            case .solveFailed:

                return "Astrometry.net could not solve this image."

            case .invalidResponse:

                return "Astrometry.net returned a response that could not be read."
        }
    }
}
