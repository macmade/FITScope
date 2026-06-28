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

    /// With nothing stored, moving a file to the Trash asks for confirmation —
    /// the safe default for a destructive action.
    @Test
    @MainActor
    func defaultsToConfirmingMoveToTrash()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )

        #expect( preferences.confirmMoveToTrash == true )
    }

    /// Turning the trash confirmation off (e.g. via the alert's "don't ask again"
    /// checkbox) is written to the store and read back by a fresh instance.
    @Test
    @MainActor
    func persistsConfirmMoveToTrashChangesAcrossInstances()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )

        preferences.confirmMoveToTrash = false

        let reloaded = Preferences( defaults: defaults )

        #expect( reloaded.confirmMoveToTrash == false )
    }

    /// With nothing stored, every information-panel field is present and visible,
    /// in the canonical order — so the panel looks exactly as it did before the
    /// field configuration existed.
    @Test
    @MainActor
    func defaultsToAllInfoFieldsVisibleInCanonicalOrder()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )

        #expect( preferences.infoPanelFields.map { $0.field } == InfoField.allCases )
        #expect( preferences.infoPanelFields.allSatisfy { $0.isVisible } )
    }

    /// Reordering the fields and hiding one survives across launches.
    @Test
    @MainActor
    func persistsInfoPanelFieldChangesAcrossInstances()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )

        // Reverse the order and hide the first field.
        var fields = preferences.infoPanelFields.reversed().map { $0 }

        fields[ 0 ].isVisible = false
        preferences.infoPanelFields = fields

        let reloaded = Preferences( defaults: defaults )

        #expect( reloaded.infoPanelFields == fields )
    }

    /// A stored configuration that predates a newly-added field still works: the
    /// missing field is appended (visible) so it is never silently lost, while
    /// the stored order and visibility of the known fields are preserved.
    @Test
    @MainActor
    func appendsFieldsMissingFromTheStoredConfiguration()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        // Only one field stored, hidden — every other field is "new".
        self.storeInfoPanelFields( [ ( "object", false ) ], in: defaults )

        let preferences = Preferences( defaults: defaults )

        #expect( preferences.infoPanelFields.first == .init( field: .object, isVisible: false ) )
        #expect( Set( preferences.infoPanelFields.map { $0.field } ) == Set( InfoField.allCases ) )
        #expect( preferences.infoPanelFields.count == InfoField.allCases.count )
        // The appended (previously-unknown) fields default to visible.
        #expect( preferences.infoPanelFields.dropFirst().allSatisfy { $0.isVisible } )
    }

    /// A stored field that no longer maps to a known field (e.g. removed in a
    /// later version) is dropped, leaving exactly the current field set.
    @Test
    @MainActor
    func dropsUnknownStoredFields()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        self.storeInfoPanelFields( [ ( "object", true ), ( "noSuchField", true ) ], in: defaults )

        let preferences = Preferences( defaults: defaults )

        #expect( preferences.infoPanelFields.contains { $0.field.rawValue == "noSuchField" } == false )
        #expect( preferences.infoPanelFields.map { $0.field }.sorted { $0.rawValue < $1.rawValue }
            == InfoField.allCases.sorted { $0.rawValue < $1.rawValue } )
    }

    /// Resetting restores every field to visible, in canonical order, and that
    /// restored default persists across launches.
    @Test
    @MainActor
    func resetInfoPanelFieldsRestoresDefaults()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )

        // Diverge from the default: reverse the order and hide a field.
        var fields = preferences.infoPanelFields.reversed().map { $0 }

        fields[ 0 ].isVisible = false
        preferences.infoPanelFields = fields

        preferences.resetInfoPanelFields()

        #expect( preferences.infoPanelFields.map { $0.field } == InfoField.allCases )
        #expect( preferences.infoPanelFields.allSatisfy { $0.isVisible } )

        let reloaded = Preferences( defaults: defaults )

        #expect( reloaded.infoPanelFields == preferences.infoPanelFields )
    }

    /// With nothing stored, the weight formula is the default expression, and
    /// that default is itself a valid, parseable formula.
    @Test
    @MainActor
    func defaultsToTheDefaultWeightFormula() throws
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )

        #expect( preferences.weightFormula == WeightFormula.defaultExpression )
        #expect( throws: Never.self ) { try WeightFormula( source: preferences.weightFormula ) }
    }

    /// An edited weight formula is written to the store and read back by a fresh
    /// instance — including an invalid one, so the user's in-progress text is
    /// never lost (validity is surfaced separately, in the editor).
    @Test
    @MainActor
    func persistsWeightFormulaChangesAcrossInstances()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )

        preferences.weightFormula = "1 / FWHM ("

        let reloaded = Preferences( defaults: defaults )

        #expect( reloaded.weightFormula == "1 / FWHM (" )
    }

    /// Writes a raw `infoPanelFields` payload — `(fieldRawValue, visible)` pairs,
    /// JSON-encoded under the persisted key — directly into the store, to seed
    /// the reconciliation tests with partial or stale configurations.
    private func storeInfoPanelFields( _ pairs: [ ( String, Bool ) ], in defaults: UserDefaults )
    {
        let payload = pairs.map { [ "field": $0.0, "visible": $0.1 ] as [ String: Any ] }
        let data    = try! JSONSerialization.data( withJSONObject: payload )

        defaults.set( data, forKey: "infoPanelFields" )
    }
}
