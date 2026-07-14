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

/// The Auto-Stretch tab of the Preferences window: per-format toggles for
/// auto-stretching linear images, split into two contexts — opening in the app,
/// and QuickLook / Finder previews and thumbnails.
///
/// The preview toggles are stored in the shared App Group suite so the sandboxed
/// QuickLook / thumbnail extensions can honour them; the on-open toggles are
/// app-only. Both are bound to the shared ``Preferences`` store.
public struct AutoStretchPreferencesView: View
{
    /// The shared, persisted preferences.
    @ObservedObject private var preferences: Preferences

    /// Creates the Auto-Stretch tab.
    ///
    /// - Parameter preferences: The shared, persisted preferences store. Passed in
    ///   explicitly rather than read from the environment, because a `Settings`
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
            Section( "When opening images" )
            {
                Toggle( "FITS", isOn: self.$preferences.autoStretchOnOpenFITS )
                    .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.autoStretchOnOpenToggle( .fits ) )

                Toggle( "XISF", isOn: self.$preferences.autoStretchOnOpenXISF )
                    .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.autoStretchOnOpenToggle( .xisf ) )

                Toggle( "Camera RAW", isOn: self.$preferences.autoStretchOnOpenRAW )
                    .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.autoStretchOnOpenToggle( .raw ) )
            }

            // Only FITS and XISF are listed here: the QuickLook / Finder preview and
            // thumbnail extensions declare support for those two types only, so a
            // camera-RAW previews toggle would never reach an extension (RAW previews
            // are handled by the system). Camera RAW keeps its "on open" toggle above.
            Section( "In Finder previews and thumbnails" )
            {
                Toggle( "FITS", isOn: self.$preferences.autoStretchPreviewsFITS )
                    .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.autoStretchPreviewsToggle( .fits ) )

                Toggle( "XISF", isOn: self.$preferences.autoStretchPreviewsXISF )
                    .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.autoStretchPreviewsToggle( .xisf ) )
            }

            Section
            {
                Text( "Auto-stretch applies a Screen Transfer to the otherwise-linear image, bringing out faint detail. For XISF files that carry a display function, that display function is used instead, and takes priority over the auto-stretch." )
                    .font( .caption )
                    .foregroundStyle( .secondary )
            }
        }
        .formStyle( .grouped )
        .scrollIndicators( .never )
        .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.autoStretchTab )
    }
}

#Preview
{
    AutoStretchPreferencesView( preferences: Preferences() )
        .frame( width: 480, height: 420 )
}
