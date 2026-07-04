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

import AppKit
import SwiftPixel
import SwiftUI

/// The interactive Levels editor: a histogram backdrop over five sliders (input
/// black/white, midtone gamma, output black/white), applied uniformly or, for a
/// colour image, per channel.
///
/// Mirrors the inspector controls' pattern: the slider state is cached in
/// `@State`, seeded from the image's ``ImageAdjustments`` on creation, and every
/// change writes the recomposed ``Processors/Levels/Channels`` back and requests
/// a debounced re-render. The editor observes the image, so its histogram
/// updates live as the render commits.
struct LevelsEditorView: View
{
    /// The midtone gamma slider bounds, matching the gamma-correction control.
    private static let minimumGamma = 0.1
    private static let maximumGamma = 5.0

    /// The smallest gap kept between the input black and white points, so the
    /// mapping never collapses (the processor rejects `inputWhite <= inputBlack`).
    private static let minimumInputGap = 0.01

    /// The image whose levels are being edited; observed so the histogram tracks
    /// the committed render.
    @ObservedObject private var image: FITSImage

    /// The shared adjustments the editor writes to, observed so the editor also
    /// follows a change made from outside it — a menu/inspector Reset View, say —
    /// rather than showing stale slider values (see ``syncFromAdjustments()``).
    @ObservedObject private var adjustments: ImageAdjustments

    /// Whether the levels are edited per channel rather than as one master curve.
    @State private var perChannel: Bool

    /// The channel whose curve the sliders edit while ``perChannel`` is on.
    @State private var channel = Channel.red

    /// The master (all-channel) curve, used when ``perChannel`` is off.
    @State private var master: Curve

    /// The per-channel curves, used when ``perChannel`` is on.
    @State private var red:   Curve
    @State private var green: Curve
    @State private var blue:  Curve

    /// Whether the "switch to master" confirmation is shown. Switching back to
    /// master mode drops any per-channel adjustments (re-enabling reseeds from
    /// the master curve), so the switch is confirmed first when edits exist.
    @State private var showSwitchToMasterConfirmation = false

    /// A single channel's editable level values, the view-side mirror of
    /// ``Processors/Levels/Parameters``.
    struct Curve
    {
        var inputBlack  = 0.0
        var inputWhite  = 1.0
        var gamma       = 1.0
        var outputBlack = 0.0
        var outputWhite = 1.0

        /// Creates a curve from processor parameters.
        init( _ parameters: Processors.Levels.Parameters )
        {
            self.inputBlack  = parameters.inputBlack
            self.inputWhite  = parameters.inputWhite
            self.gamma       = parameters.gamma
            self.outputBlack = parameters.outputBlack
            self.outputWhite = parameters.outputWhite
        }

        /// The equivalent processor parameters.
        var parameters: Processors.Levels.Parameters
        {
            Processors.Levels.Parameters( inputBlack: self.inputBlack, inputWhite: self.inputWhite, gamma: self.gamma, outputBlack: self.outputBlack, outputWhite: self.outputWhite )
        }
    }

    /// Which per-channel curve is being edited.
    enum Channel: CaseIterable, Hashable, CustomStringConvertible
    {
        case red
        case green
        case blue

        /// The picker label.
        var description: String
        {
            switch self
            {
                case .red:   return "Red"
                case .green: return "Green"
                case .blue:  return "Blue"
            }
        }
    }

    /// Which level value a slider edits.
    private enum Field
    {
        case inputBlack
        case inputWhite
        case gamma
        case outputBlack
        case outputWhite
    }

    /// Creates the editor, seeding its slider state from the image's current
    /// levels.
    ///
    /// - Parameter image: The image whose levels are edited.
    init( image: FITSImage )
    {
        self.image       = image
        self.adjustments = image.renderer.adjustments

        switch image.renderer.adjustments.levels
        {
            case .uniform( let parameters ):

                self.perChannel = false
                self.master     = Curve( parameters )
                self.red        = Curve( parameters )
                self.green      = Curve( parameters )
                self.blue       = Curve( parameters )

            case .perChannel( let r, let g, let b ):

                self.perChannel = true
                self.master     = Curve( .identity )
                self.red        = Curve( r )
                self.green      = Curve( g )
                self.blue       = Curve( b )

            @unknown default:

                self.perChannel = false
                self.master     = Curve( .identity )
                self.red        = Curve( .identity )
                self.green      = Curve( .identity )
                self.blue       = Curve( .identity )
        }
    }

