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
import Security

/// The system Keychain, backing ``APIKeyStore`` in the running app.
///
/// Each value is a generic-password item scoped to the app by service name and
/// addressed by account, so the secret lives in the encrypted Keychain rather
/// than `UserDefaults`, source, or logs. The app's sandbox confines these items
/// to its own Keychain access group.
public struct Keychain: KeychainStoring
{
    /// The service name all of the app's items are filed under.
    private let service: String

    /// Creates a Keychain accessor.
    ///
    /// - Parameter service: The generic-password service name. Defaults to the
    ///   app's bundle identifier so items don't collide with other apps.
    public init( service: String = Bundle.main.bundleIdentifier ?? "com.xs-labs.FITScope" )
    {
        self.service = service
    }

    /// The class/service/account query that identifies one item.
    private func baseQuery( forAccount account: String ) -> [ String: Any ]
    {
        [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: account,
        ]
    }

    public func string( forAccount account: String ) -> String?
    {
        var query = self.baseQuery( forAccount: account )

        query[ kSecReturnData as String ] = true
        query[ kSecMatchLimit as String ] = kSecMatchLimitOne

        var item: CFTypeRef?

        guard SecItemCopyMatching( query as CFDictionary, &item ) == errSecSuccess,
              let data = item as? Data,
              let value = String( data: data, encoding: .utf8 )
        else
        {
            return nil
        }

        return value
    }

    public func setString( _ value: String, forAccount account: String )
    {
        let data  = Data( value.utf8 )
        let query = self.baseQuery( forAccount: account )

        // Update an existing item in place; if there is none, add a fresh one.
        let updateStatus = SecItemUpdate( query as CFDictionary, [ kSecValueData as String: data ] as CFDictionary )

        if updateStatus == errSecItemNotFound
        {
            var attributes = query

            attributes[ kSecValueData as String ]      = data
            attributes[ kSecAttrAccessible as String ] = kSecAttrAccessibleAfterFirstUnlock

            _ = SecItemAdd( attributes as CFDictionary, nil )
        }
    }

    public func removeString( forAccount account: String )
    {
        _ = SecItemDelete( self.baseQuery( forAccount: account ) as CFDictionary )
    }
}
