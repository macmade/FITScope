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
import SwiftUtilities

/// The content of the Preferences (Settings) window: a tabbed surface composing
/// one component view per section.
///
/// Each tab is its own view and is given the shared stores it needs explicitly,
/// because a `Settings` scene's `TabView` does not reliably propagate
/// environment objects across the tab boundary.
public struct PreferencesView: View
{
    /// The shared, persisted preferences. Resolved here — before the `TabView` —
    /// and passed into the tabs explicitly, since a `Settings` scene's `TabView`
    /// does not reliably propagate environment objects to its tab content.
    @EnvironmentObject private var preferences: Preferences

    /// The shared, Keychain-backed API keys, resolved here and passed down for
    /// the same reason as ``preferences``.
    @EnvironmentObject private var apiKeyStore: APIKeyStore

    /// App-wide coordination, holding the selected tab so a call site outside the
    /// window (the "no API key" alert) can open Preferences to a specific tab.
    @EnvironmentObject private var appModel: AppModel

    /// The width of the standard, control-light tabs.
    private static let standardWidth: CGFloat = 480

    /// The width of the Weighting tab, which needs more room for the formula
    /// editor and the placeholder palette.
    private static let weightingWidth: CGFloat = 560

    /// The size of the Information Panel tab, whose reorderable list is meant to
    /// fill a fixed area rather than size to its rows.
    private static let informationPanelSize = CGSize( width: 480, height: 360 )

    /// Creates the preferences view.
    public init()
    {}

    /// The view's content.
    ///
    /// The form-based tabs are given a fixed width and sized to their content
    /// height (`fixedSize`), so the `.contentSize` Settings window adapts to the
    /// selected pane with no empty space below.
    public var body: some View
    {
        TabView( selection: self.$appModel.selectedPreferencesTab )
        {
            GeneralPreferencesView( preferences: self.preferences )
                .frame( width: Self.standardWidth )
                .fixedSize( horizontal: false, vertical: true )
                .tabItem { Label( "General", systemImage: "gearshape" ) }
                .tag( PreferencesTab.general )

            APIKeysPreferencesView( apiKeyStore: self.apiKeyStore )
                .frame( width: Self.standardWidth )
                .fixedSize( horizontal: false, vertical: true )
                .tabItem { Label( "API Keys", systemImage: "key" ) }
                .tag( PreferencesTab.apiKeys )

            InformationPanelPreferencesView( preferences: self.preferences )
                .frame( width: Self.informationPanelSize.width, height: Self.informationPanelSize.height )
                .tabItem { Label( "Information Panel", systemImage: "list.bullet.rectangle" ) }
                .tag( PreferencesTab.informationPanel )

            WeightingPreferencesView( preferences: self.preferences )
                .frame( width: Self.weightingWidth )
                .fixedSize( horizontal: false, vertical: true )
                .tabItem { Label( "Weighting", systemImage: "scalemass" ) }
                .tag( PreferencesTab.weighting )
        }
        // The Settings scene has no declarative positioning, so the hosting window
        // is centered when the view first joins it.
        .background( WindowAccessor { $0.center() } )
    }
}
