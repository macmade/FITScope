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

/// The content of the Preferences (Settings) window: a tabbed surface composing
/// one component view per section.
///
/// The General and API Keys tabs carry real settings; the Information Panel and
/// Astro tabs are placeholders. Each tab is its own view and is given the shared
/// stores it needs explicitly.
public struct PreferencesView: View
{
    /// The tabs shown in the window, in order.
    private enum Tab: Hashable
    {
        case general
        case apiKeys
        case informationPanel
        case astro
    }

    /// The shared, persisted preferences. Resolved here — before the `TabView` —
    /// and passed into the tabs explicitly, since a `Settings` scene's `TabView`
    /// does not reliably propagate environment objects to its tab content.
    @EnvironmentObject private var preferences: Preferences

    /// The shared, Keychain-backed API keys, resolved here and passed down for
    /// the same reason as ``preferences``.
    @EnvironmentObject private var apiKeyStore: APIKeyStore

    /// Creates the preferences view.
    public init()
    {}

    /// The view's content.
    public var body: some View
    {
        TabView
        {
            GeneralPreferencesView( preferences: self.preferences )
                .tabItem { Label( "General", systemImage: "gearshape" ) }
                .tag( Tab.general )

            APIKeysPreferencesView( apiKeyStore: self.apiKeyStore )
                .tabItem { Label( "API Keys", systemImage: "key" ) }
                .tag( Tab.apiKeys )

            PreferencesPlaceholderView( "Information Panel", systemImage: "list.bullet.rectangle" )
                .tabItem { Label( "Information Panel", systemImage: "list.bullet.rectangle" ) }
                .tag( Tab.informationPanel )

            PreferencesPlaceholderView( "Astro", systemImage: "sparkles" )
                .tabItem { Label( "Astro", systemImage: "sparkles" ) }
                .tag( Tab.astro )
        }
        .frame( width: 480, height: 260 )
    }
}
