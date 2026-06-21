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

/// Tests for `APIKeyStore`: the secure, Keychain-backed API-key store. The store
/// is exercised against an in-memory backend conforming to the same
/// ``KeychainStoring`` protocol the real Keychain implementation does, so the
/// store's own logic (seeding, write-through, empty-means-delete, per-key
/// independence) is verified without ever touching the real login keychain —
/// mirroring how ``PreferencesTests`` injects an isolated `UserDefaults` suite.
@Suite( "APIKeyStore" )
struct APIKeyStoreTests
{
    /// An in-memory ``KeychainStoring`` — a real key/value store, not a
    /// behaviour-verifying mock — so the tests exercise `APIKeyStore`'s logic
    /// against genuine read/write/delete semantics.
    private final class InMemoryKeychain: KeychainStoring
    {
        private var storage: [ String: String ] = [ : ]

        func string( forAccount account: String ) -> String?
        {
            self.storage[ account ]
        }

        func setString( _ value: String, forAccount account: String )
        {
            self.storage[ account ] = value
        }

        func removeString( forAccount account: String )
        {
            self.storage.removeValue( forKey: account )
        }
    }

    /// With nothing stored, every key reads back as empty.
    @Test
    @MainActor
    func defaultsToEmptyKeys()
    {
        let store = APIKeyStore( keychain: InMemoryKeychain() )

        #expect( store.astrometryNetKey == "" )
        #expect( store.openWeatherMapKey == "" )
    }

    /// A stored key is written to the backend and read back by a fresh instance —
    /// the round-trip that proves the value survives across launches.
    @Test
    @MainActor
    func persistsKeysAcrossInstances()
    {
        let keychain = InMemoryKeychain()
        let store     = APIKeyStore( keychain: keychain )

        store.astrometryNetKey  = "astro-secret"
        store.openWeatherMapKey = "weather-secret"

        let reloaded = APIKeyStore( keychain: keychain )

        #expect( reloaded.astrometryNetKey  == "astro-secret" )
        #expect( reloaded.openWeatherMapKey == "weather-secret" )
    }

    /// Clearing a key removes it from the backend entirely rather than storing an
    /// empty string, so a fresh instance reads it back as empty.
    @Test
    @MainActor
    func clearingAKeyRemovesItFromTheBackend()
    {
        let keychain = InMemoryKeychain()
        let store     = APIKeyStore( keychain: keychain )

        store.astrometryNetKey = "astro-secret"

        #expect( keychain.string( forAccount: APIKeyStore.Service.astrometryNet.account ) == "astro-secret" )

        store.astrometryNetKey = ""

        #expect( keychain.string( forAccount: APIKeyStore.Service.astrometryNet.account ) == nil )

        let reloaded = APIKeyStore( keychain: keychain )

        #expect( reloaded.astrometryNetKey == "" )
    }

    /// Whitespace-only input is treated as no key: it is trimmed away and the
    /// entry is removed rather than persisting blank padding.
    @Test
    @MainActor
    func whitespaceOnlyInputClearsTheKey()
    {
        let keychain = InMemoryKeychain()
        let store     = APIKeyStore( keychain: keychain )

        store.openWeatherMapKey = "   "

        #expect( keychain.string( forAccount: APIKeyStore.Service.openWeatherMap.account ) == nil )
    }

    /// The two keys are stored under distinct accounts, so setting one never
    /// disturbs the other.
    @Test
    @MainActor
    func keysAreStoredIndependently()
    {
        let keychain = InMemoryKeychain()
        let store     = APIKeyStore( keychain: keychain )

        store.astrometryNetKey = "astro-secret"

        #expect( store.openWeatherMapKey == "" )
        #expect( keychain.string( forAccount: APIKeyStore.Service.openWeatherMap.account ) == nil )
    }
}
