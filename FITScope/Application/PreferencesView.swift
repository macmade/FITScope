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

/// The content of the Preferences (Settings) window: a tabbed surface for the
/// app's settings.
///
/// The General tab carries the first real setting; the API Keys, Information
/// Panel and Astro tabs are placeholders filled in by later milestones. The
/// settings bind to the shared ``Preferences`` store from the environment, so a
/// change here is observed app-wide and persisted.
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

    /// The shared, persisted preferences.
    @EnvironmentObject private var preferences: Preferences

    /// Creates the preferences view.
    public init()
    {}

    /// The view's content.
    public var body: some View
    {
        TabView
        {
            self.generalTab
                .tabItem { Label( "General", systemImage: "gearshape" ) }
                .tag( Tab.general )

            self.placeholderTab( "API Keys", systemImage: "key" )
                .tabItem { Label( "API Keys", systemImage: "key" ) }
                .tag( Tab.apiKeys )

            self.placeholderTab( "Information Panel", systemImage: "list.bullet.rectangle" )
                .tabItem { Label( "Information Panel", systemImage: "list.bullet.rectangle" ) }
                .tag( Tab.informationPanel )

            self.placeholderTab( "Astro", systemImage: "sparkles" )
                .tabItem { Label( "Astro", systemImage: "sparkles" ) }
                .tag( Tab.astro )
        }
        .frame( width: 480, height: 260 )
    }

    /// The General tab: the first real setting plus room for more.
    private var generalTab: some View
    {
        Form
        {
            Toggle( "Automatically hide the floating toolbars", isOn: self.$preferences.autoHideFloatingBars )
                .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.autoHideFloatingBarsToggle )

            Text( "When on, the canvas's zoom toolbar and status pill fade out after a moment of inactivity and reappear when you move the pointer. When off, they stay visible." )
                .font( .caption )
                .foregroundStyle( .secondary )
        }
        .formStyle( .grouped )
        .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.generalTab )
    }

    /// A placeholder tab for a section a later milestone fills in.
    ///
    /// - Parameters:
    ///   - title:       The section's name.
    ///   - systemImage: The SF Symbol shown above the message.
    /// - Returns: The placeholder content.
    private func placeholderTab( _ title: String, systemImage: String ) -> some View
    {
        VStack( spacing: 10 )
        {
            Image( systemName: systemImage )
                .font( .system( size: 34 ) )
                .foregroundStyle( .secondary )

            Text( title )
                .font( .headline )

            Text( "Coming soon." )
                .font( .subheadline )
                .foregroundStyle( .secondary )
        }
        .frame( maxWidth: .infinity, maxHeight: .infinity )
    }
}
