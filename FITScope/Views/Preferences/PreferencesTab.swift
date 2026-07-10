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

/// The tabs of the Preferences (Settings) window, in display order.
///
/// Selecting a tab is driven by a shared binding (``AppModel/selectedPreferencesTab``),
/// so a call site outside the window — such as the "no API key" alert pointing the
/// user at the API&nbsp;Keys tab — can open Preferences to a specific tab.
public enum PreferencesTab: Hashable, CaseIterable
{
    /// The General tab.
    case general

    /// The Auto-Stretch tab, for the per-format auto-stretch-on-open and preview
    /// preferences.
    case autoStretch

    /// The API Keys tab.
    case apiKeys

    /// The Information Panel tab.
    case informationPanel

    /// The Overlays tab, for customising the canvas annotation overlays' colours
    /// and opacities.
    case overlays

    /// The Weighting tab.
    case weighting
}
