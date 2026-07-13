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

    /// With nothing stored, the stars overlay labels each star with its HFR — the
    /// chosen default measurement.
    @Test
    @MainActor
    func defaultsToLabellingStarsWithHFR()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )

        #expect( preferences.starLabelMetric == .hfr )
    }

    /// Choosing a different star-label metric is written to the store and read back
    /// by a fresh instance.
    @Test
    @MainActor
    func persistsStarLabelMetricChangesAcrossInstances()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )

        preferences.starLabelMetric = .fwhm

        let reloaded = Preferences( defaults: defaults )

        #expect( reloaded.starLabelMetric == .fwhm )
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

    /// With nothing stored, there is no remembered main-window size, so the app's
    /// launch-time default size applies rather than a persisted one.
    @Test
    @MainActor
    func defaultsToNoStoredMainWindowSize()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )

        #expect( preferences.mainWindowSize == nil )
    }

    /// A remembered main-window size is written to the store and read back by a
    /// fresh instance — the round-trip that reopens the window at the size the
    /// user last left it.
    @Test
    @MainActor
    func persistsMainWindowSizeAcrossInstances()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )
        let size        = CGSize( width: 1234, height: 987 )

        preferences.mainWindowSize = size

        let reloaded = Preferences( defaults: defaults )

        #expect( reloaded.mainWindowSize == size )
    }

    /// Clearing the remembered size removes it from the store, so a fresh instance
    /// falls back to no stored size (and thus the launch-time default).
    @Test
    @MainActor
    func clearingMainWindowSizeRemovesItFromTheStore()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )

        preferences.mainWindowSize = CGSize( width: 1234, height: 987 )
        preferences.mainWindowSize = nil

        let reloaded = Preferences( defaults: defaults )

        #expect( reloaded.mainWindowSize == nil )
    }

    /// With nothing stored, no overlay is customised — so each overlay falls back to
    /// its own default and the canvas looks exactly as it did before customisation
    /// existed.
    @Test
    @MainActor
    func startsWithNoOverlayCustomizations()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )

        #expect( preferences.overlayAppearances.isEmpty )
        #expect( preferences.overlayAppearance( "stars" ) == nil )
    }

    /// A customised overlay appearance is written to the store and read back by a
    /// fresh instance — the round-trip that keeps the user's colours across launches.
    @Test
    @MainActor
    func persistsOverlayAppearanceChangesAcrossInstances()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )
        let custom      = OverlayAppearance( red: 0.1, green: 0.2, blue: 0.3, opacity: 0.4, secondaryOpacity: 0.5 )

        preferences.overlayAppearances[ "stars" ] = custom

        let reloaded = Preferences( defaults: defaults )

        #expect( reloaded.overlayAppearance( "stars" ) == custom )
    }

    /// Only the customised overlays are stored; an overlay the user never touched
    /// stays absent, so the caller falls back to that overlay's own default.
    @Test
    @MainActor
    func keepsOnlyCustomizedOverlays()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        // Only the reticle stored — every other overlay is left uncustomised.
        self.storeOverlayAppearances( [ ( "reticle", 0.1, 0.2, 0.3, 0.4, 0.5 ) ], in: defaults )

        let preferences = Preferences( defaults: defaults )

        #expect( preferences.overlayAppearance( "reticle" ) == OverlayAppearance( red: 0.1, green: 0.2, blue: 0.3, opacity: 0.4, secondaryOpacity: 0.5 ) )
        #expect( preferences.overlayAppearance( "stars" ) == nil )
        #expect( Set( preferences.overlayAppearances.keys ) == [ "reticle" ] )
    }

    /// Resetting a single overlay drops its customisation (so it falls back to its
    /// default) while leaving the others' customisations intact, and that persists
    /// across launches.
    @Test
    @MainActor
    func resetOverlayAppearanceClearsOnlyThatOverlay()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )
        let custom      = OverlayAppearance( red: 0.1, green: 0.2, blue: 0.3, opacity: 0.4, secondaryOpacity: 0.5 )

        preferences.overlayAppearances[ "stars" ]   = custom
        preferences.overlayAppearances[ "objects" ] = custom

        preferences.resetOverlayAppearance( "stars" )

        #expect( preferences.overlayAppearance( "stars" )   == nil )
        #expect( preferences.overlayAppearance( "objects" ) == custom )

        let reloaded = Preferences( defaults: defaults )

        #expect( reloaded.overlayAppearance( "stars" )   == nil )
        #expect( reloaded.overlayAppearance( "objects" ) == custom )
    }

    /// Restoring all overlays clears every customisation, and that cleared state
    /// persists across launches.
    @Test
    @MainActor
    func resetAllOverlayAppearancesClearsEveryOverlay()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )
        let custom      = OverlayAppearance( red: 0.1, green: 0.2, blue: 0.3, opacity: 0.4, secondaryOpacity: 0.5 )

        preferences.overlayAppearances[ "stars" ]   = custom
        preferences.overlayAppearances[ "reticle" ] = custom

        preferences.resetAllOverlayAppearances()

        #expect( preferences.overlayAppearances.isEmpty )

        let reloaded = Preferences( defaults: defaults )

        #expect( reloaded.overlayAppearances.isEmpty )
    }

    /// Resetting the star-label metric restores the HFR default, and that persists.
    @Test
    @MainActor
    func resetStarLabelMetricRestoresTheDefault()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )

        preferences.starLabelMetric = .fwhm
        preferences.resetStarLabelMetric()

        #expect( preferences.starLabelMetric == .hfr )

        let reloaded = Preferences( defaults: defaults )

        #expect( reloaded.starLabelMetric == .hfr )
    }

    /// The Overlays tab reports a customisation to restore when either an overlay
    /// appearance or the star-label metric differs from its default — so "Restore
    /// All Defaults" enables even when only the label metric was changed.
    @Test
    @MainActor
    func reportsCustomOverlaySettingsForAppearanceOrMetric()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        let preferences = Preferences( defaults: defaults )

        #expect( preferences.hasCustomOverlaySettings == false )

        preferences.starLabelMetric = .fwhm

        #expect( preferences.hasCustomOverlaySettings )

        preferences.starLabelMetric = Preferences.defaultStarLabelMetric

        #expect( preferences.hasCustomOverlaySettings == false )

        preferences.overlayAppearances[ "stars" ] = OverlayAppearance( red: 0.1, green: 0.2, blue: 0.3, opacity: 0.4, secondaryOpacity: 0.5 )

        #expect( preferences.hasCustomOverlaySettings )
    }

    /// With nothing stored, every per-format auto-stretch preference — on-open and
    /// previews alike — defaults to on, so astro images open and preview stretched
    /// out of the box.
    @Test
    @MainActor
    func autoStretchPreferencesDefaultToOn()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()
        let ( shared, sharedName )  = self.makeIsolatedDefaults()

        defer
        {
            defaults.removePersistentDomain( forName: suiteName )
            shared.removePersistentDomain( forName: sharedName )
        }

        let preferences = Preferences( defaults: defaults, sharedDefaults: shared )

        #expect( preferences.autoStretchOnOpenFITS )
        #expect( preferences.autoStretchOnOpenXISF )
        #expect( preferences.autoStretchOnOpenRAW )
        #expect( preferences.autoStretchPreviewsFITS )
        #expect( preferences.autoStretchPreviewsXISF )
    }

    /// The on-open preferences persist through the standard store (app-only) and
    /// are read back by a fresh instance — never touching the shared suite.
    @Test
    @MainActor
    func autoStretchOnOpenPersistsInTheStandardStore()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()
        let ( shared, sharedName )  = self.makeIsolatedDefaults()

        defer
        {
            defaults.removePersistentDomain( forName: suiteName )
            shared.removePersistentDomain( forName: sharedName )
        }

        let preferences = Preferences( defaults: defaults, sharedDefaults: shared )

        preferences.autoStretchOnOpenFITS = false

        let reloaded = Preferences( defaults: defaults, sharedDefaults: shared )

        #expect( reloaded.autoStretchOnOpenFITS == false )
        #expect( AutoStretchPreference.autoStretchOnOpen( .fits, in: defaults ) == false, "the loader helper should read the app-only value" )
        #expect( shared.object( forKey: AutoStretchPreference.onOpenKey( .fits ) ) == nil, "on-open must not go to the shared suite" )
    }

    /// The preview preferences persist through the shared App Group suite so the
    /// sandboxed extensions can read them (via the shared helper), and never touch
    /// the app-only standard store.
    @Test
    @MainActor
    func autoStretchPreviewsPersistInTheSharedStore()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()
        let ( shared, sharedName )  = self.makeIsolatedDefaults()

        defer
        {
            defaults.removePersistentDomain( forName: suiteName )
            shared.removePersistentDomain( forName: sharedName )
        }

        let preferences = Preferences( defaults: defaults, sharedDefaults: shared )

        preferences.autoStretchPreviewsXISF = false

        #expect( AutoStretchPreference.autoStretchPreviews( .xisf, in: shared ) == false, "the extension helper should read the shared value" )

        let reloaded = Preferences( defaults: defaults, sharedDefaults: shared )

        #expect( reloaded.autoStretchPreviewsXISF == false )
        #expect( defaults.object( forKey: AutoStretchPreference.previewsKey( .xisf ) ) == nil, "previews must not go to the standard store" )
    }

    /// The shared preview helper defaults to on when nothing is stored, so a
    /// fresh extension previews stretched until the user opts out.
    @Test
    @MainActor
    func sharedPreviewHelperDefaultsToOn()
    {
        let ( shared, sharedName ) = self.makeIsolatedDefaults()

        defer { shared.removePersistentDomain( forName: sharedName ) }

        #expect( AutoStretchPreference.autoStretchPreviews( .fits, in: shared ) )
        #expect( AutoStretchPreference.autoStretchPreviews( .xisf, in: shared ) )
    }

    /// The on-open helper defaults to on when nothing is stored, so a fresh install
    /// opens astro images stretched until the user opts out.
    @Test
    @MainActor
    func onOpenHelperDefaultsToOn()
    {
        let ( defaults, suiteName ) = self.makeIsolatedDefaults()

        defer { defaults.removePersistentDomain( forName: suiteName ) }

        #expect( AutoStretchPreference.autoStretchOnOpen( .fits, in: defaults ) )
        #expect( AutoStretchPreference.autoStretchOnOpen( .xisf, in: defaults ) )
        #expect( AutoStretchPreference.autoStretchOnOpen( .raw, in: defaults ) )
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

    /// Writes a raw `overlayAppearances` payload — `(id, red, green, blue, opacity,
    /// secondaryOpacity)` tuples, JSON-encoded under the persisted key — directly
    /// into the store, to seed the decoding tests with partial configurations.
    private func storeOverlayAppearances( _ entries: [ ( String, Double, Double, Double, Double, Double ) ], in defaults: UserDefaults )
    {
        let payload = entries.map
        {
            [ "id": $0.0, "red": $0.1, "green": $0.2, "blue": $0.3, "opacity": $0.4, "secondaryOpacity": $0.5 ] as [ String: Any ]
        }
        let data = try! JSONSerialization.data( withJSONObject: payload )

        defaults.set( data, forKey: "overlayAppearances" )
    }
}
