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

/// The app's singleton auxiliary windows — Levels, Curves, Screen Transfer,
/// Session Metrics and About.
///
/// Each is declared as a value-keyed `WindowGroup` (rather than a singleton
/// `Window` scene) presented with the single shared ``token`` value. A `Window`
/// scene adds a permanent entry to the standard *Window* menu that is listed even
/// while the window is closed; a `WindowGroup` does not. Keying the group on a
/// constant value keeps SwiftUI reusing the one existing window on every open —
/// the single-instance behaviour a `Window` scene would otherwise provide — so
/// the only change users see is that closed windows no longer clutter the *Window*
/// menu.
enum SingletonWindow
{
    /// The constant value every singleton auxiliary window is presented with, via
    /// `openWindow( id:value: )`. Passing the same value on each open makes SwiftUI
    /// surface the existing window instead of creating another.
    static let token = "default"
}