    /// The view's content.
    var body: some View
    {
        // No scroll view: the window is content-sized (fixed width, height adapts to
        // this content), so the controls lay out at their natural height. The
        // `.contain` accessibility element keeps the child controls individually
        // reachable in the accessibility tree while still exposing the `editor`
        // identifier — the role the enclosing scroll view previously served.
        VStack( alignment: .leading, spacing: 14 )
        {
            self.histogram

            if self.isMono == false
            {
                Toggle( "Per-channel", isOn: self.perChannelBinding )
                    .accessibilityIdentifier( AccessibilityIdentifier.LevelsWindowView.perChannelToggle )
                    .help( "Edit Each Colour Channel Independently" )

                if self.perChannel
                {
                    SegmentedControlView( selection: self.$channel, values: Channel.allCases, title: { $0.description } )
                        .accessibilityIdentifier( AccessibilityIdentifier.LevelsWindowView.channelPicker )
                }
            }

            Grid( alignment: .leading )
            {
                SliderGridRowView( value: self.binding( .inputBlack ), minimumValue: 0, maximumValue: 1, label: "Input Black", image: "circle.fill" )
                    .accessibilityIdentifier( AccessibilityIdentifier.LevelsWindowView.inputBlackSlider )

                SliderGridRowView( value: self.binding( .inputWhite ), minimumValue: 0, maximumValue: 1, label: "Input White", image: "circle" )
                    .accessibilityIdentifier( AccessibilityIdentifier.LevelsWindowView.inputWhiteSlider )

                SliderGridRowView( value: self.binding( .gamma ), minimumValue: Self.minimumGamma, maximumValue: Self.maximumGamma, label: "Gamma", image: "eye.fill" )
                    .accessibilityIdentifier( AccessibilityIdentifier.LevelsWindowView.gammaSlider )

                SliderGridRowView( value: self.binding( .outputBlack ), minimumValue: 0, maximumValue: 1, label: "Output Black", image: "circle.fill" )
                    .accessibilityIdentifier( AccessibilityIdentifier.LevelsWindowView.outputBlackSlider )

                SliderGridRowView( value: self.binding( .outputWhite ), minimumValue: 0, maximumValue: 1, label: "Output White", image: "circle" )
                    .accessibilityIdentifier( AccessibilityIdentifier.LevelsWindowView.outputWhiteSlider )
            }

            HStack
            {
                Spacer()

                Button( action: self.reset )
                {
                    Label( "Reset", systemImage: "arrow.counterclockwise" )
                }
                .accessibilityIdentifier( AccessibilityIdentifier.LevelsWindowView.resetButton )
                .help( "Reset the Levels to Their Defaults" )
            }
        }
        .padding( 16 )
        .frame( maxWidth: .infinity, alignment: .top )
        .navigationTitle( "Levels — \( self.image.info.url.lastPathComponent )" )
        .accessibilityElement( children: .contain )
        .accessibilityIdentifier( AccessibilityIdentifier.LevelsWindowView.editor )
        // Follow a change made from outside the editor (e.g. a Reset View): pull
        // it back into the sliders' displayed state.
        .onChange( of: self.adjustments.levels )
        {
            self.syncFromAdjustments()
        }
        .confirmationDialog( "Switch to Master Mode?", isPresented: self.$showSwitchToMasterConfirmation, titleVisibility: .visible )
        {
            Button( "Switch to Master", role: .destructive )
            {
                self.switchToMaster()
            }
            .accessibilityIdentifier( AccessibilityIdentifier.LevelsWindowView.switchToMasterConfirm )

            Button( "Cancel", role: .cancel )
            {}
        }
        message:
        {
            Text( "Your per-channel adjustments will be discarded." )
        }
    }

    /// The histogram backdrop, drawn from the latest committed render so it
    /// reflects the levels as they are applied.
    @ViewBuilder     private var histogram: some View
    {
        if let result = self.image.renderer.result
        {
            HistogramView(
                histogram:        result.histogram,
                separateChannels: false,
                mode:             result.histogram.isMono ? .mono : .rgb,
                logScale:         false
            )
            .frame( height: 120 )
            .padding( 6 )
            .background( Color( nsColor: .textBackgroundColor ) )
            .clipShape( RoundedRectangle( cornerRadius: 10 ) )
            .overlay( RoundedRectangle( cornerRadius: 10 ).strokeBorder( .quaternary, lineWidth: 0.5 ) )
        }
    }

    /// Whether the rendered image is monochrome, in which case per-channel
    /// editing is hidden (the channels are replicated, so it would only tint).
    private var isMono: Bool
    {
        self.image.renderer.result?.histogram.isMono ?? false
    }

    /// A binding to the per-channel toggle.
    ///
    /// Turning it on seeds the per-channel curves from the master curve so the
    /// switch is continuous. Turning it off reverts to the master curve, dropping
    /// any per-channel work — so when per-channel edits exist the switch is
    /// confirmed first rather than performed immediately (the toggle stays on
    /// until the user confirms).
    private var perChannelBinding: Binding< Bool >
    {
        Binding(
            get: { self.perChannel },
            set:
            {
                if $0
                {
                    if self.perChannel == false
                    {
                        self.red   = self.master
                        self.green = self.master
                        self.blue  = self.master
                    }

                    self.perChannel = true

                    self.commit()
                }
                else if self.hasPerChannelEdits
                {
                    self.showSwitchToMasterConfirmation = true
                }
                else
                {
                    self.perChannel = false

                    self.commit()
                }
            }
        )
    }

