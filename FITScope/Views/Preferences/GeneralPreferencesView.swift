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

/// The General tab of the Preferences window: app-wide behaviour settings, bound
/// to the shared ``Preferences`` store from the environment.
public struct GeneralPreferencesView: View
{
    /// The shared, persisted preferences.
    @ObservedObject private var preferences: Preferences

    /// Creates the General tab.
    ///
    /// - Parameter preferences: The shared, persisted preferences store. Passed
    ///   in explicitly rather than read from the environment, because a `Settings`
    ///   scene's `TabView` does not reliably propagate environment objects across
    ///   the tab boundary.
    public init( preferences: Preferences )
    {
        self._preferences = ObservedObject( wrappedValue: preferences )
    }

    /// The view's content.
    public var body: some View
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
}

#Preview
{
    GeneralPreferencesView( preferences: Preferences() )
        .frame( width: 480, height: 260 )
}
