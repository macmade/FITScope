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
        static let autoHideFloatingBars = "autoHideFloatingBars"
        static let infoPanelFields      = "infoPanelFields"
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
        self.infoPanelFields      = Self.decodeInfoPanelFields( defaults.data( forKey: Key.infoPanelFields ) )
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
}
