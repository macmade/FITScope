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

import SwiftUI

/// The API Keys tab of the Preferences window: a field per third-party key the
/// network features use, bound to the shared ``APIKeyStore`` from the
/// environment, which persists each key in the Keychain.
public struct APIKeysPreferencesView: View
{
    /// The shared, Keychain-backed API keys.
    @ObservedObject private var apiKeyStore: APIKeyStore

    /// Creates the API Keys tab.
    ///
    /// - Parameter apiKeyStore: The shared, Keychain-backed API-key store. Passed
    ///   in explicitly rather than read from the environment, because a `Settings`
    ///   scene's `TabView` does not reliably propagate environment objects across
    ///   the tab boundary.
    public init( apiKeyStore: APIKeyStore )
    {
        self._apiKeyStore = ObservedObject( wrappedValue: apiKeyStore )
    }

    /// The view's content.
    public var body: some View
    {
        Form
        {
            Section
            {
                APIKeyFieldView(
                    "Astrometry.net",
                    systemImage: "sparkles",
                    key:         self.$apiKeyStore.astrometryNetKey,
                    identifier:  AccessibilityIdentifier.PreferencesView.astrometryNetKeyField,
                    help:        "Your Astrometry.net API key, used for plate solving."
                )
            }
            header:
            {
                Text( "API Keys" )
            }
            footer:
            {
                Text( "API keys are stored securely in your Keychain." )
                    .font( .caption )
                    .foregroundStyle( .secondary )
            }
        }
        .formStyle( .grouped )
        .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.apiKeysTab )
    }
}

#Preview
{
    APIKeysPreferencesView( apiKeyStore: APIKeyStore() )
        .frame( width: 480, height: 260 )
}
