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

/// The HTTP transport ``AstrometryClient`` sends requests through.
///
/// Abstracting the network behind this seam lets the client be driven by a
/// scripted transport in tests, so request encoding and response decoding are
/// verified against the documented wire format without a live connection.
public protocol AstrometryTransport: Sendable
{
    /// Sends a request and returns its body and HTTP response.
    ///
    /// - Parameter request: The request to send.
    /// - Returns: The response body and the HTTP response.
    /// - Throws: Any transport-level error (e.g. no connection).
    func data( for request: URLRequest ) async throws -> ( Data, HTTPURLResponse )
}

/// The production transport, backed by a `URLSession`.
public struct URLSessionTransport: AstrometryTransport
{
    /// The session used for requests.
    private let session: URLSession

    /// Creates a transport over the given session.
    ///
    /// - Parameter session: The session to use. Defaults to `.shared`.
    public init( session: URLSession = .shared )
    {
        self.session = session
    }

    public func data( for request: URLRequest ) async throws -> ( Data, HTTPURLResponse )
    {
        let ( data, response ) = try await self.session.data( for: request )

        guard let http = response as? HTTPURLResponse
        else
        {
            throw AstrometryError.invalidResponse
        }

        return ( data, http )
    }
}
