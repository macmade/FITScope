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

import Combine
import Foundation

/// The app's API keys: an observable, Keychain-backed store shared across the
/// app's windows and the Preferences scene.
///
/// Each key is published so the API Keys settings update live, and writes flow
/// through to the Keychain so the secret survives across launches without ever
/// being written to source, `UserDefaults`, or logs. The backing store is
/// injected, defaulting to the system ``Keychain``, so tests exercise the
/// round-trip against an isolated, in-memory backend.
@MainActor
public final class APIKeyStore: ObservableObject
{
    /// The third-party services the app holds a key for. Each maps to a stable
    /// Keychain account name, independent of any UI label.
    public enum Service: CaseIterable
    {
        /// The Astrometry.net plate-solving service.
        case astrometryNet

        /// The OpenWeatherMap weather service.
        case openWeatherMap

        /// The Keychain account this service's key is stored under.
        public var account: String
        {
            switch self
            {
                case .astrometryNet:  return "astrometry.net"
                case .openWeatherMap: return "openweathermap.org"
            }
        }
    }

    /// The backing secure store. Reads seed the published keys at init; writes
    /// flow back through each property's `didSet`.
    private let keychain: KeychainStoring

    /// The Astrometry.net API key, or an empty string when none is stored.
    @Published public var astrometryNetKey: String
    {
        didSet { self.write( self.astrometryNetKey, for: .astrometryNet ) }
    }

    /// The OpenWeatherMap API key, or an empty string when none is stored.
    @Published public var openWeatherMapKey: String
    {
        didSet { self.write( self.openWeatherMapKey, for: .openWeatherMap ) }
    }

    /// Creates the store, seeding each key from the backend (empty when unset).
    ///
    /// - Parameter keychain: The backing secure store. Defaults to the system
    ///   ``Keychain``; tests inject an isolated, in-memory backend.
    public init( keychain: KeychainStoring = Keychain() )
    {
        self.keychain = keychain

        self.astrometryNetKey  = keychain.string( forAccount: Service.astrometryNet.account )  ?? ""
        self.openWeatherMapKey = keychain.string( forAccount: Service.openWeatherMap.account ) ?? ""
    }

    /// Writes a key through to the backend, treating blank input as "no key" so a
    /// cleared field removes the secret rather than storing empty padding.
    private func write( _ value: String, for service: Service )
    {
        let trimmed = value.trimmingCharacters( in: .whitespacesAndNewlines )

        if trimmed.isEmpty
        {
            self.keychain.removeString( forAccount: service.account )
        }
        else
        {
            self.keychain.setString( trimmed, forAccount: service.account )
        }
    }
}
