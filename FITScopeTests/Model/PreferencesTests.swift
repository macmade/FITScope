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

@testable import FITScope
import Foundation
import Testing

/// Tests for `Preferences`: the typed, `UserDefaults`-backed settings store. The
/// store is exercised against an isolated, throwaway defaults suite so the real
/// user domain is never touched and tests stay independent.
@Suite( "Preferences" )
struct PreferencesTests
{
    /// Builds an isolated `UserDefaults` suite for a single test, plus its name
    /// so the caller can tear the persistent domain down afterwards.
    private func makeIsolatedDefaults() -> ( defaults: UserDefaults, suiteName: String )
    {
        let suiteName = "FITScopeTests.Preferences.\( UUID().uuidString )"

        return ( UserDefaults( suiteName: suiteName )!, suiteName )
    }

    /// With nothing stored, the floating bars auto-hide — the app's existing
    /// behaviour — so first launch is unchanged.
    @Test
    @MainActor
    func defaultsToAutoHidingTheFloatingBars()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )

        #expect( preferences.autoHideFloatingBars == true )
    }

    /// A change is written to the store and read back by a fresh instance — the
    /// round-trip that proves the setting survives across launches.
    @Test
    @MainActor
    func persistsAutoHideChangesAcrossInstances()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )

        preferences.autoHideFloatingBars = false

        let reloaded = Preferences( defaults: defaults )

        #expect( reloaded.autoHideFloatingBars == false )
    }
}
