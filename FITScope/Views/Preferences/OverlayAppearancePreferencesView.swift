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

/// The Overlays tab of the Preferences window: a per-overlay editor for the canvas
/// annotation overlays' colour and opacity.
///
/// Each overlay listed by ``CanvasOverlayCatalog`` gets a card — laid out two to a
/// row, top-aligned, so the tab stays compact — with a colour well and one opacity
/// slider per opacity channel the overlay declares (so the equatorial grid, which
/// declares two, shows two). Within a card the field labels form a left column,
/// aligned through a `Grid`. Edits bind to the shared
/// ``Preferences/overlayAppearances`` store, so every open canvas repaints live and
/// the choices persist across launches. A card shows a reset control once its
/// overlay differs from its default, and a "Restore All Defaults" button clears
/// every customisation at once.
public struct OverlayAppearancePreferencesView: View
{
    /// The shared, persisted preferences.
    @ObservedObject private var preferences: Preferences

    /// The fixed width of the trailing percentage read-out, in points, so the
    /// sliders end at a consistent position.
    private static let readoutWidth: CGFloat = 40

    /// Creates the Overlays tab.
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
    ///
    /// The overlays are split into two fixed columns of cards (rather than a grid)
    /// so a taller card — the equatorial grid, with its two sliders — leaves its
    /// row-mate pinned to the top rather than centred.
    public var body: some View
    {
        VStack( spacing: 20 )
        {
            HStack( alignment: .top, spacing: 16 )
            {
                self.column( Self.leftColumn )
                self.column( Self.rightColumn )
            }

            HStack
            {
                Spacer()

                Button( "Restore All Defaults" )
                {
                    self.preferences.resetAllOverlayAppearances()
                    self.preferences.resetStarLabelMetric()
                }
                .disabled( self.preferences.hasCustomOverlaySettings == false )
                .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.overlaysRestoreAllButton )
            }
        }
        .padding( 20 )
        .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.overlaysTab )
    }

    /// The index at which the catalog is split into the two columns: the first
    /// half (rounded up, so the left column takes the extra card when the count is
    /// odd) fills the left column, the rest the right — so the cards are ordered
    /// down each column rather than across the rows.
    private static var columnSplit: Int
    {
        ( CanvasOverlayCatalog.all.count + 1 ) / 2
    }

    /// The overlays in the left column — the first half of the catalog, so reading
    /// down the column follows catalog order.
    private static var leftColumn: [ any CanvasOverlay ]
    {
        Array( CanvasOverlayCatalog.all.prefix( Self.columnSplit ) )
    }

    /// The overlays in the right column — the remaining catalog entries after the
    /// left column.
    private static var rightColumn: [ any CanvasOverlay ]
    {
        Array( CanvasOverlayCatalog.all.dropFirst( Self.columnSplit ) )
    }

    /// A single top-aligned column of overlay cards.
    ///
    /// - Parameter overlays: The overlays to stack in the column.
    private func column( _ overlays: [ any CanvasOverlay ] ) -> some View
    {
        VStack( spacing: 16 )
        {
            ForEach( overlays, id: \.id )
            {
                overlay in

                self.card( for: overlay )
            }
        }
        .frame( maxWidth: .infinity, alignment: .top )
    }

    /// One overlay's card: a titled box with a colour well, an opacity slider per
    /// declared channel, and — once the overlay is customised — a reset control.
    /// The field labels line up in a left column via a `Grid`.
    ///
    /// - Parameter overlay: The overlay to edit (a representative instance from the
    ///   catalog, read only for its metadata).
    private func card( for overlay: any CanvasOverlay ) -> some View
    {
        let appearance = self.appearanceBinding( for: overlay )

        return GroupBox
        {
            Grid( alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8 )
            {
                GridRow
                {
                    self.fieldLabel( "Color" )

                    ColorPicker( "Color", selection: appearance.color, supportsOpacity: false )
                        .labelsHidden()
                        .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.overlayColorPicker( overlay.id ) )
                }

                ForEach( type( of: overlay ).opacityChannels )
                {
                    channel in

                    GridRow
                    {
                        self.fieldLabel( channel.label )

                        self.opacitySlider( appearance[ dynamicMember: channel.keyPath ] )
                    }
                }

                if overlay.id == StarsOverlay.identifier
                {
                    GridRow
                    {
                        self.fieldLabel( "Labels" )

                        self.starLabelMetricPicker
                    }
                }
            }
            .frame( maxWidth: .infinity, alignment: .leading )
            .padding( .top, 4 )
        }
        label:
        {
            HStack( spacing: 6 )
            {
                Image( systemName: overlay.systemImageName )
                    .foregroundStyle( .secondary )

                Text( overlay.title )

                Spacer()

                if self.preferences.overlayAppearance( overlay.id ) != nil
                {
                    ResetButton( help: "Reset \( overlay.title )" )
                    {
                        self.preferences.resetOverlayAppearance( overlay.id )
                    }
                    .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.overlayResetButton( overlay.id ) )
                }
            }
        }
    }

    /// The stars overlay's measurement-label picker — None / HFR / FWHM — bound to
    /// the shared ``Preferences/starLabelMetric`` so the choice repaints every open
    /// canvas live and persists across launches. Shown only in the stars card.
    private var starLabelMetricPicker: some View
    {
        Picker( "Labels", selection: self.$preferences.starLabelMetric )
        {
            ForEach( StarLabelMetric.allCases )
            {
                metric in Text( metric.title ).tag( metric )
            }
        }
        .labelsHidden()
        .pickerStyle( .menu )
        .fixedSize()
        .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.starLabelMetricPicker )
    }

    /// A field label — small and grey — for the left column of a card's grid.
    ///
    /// - Parameter text: The label text.
    private func fieldLabel( _ text: String ) -> some View
    {
        Text( text )
            .font( .caption )
            .foregroundStyle( .secondary )
    }

    /// A native opacity slider with a trailing percentage read-out.
    ///
    /// - Parameter value: A binding to the opacity, in `0...1`.
    private func opacitySlider( _ value: Binding< Double > ) -> some View
    {
        HStack( spacing: 8 )
        {
            SwiftUI.Slider( value: value, in: 0 ... 1 )

            Text( value.wrappedValue.formatted( .percent.precision( .fractionLength( 0 ) ) ) )
                .font( .caption )
                .monospacedDigit()
                .foregroundStyle( .secondary )
                .frame( width: Self.readoutWidth, alignment: .trailing )
        }
    }

    /// A binding to an overlay's appearance, reading the user's customisation or the
    /// overlay's own default and writing changes straight into the shared store.
    ///
    /// - Parameter overlay: The overlay to bind.
    /// - Returns: The appearance binding.
    private func appearanceBinding( for overlay: any CanvasOverlay ) -> Binding< OverlayAppearance >
    {
        let id                = overlay.id
        let defaultAppearance = type( of: overlay ).defaultAppearance

        return Binding(
            get: { self.preferences.overlayAppearance( id ) ?? defaultAppearance },
            set: { self.preferences.overlayAppearances[ id ] = $0 }
        )
    }
}

#Preview
{
    OverlayAppearancePreferencesView( preferences: Preferences() )
        .frame( width: 620 )
}