    /// Whether any per-channel curve has been adjusted away from the identity
    /// mapping (i.e. there is per-channel work that switching to master discards).
    private var hasPerChannelEdits: Bool
    {
        self.red.parameters.isIdentity == false || self.green.parameters.isIdentity == false || self.blue.parameters.isIdentity == false
    }

    /// Confirms the switch back to master mode: turns per-channel off and clears
    /// the per-channel curves, then re-renders from the master curve.
    private func switchToMaster()
    {
        self.perChannel = false
        self.red        = Curve( .identity )
        self.green      = Curve( .identity )
        self.blue       = Curve( .identity )

        self.commit()
    }

    /// A binding to one level value of the active curve (the master curve, or the
    /// selected channel while editing per channel). Setting it clamps the value,
    /// writes it back and commits.
    ///
    /// - Parameter field: Which level value to bind.
    /// - Returns: The binding.
    private func binding( _ field: Field ) -> Binding< Double >
    {
        Binding(
            get: { self.activeCurve[ keyPath: Self.keyPath( field ) ] },
            set:
            {
                var curve = self.activeCurve

                self.set( field, to: $0, in: &curve )
                self.writeActiveCurve( curve )
                self.commit()
            }
        )
    }

    /// The curve the sliders currently edit.
    private var activeCurve: Curve
    {
        guard self.perChannel
        else
        {
            return self.master
        }

        switch self.channel
        {
            case .red:   return self.red
            case .green: return self.green
            case .blue:  return self.blue
        }
    }

    /// Writes back the curve the sliders currently edit.
    ///
    /// - Parameter curve: The updated curve.
    private func writeActiveCurve( _ curve: Curve )
    {
        guard self.perChannel
        else
        {
            self.master = curve

            return
        }

        switch self.channel
        {
            case .red:   self.red   = curve
            case .green: self.green = curve
            case .blue:  self.blue  = curve
        }
    }

    /// The key path for a field's stored value.
    private static func keyPath( _ field: Field ) -> WritableKeyPath< Curve, Double >
    {
        switch field
        {
            case .inputBlack:  return \.inputBlack
            case .inputWhite:  return \.inputWhite
            case .gamma:       return \.gamma
            case .outputBlack: return \.outputBlack
            case .outputWhite: return \.outputWhite
        }
    }

    /// Sets a field on `curve`, keeping the input black and white points a
    /// minimum gap apart so the mapping stays valid.
    ///
    /// - Parameters:
    ///   - field: The field to set.
    ///   - value: The new value.
    ///   - curve: The curve to update, in place.
    private func set( _ field: Field, to value: Double, in curve: inout Curve )
    {
        switch field
        {
            case .inputBlack:  curve.inputBlack  = min( value, curve.inputWhite - Self.minimumInputGap )
            case .inputWhite:  curve.inputWhite  = max( value, curve.inputBlack + Self.minimumInputGap )
            case .gamma:       curve.gamma       = value
            case .outputBlack: curve.outputBlack = value
            case .outputWhite: curve.outputWhite = value
        }
    }

    /// The current channel configuration, recomposed from the editor's state.
    private var channels: Processors.Levels.Channels
    {
        self.perChannel
            ? .perChannel( red: self.red.parameters, green: self.green.parameters, blue: self.blue.parameters )
            : .uniform( self.master.parameters )
    }

    /// Re-seeds the editor's mode and curves from the shared adjustments when the
    /// levels change from outside the editor — a menu/inspector Reset View, say —
    /// so the sliders follow. Skipped when the adjustments already match what the
    /// editor represents, so the editor's own ``commit()`` writes don't echo back
    /// into a loop; it writes `@State` only, so it updates the display without
    /// re-committing or re-rendering.
    private func syncFromAdjustments()
    {
        guard self.adjustments.levels != self.channels
        else
        {
            return
        }

        switch self.adjustments.levels
        {
            case .uniform( let parameters ):

                self.perChannel = false
                self.master     = Curve( parameters )
                self.red        = Curve( parameters )
                self.green      = Curve( parameters )
                self.blue       = Curve( parameters )

            case .perChannel( let r, let g, let b ):

                self.perChannel = true
                self.master     = Curve( .identity )
                self.red        = Curve( r )
                self.green      = Curve( g )
                self.blue       = Curve( b )

            @unknown default:

                break
        }
    }

    /// Writes the current configuration into the image's adjustments and requests
    /// a debounced re-render.
    private func commit()
    {
        self.image.renderer.adjustments.levels = self.channels

        self.image.renderer.scheduleReRender()
    }

    /// Resets every curve to the identity mapping and re-renders.
    private func reset()
    {
        self.perChannel = false
        self.master     = Curve( .identity )
        self.red        = Curve( .identity )
        self.green      = Curve( .identity )
        self.blue       = Curve( .identity )

        self.commit()
    }
}
