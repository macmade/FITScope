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

import Combine
import Foundation

/// The app's user preferences: an observable, `UserDefaults`-backed settings
/// store shared across the app's windows and the Preferences scene.
///
/// Each setting is published so views update live, and writes through to the
/// backing `UserDefaults` so the value survives across launches. The backing
/// store is injected, defaulting to `.standard`, so tests can exercise the
/// round-trip against an isolated, throwaway suite.
@MainActor
public final class Preferences: ObservableObject
{
    /// The keys under which settings are persisted in `UserDefaults`.
    private enum Key
    {
        static let autoHideFloatingBars = "autoHideFloatingBars"
    }

    /// The backing store. Reads seed the published values at init; writes flow
    /// back through each property's `didSet`.
    private let defaults: UserDefaults

    /// Whether the canvas's floating toolbar and status pill auto-hide after a
    /// short delay of cursor inactivity. On — the app's original behaviour — by
    /// default; when off, the bars stay visible.
    @Published public var autoHideFloatingBars: Bool
    {
        didSet { self.defaults.set( self.autoHideFloatingBars, forKey: Key.autoHideFloatingBars ) }
    }

    /// Creates the store, seeding each setting from `defaults` or its default
    /// value when nothing has been stored yet.
    ///
    /// - Parameter defaults: The backing store. Defaults to `.standard`; tests
    ///   inject an isolated suite.
    public init( defaults: UserDefaults = .standard )
    {
        self.defaults = defaults

        // `object(forKey:)` distinguishes "never set" (nil → the default) from a
        // stored `false`, which a plain `bool(forKey:)` could not.
        self.autoHideFloatingBars = ( defaults.object( forKey: Key.autoHideFloatingBars ) as? Bool ) ?? true
    }
}
