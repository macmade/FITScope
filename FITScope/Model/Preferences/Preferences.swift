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
import CoreGraphics
import Foundation

/// One information-panel field together with whether the user wants it shown.
///
/// An ordered array of these is the panel's configuration: the array's order is
/// the display order, and ``isVisible`` toggles each field on or off.
public struct InfoPanelFieldSetting: Equatable, Sendable
{
    /// The field this setting controls.
    public let field: InfoField

    /// Whether the field is shown in the information panel.
    public var isVisible: Bool

    /// Creates a field setting.
    ///
    /// - Parameters:
    ///   - field:     The field to control.
    ///   - isVisible: Whether it is shown.
    public init( field: InfoField, isVisible: Bool )
    {
        self.field     = field
        self.isVisible = isVisible
    }
}

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
        static let autoHideFloatingBars         = "autoHideFloatingBars"
        static let confirmMoveToTrash           = "confirmMoveToTrash"
        static let automaticallyCheckForUpdates = "automaticallyCheckForUpdates"
        static let infoPanelFields              = "infoPanelFields"
        static let weightFormula                = "weightFormula"
        static let mainWindowWidth              = "mainWindowWidth"
        static let mainWindowHeight             = "mainWindowHeight"
        static let overlayAppearances           = "overlayAppearances"
        static let starLabelMetric              = "starLabelMetric"
    }

    /// The persisted shape of one field setting: the field's stable raw value and
    /// its visibility. Decoding tolerates unknown raw values (see
    /// ``Preferences/reconcileInfoPanelFields(from:)``), so it uses a plain
    /// `String` for the field rather than ``InfoField`` directly.
    private struct StoredInfoPanelField: Codable
    {
        let field:   String
        let visible: Bool
    }

    /// The persisted shape of one overlay appearance: the overlay's stable
    /// identifier plus its sRGB components and opacities.
    private struct StoredOverlayAppearance: Codable
    {
        let id:               String
        let red:              Double
        let green:            Double
        let blue:             Double
        let opacity:          Double
        let secondaryOpacity: Double
    }

    /// The backing store. Reads seed the published values at init; writes flow
    /// back through each property's `didSet`.
    private let defaults: UserDefaults

    /// The shared App Group backing store for the preferences the sandboxed
    /// QuickLook / thumbnail extensions must read — currently the per-format
    /// "auto-stretch previews" toggles. The app writes them here; the extensions
    /// read them via ``AutoStretchPreference/autoStretchPreviews(_:in:)``. Separate
    /// from ``defaults`` so the app-only settings stay on `.standard`.
    private let sharedDefaults: UserDefaults

    /// Whether the canvas's floating toolbar and status pill auto-hide after a
    /// short delay of cursor inactivity. On — the app's original behaviour — by
    /// default; when off, the bars stay visible.
    @Published public var autoHideFloatingBars: Bool
    {
        didSet { self.defaults.set( self.autoHideFloatingBars, forKey: Key.autoHideFloatingBars ) }
    }

    /// Whether moving a file to the Trash asks the user to confirm first. On by
    /// default — the safe choice for a destructive action; the confirmation
    /// alert's "don't ask again" checkbox, and the General preferences toggle,
    /// turn it off.
    @Published public var confirmMoveToTrash: Bool
    {
        didSet { self.defaults.set( self.confirmMoveToTrash, forKey: Key.confirmMoveToTrash ) }
    }

    /// Whether the app checks for a newer version automatically, shortly after
    /// launch. On by default; when off, only the manual *Check for Updates…* menu
    /// command looks for an update. Gates the launch-time background check in
    /// ``AppDelegate``.
    @Published public var automaticallyCheckForUpdates: Bool
    {
        didSet { self.defaults.set( self.automaticallyCheckForUpdates, forKey: Key.automaticallyCheckForUpdates ) }
    }

    /// The information-panel fields, in display order, each flagged visible or
    /// hidden. Drives both the sidebar panel and its Preferences editor.
    ///
    /// Defaults to every field, visible, in ``InfoField/allCases`` order — so an
    /// unconfigured app shows the panel exactly as before. Writes persist the
    /// configuration; reads on launch reconcile it against the current field set
    /// (see ``reconcileInfoPanelFields(from:)``).
    @Published public var infoPanelFields: [ InfoPanelFieldSetting ]
    {
        didSet { self.defaults.set( Self.encode( self.infoPanelFields ), forKey: Key.infoPanelFields ) }
    }

    /// The overlays the user has customised, keyed by overlay identifier — colour
    /// and opacities per overlay. Drives how the canvas annotation overlays are
    /// drawn and their editor in the Overlays preferences tab.
    ///
    /// Deliberately holds *only* the overlays the user has changed: an overlay
    /// absent from the map keeps its own default appearance (so this store stays
    /// decoupled from the overlays — it never enumerates or hardcodes their
    /// defaults). Writes persist the map; reading back an empty or unreadable
    /// payload yields no customisations.
    @Published public var overlayAppearances: [ String: OverlayAppearance ]
    {
        didSet { self.defaults.set( Self.encode( self.overlayAppearances ), forKey: Key.overlayAppearances ) }
    }

    /// The per-star measurement the stars overlay labels next to each detected
    /// star — none, HFR or FWHM. Defaults to ``StarLabelMetric/hfr``. Persisted by
    /// its stable raw value; an unknown stored value falls back to the default.
    @Published public var starLabelMetric: StarLabelMetric
    {
        didSet { self.defaults.set( self.starLabelMetric.rawValue, forKey: Key.starLabelMetric ) }
    }

    /// Whether opening a FITS image in the app auto-stretches it (a Screen
    /// Transfer), rather than showing it linear. On by default. App-only, so it is
    /// stored on ``defaults`` (`.standard`).
    @Published public var autoStretchOnOpenFITS: Bool
    {
        didSet { self.defaults.set( self.autoStretchOnOpenFITS, forKey: AutoStretchPreference.onOpenKey( .fits ) ) }
    }

    /// Whether opening an XISF image in the app auto-stretches it. On by default.
    /// App-only (`.standard`). The XISF display function, when present, takes
    /// priority over the auto-stretch (see Milestone 4).
    @Published public var autoStretchOnOpenXISF: Bool
    {
        didSet { self.defaults.set( self.autoStretchOnOpenXISF, forKey: AutoStretchPreference.onOpenKey( .xisf ) ) }
    }

    /// Whether opening a camera RAW image in the app auto-stretches it. On by
    /// default. App-only (`.standard`).
    @Published public var autoStretchOnOpenRAW: Bool
    {
        didSet { self.defaults.set( self.autoStretchOnOpenRAW, forKey: AutoStretchPreference.onOpenKey( .raw ) ) }
    }

    /// Whether FITS QuickLook / Finder previews and thumbnails are auto-stretched.
    /// On by default. Stored in the shared App Group suite so the sandboxed
    /// extensions can read it.
    @Published public var autoStretchPreviewsFITS: Bool
    {
        didSet { self.sharedDefaults.set( self.autoStretchPreviewsFITS, forKey: AutoStretchPreference.previewsKey( .fits ) ) }
    }

    /// Whether XISF QuickLook / Finder previews and thumbnails are auto-stretched.
    /// On by default. Stored in the shared App Group suite. The XISF display
    /// function, when present, takes priority (see Milestone 4).
    @Published public var autoStretchPreviewsXISF: Bool
    {
        didSet { self.sharedDefaults.set( self.autoStretchPreviewsXISF, forKey: AutoStretchPreference.previewsKey( .xisf ) ) }
    }

    /// The user's image-weight formula, as raw text (see ``WeightFormula``).
    ///
    /// Defaults to ``WeightFormula/defaultExpression``. The raw text is persisted
    /// on every change — including a syntactically invalid one — so in-progress
    /// edits are never lost; the editor validates it live and consumers parse it
    /// through ``WeightFormula`` before use.
    @Published public var weightFormula: String
    {
        didSet { self.defaults.set( self.weightFormula, forKey: Key.weightFormula ) }
    }

    /// The size the main window was last left at, persisted so it reopens at the
    /// same dimensions on the next launch (see ``MainWindowView``).
    ///
    /// `nil` when nothing has been stored yet — so first launch falls back to the
    /// app's default size (``MainWindowView/defaultSize``) rather than a persisted
    /// one. Deliberately *not* `@Published`: it is written on every window-resize
    /// step and read once at launch, with no view observing it for display, so
    /// publishing it would only churn re-renders during a live resize.
    public var mainWindowSize: CGSize?
    {
        didSet
        {
            guard let size = self.mainWindowSize
            else
            {
                self.defaults.removeObject( forKey: Key.mainWindowWidth )
                self.defaults.removeObject( forKey: Key.mainWindowHeight )

                return
            }

            self.defaults.set( size.width,  forKey: Key.mainWindowWidth )
            self.defaults.set( size.height, forKey: Key.mainWindowHeight )
        }
    }

    /// Creates the store, seeding each setting from its backing store or its
    /// default value when nothing has been stored yet.
    ///
    /// - Parameters:
    ///   - defaults:       The app-only backing store. Defaults to `.standard`;
    ///                     tests inject an isolated suite.
    ///   - sharedDefaults: The shared App Group backing store for the extension-
    ///                     readable preview preferences. Defaults to the App Group
    ///                     suite, falling back to `defaults` when the running bundle
    ///                     declares no App Group identifier — see
    ///                     ``AutoStretchPreference/sharedDefaults``; tests inject an
    ///                     isolated suite.
    public init( defaults: UserDefaults = .standard, sharedDefaults: UserDefaults? = nil )
    {
        let sharedDefaults = sharedDefaults ?? AutoStretchPreference.sharedDefaults ?? defaults

        self.defaults       = defaults
        self.sharedDefaults = sharedDefaults

        // `object(forKey:)` distinguishes "never set" (nil → the default) from a
        // stored `false`, which a plain `bool(forKey:)` could not.
        self.autoHideFloatingBars         = ( defaults.object( forKey: Key.autoHideFloatingBars ) as? Bool ) ?? true
        self.confirmMoveToTrash           = ( defaults.object( forKey: Key.confirmMoveToTrash ) as? Bool ) ?? true
        self.automaticallyCheckForUpdates = ( defaults.object( forKey: Key.automaticallyCheckForUpdates ) as? Bool ) ?? true
        self.infoPanelFields              = Self.decodeInfoPanelFields( defaults.data( forKey: Key.infoPanelFields ) )
        self.overlayAppearances           = Self.decodeOverlayAppearances( defaults.data( forKey: Key.overlayAppearances ) )
        self.starLabelMetric              = ( defaults.string( forKey: Key.starLabelMetric ).flatMap { StarLabelMetric( rawValue: $0 ) } ) ?? Self.defaultStarLabelMetric
        self.weightFormula                = defaults.string( forKey: Key.weightFormula ) ?? WeightFormula.defaultExpression
        self.mainWindowSize               = Self.decodeMainWindowSize( from: defaults )
        self.autoStretchOnOpenFITS        = AutoStretchPreference.autoStretchOnOpen( .fits, in: defaults )
        self.autoStretchOnOpenXISF        = AutoStretchPreference.autoStretchOnOpen( .xisf, in: defaults )
        self.autoStretchOnOpenRAW         = AutoStretchPreference.autoStretchOnOpen( .raw, in: defaults )
        self.autoStretchPreviewsFITS      = AutoStretchPreference.autoStretchPreviews( .fits, in: sharedDefaults )
        self.autoStretchPreviewsXISF      = AutoStretchPreference.autoStretchPreviews( .xisf, in: sharedDefaults )
    }

    /// Reads the persisted main-window size, if any.
    ///
    /// Both a width and a height must be present (via `object(forKey:)`, which
    /// distinguishes "never set" from a stored `0`) for a size to be returned;
    /// otherwise `nil`, so the caller applies the default size instead.
    ///
    /// - Parameter defaults: The backing store to read from.
    /// - Returns: The stored size, or `nil` when nothing complete is stored.
    private static func decodeMainWindowSize( from defaults: UserDefaults ) -> CGSize?
    {
        guard let width  = defaults.object( forKey: Key.mainWindowWidth )  as? Double,
              let height = defaults.object( forKey: Key.mainWindowHeight ) as? Double
        else
        {
            return nil
        }

        return CGSize( width: width, height: height )
    }

    /// Restores ``weightFormula`` to the default expression, discarding the user's
    /// edits.
    public func resetWeightFormula()
    {
        self.weightFormula = WeightFormula.defaultExpression
    }

    /// Restores ``infoPanelFields`` to the default — every field visible, in
    /// canonical order — discarding the user's selection and ordering.
    public func resetInfoPanelFields()
    {
        self.infoPanelFields = Self.defaultInfoPanelFields
    }

    /// Every field, visible, in canonical order — the configuration used when
    /// nothing has been stored yet.
    private static var defaultInfoPanelFields: [ InfoPanelFieldSetting ]
    {
        InfoField.allCases.map { InfoPanelFieldSetting( field: $0, isVisible: true ) }
    }

    /// The user's customised appearance for an overlay, or `nil` when it has not
    /// been customised — in which case the caller uses the overlay's own default.
    ///
    /// - Parameter id: The overlay's identifier.
    /// - Returns: The stored appearance, or `nil`.
    public func overlayAppearance( _ id: String ) -> OverlayAppearance?
    {
        self.overlayAppearances[ id ]
    }

    /// Restores a single overlay to its default appearance by dropping its stored
    /// customisation, leaving the others untouched.
    ///
    /// - Parameter id: The overlay's identifier.
    public func resetOverlayAppearance( _ id: String )
    {
        self.overlayAppearances[ id ] = nil
    }

    /// Restores every overlay to its default appearance by clearing all stored
    /// customisations.
    public func resetAllOverlayAppearances()
    {
        self.overlayAppearances = [ : ]
    }

    /// The star-label metric used when nothing is stored, and restored by
    /// ``resetStarLabelMetric()`` — HFR.
    public static let defaultStarLabelMetric: StarLabelMetric = .hfr

    /// Restores ``starLabelMetric`` to its default (HFR).
    public func resetStarLabelMetric()
    {
        self.starLabelMetric = Self.defaultStarLabelMetric
    }

    /// Whether the Overlays tab has anything to restore — a customised overlay
    /// appearance or a non-default star-label metric. Drives the enabled state of
    /// the tab's "Restore All Defaults" button, so it also lights up when only the
    /// label metric was changed.
    public var hasCustomOverlaySettings: Bool
    {
        self.overlayAppearances.isEmpty == false || self.starLabelMetric != Self.defaultStarLabelMetric
    }

    /// Encodes a configuration to JSON `Data` for `UserDefaults`.
    ///
    /// - Parameter fields: The configuration to persist.
    /// - Returns: The encoded data, or `nil` if encoding fails (never expected).
    private static func encode( _ fields: [ InfoPanelFieldSetting ] ) -> Data?
    {
        let stored = fields.map { StoredInfoPanelField( field: $0.field.rawValue, visible: $0.isVisible ) }

        return try? JSONEncoder().encode( stored )
    }

    /// Decodes a stored configuration, reconciling it against the current field
    /// set. A missing or unreadable payload yields the default configuration.
    ///
    /// - Parameter data: The persisted JSON, or `nil` when nothing is stored.
    /// - Returns: The reconciled configuration.
    private static func decodeInfoPanelFields( _ data: Data? ) -> [ InfoPanelFieldSetting ]
    {
        guard let data, let stored = try? JSONDecoder().decode( [ StoredInfoPanelField ].self, from: data )
        else
        {
            return self.defaultInfoPanelFields
        }

        return self.reconcileInfoPanelFields( from: stored )
    }

    /// Reconciles a stored configuration with the current set of fields so the
    /// app is robust to fields being added or removed between versions.
    ///
    /// Known fields keep their stored order and visibility; an entry whose raw
    /// value no longer names a field is dropped; and any field absent from the
    /// stored list is appended (visible) so it is never silently lost.
    ///
    /// - Parameter stored: The decoded stored entries, in stored order.
    /// - Returns: The reconciled configuration covering exactly the current
    ///   field set.
    private static func reconcileInfoPanelFields( from stored: [ StoredInfoPanelField ] ) -> [ InfoPanelFieldSetting ]
    {
        var result: [ InfoPanelFieldSetting ] = []
        var seen:    Set< InfoField >         = []

        for entry in stored
        {
            guard let field = InfoField( rawValue: entry.field ), seen.contains( field ) == false
            else
            {
                continue
            }

            result.append( InfoPanelFieldSetting( field: field, isVisible: entry.visible ) )
            seen.insert( field )
        }

        for field in InfoField.allCases where seen.contains( field ) == false
        {
            result.append( InfoPanelFieldSetting( field: field, isVisible: true ) )
        }

        return result
    }

    /// Encodes the overlay appearances to JSON `Data` for `UserDefaults`.
    ///
    /// - Parameter appearances: The customisations to persist.
    /// - Returns: The encoded data, or `nil` if encoding fails (never expected).
    private static func encode( _ appearances: [ String: OverlayAppearance ] ) -> Data?
    {
        let stored = appearances.map
        {
            StoredOverlayAppearance( id: $0.key, red: $0.value.red, green: $0.value.green, blue: $0.value.blue, opacity: $0.value.opacity, secondaryOpacity: $0.value.secondaryOpacity )
        }

        return try? JSONEncoder().encode( stored )
    }

    /// Decodes the stored overlay customisations. A missing or unreadable payload
    /// yields no customisations, so every overlay falls back to its own default.
    ///
    /// - Parameter data: The persisted JSON, or `nil` when nothing is stored.
    /// - Returns: The decoded customisations, keyed by overlay identifier.
    private static func decodeOverlayAppearances( _ data: Data? ) -> [ String: OverlayAppearance ]
    {
        guard let data, let stored = try? JSONDecoder().decode( [ StoredOverlayAppearance ].self, from: data )
        else
        {
            return [ : ]
        }

        return Dictionary(
            stored.map { ( $0.id, OverlayAppearance( red: $0.red, green: $0.green, blue: $0.blue, opacity: $0.opacity, secondaryOpacity: $0.secondaryOpacity ) ) },
            uniquingKeysWith: { _, latest in latest }
        )
    }
}
