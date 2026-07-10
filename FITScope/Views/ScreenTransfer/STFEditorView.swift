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

/// The interactive Screen Transfer Function (STF) editor: a histogram backdrop
/// over the shadows / midtones / highlights and low/high range-expansion sliders,
/// applied uniformly or, for a colour image, per channel, plus a one-click Auto
/// (with tunable shadow-clip factor and target background) that derives the STF
/// from the image.
///
/// Mirrors the Levels editor's pattern: the slider state is cached in `@State`,
/// seeded from the image's ``ImageAdjustments`` on creation, and every change
/// writes the recomposed ``Processors/Stretch/STFParameters`` back (as a
/// ``Processors/Stretch/Algorithm/screenTransfer(_:)`` stretch) and requests a
/// debounced re-render. The editor observes the image, so its histogram updates
/// live as the render commits.
struct STFEditorView: View
{
    /// The midtones slider bounds; the MTF balance is defined on `[0, 1]`.
    private static let minimumMidtones = 0.0
    private static let maximumMidtones = 1.0

    /// The shadow-clip factor slider bounds (median-absolute-deviations below the
    /// median), and the target-background bounds.
    private static let minimumShadowClipFactor = 0.0
    private static let maximumShadowClipFactor = 10.0
    private static let minimumTargetBackground = 0.0
    private static let maximumTargetBackground = 1.0

    /// The default auto-derivation settings, matching the SwiftPixel defaults.
    static let defaultShadowClipFactor = 2.8
    static let defaultTargetBackground = 0.25

    /// The smallest gap kept between the shadows and highlights, and between the
    /// low and high expansion bounds, so the mapping never collapses (the
    /// processor rejects `highlights <= shadows` and `high <= low`).
    private static let minimumGap = 0.001

    /// The identity channel, the single source for each slider's per-field reset
    /// default (shadows 0, midtones 0.5, highlights 1, low 0, high 1).
    private static let identityChannel = STF( .identity )

    /// The image whose screen transfer is being edited; observed so the histogram
    /// tracks the committed render.
    @ObservedObject private var image: LoadedImage

    /// The shared adjustments the editor writes to, observed so the editor also
    /// follows a change made from outside it — a menu/inspector Reset View, say —
    /// rather than showing stale slider values (see ``syncFromAdjustments()``).
    @ObservedObject private var adjustments: ImageAdjustments

    /// Whether the STF is edited per channel rather than as one master curve.
    @State private var perChannel: Bool

    /// The channel whose parameters the sliders edit while ``perChannel`` is on.
    @State private var channel = Channel.red

    /// The master (all-channel) parameters, used when ``perChannel`` is off.
    @State private var master: STF

    /// The per-channel parameters, used when ``perChannel`` is on.
    @State private var red:   STF
    @State private var green: STF
    @State private var blue:  STF

    /// The auto-derivation shadow-clip factor (how many MADs below the median to
    /// clip the shadows). A derivation knob, not part of the STF itself.
    @State private var shadowClipFactor = STFEditorView.defaultShadowClipFactor

    /// The auto-derivation target background (the value the median maps to).
    @State private var targetBackground = STFEditorView.defaultTargetBackground

    /// Whether the "switch to master" confirmation is shown. Switching back to
    /// master mode drops any per-channel adjustments (re-enabling reseeds from the
    /// master parameters), so the switch is confirmed first when edits exist.
    @State private var showSwitchToMasterConfirmation = false

    /// Whether an auto-STF derivation is in flight, disabling the Auto action while
    /// it runs off the main actor.
    @State private var isDeriving = false

    /// A single channel's editable STF values, the view-side mirror of
    /// ``Processors/Stretch/STFParameters/Channel``.
    struct STF
    {
        var shadows    = 0.0
        var midtones   = 0.5
        var highlights = 1.0
        var low        = 0.0
        var high       = 1.0

        /// Creates an editable value from processor parameters.
        init( _ channel: Processors.Stretch.STFParameters.Channel )
        {
            self.shadows    = channel.shadows
            self.midtones   = channel.midtones
            self.highlights = channel.highlights
            self.low        = channel.low
            self.high       = channel.high
        }

        /// The equivalent processor parameters.
        var channel: Processors.Stretch.STFParameters.Channel
        {
            Processors.Stretch.STFParameters.Channel( shadows: self.shadows, midtones: self.midtones, highlights: self.highlights, low: self.low, high: self.high )
        }
    }

    /// Which per-channel parameters are being edited.
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

    /// Which STF value a slider edits.
    private enum Field
    {
        case shadows
        case midtones
        case highlights
        case low
        case high
    }

    /// Creates the editor, seeding its slider state from the image's current
    /// screen transfer.
    ///
    /// - Parameter image: The image whose screen transfer is edited.
    init( image: LoadedImage )
    {
        self.image       = image
        self.adjustments = image.renderer.adjustments

        switch image.renderer.adjustments.stretch
        {
            case .screenTransfer( .uniform( let channel ) ):

                self.perChannel = false
                self.master     = STF( channel )
                self.red        = STF( channel )
                self.green      = STF( channel )
                self.blue       = STF( channel )

            case .screenTransfer( .perChannel( let r, let g, let b ) ):

                self.perChannel = true
                self.master     = STF( .identity )
                self.red        = STF( r )
                self.green      = STF( g )
                self.blue       = STF( b )

            default:

                self.perChannel = false
                self.master     = STF( .identity )
                self.red        = STF( .identity )
                self.green      = STF( .identity )
                self.blue       = STF( .identity )
        }
    }

    /// The view's content.
    var body: some View
    {
        VStack( alignment: .leading, spacing: 14 )
        {
            self.histogram

            Grid( alignment: .leading )
            {
                if self.isMono == false
                {
                    GridRow
                    {
                        Text( "Per-channel" )

                        Toggle( isOn: self.perChannelBinding ) { EmptyView() }
                            .toggleStyle( CapsuleToggleStyle() )
                            .accessibilityIdentifier( AccessibilityIdentifier.ScreenTransferWindowView.perChannelToggle )
                            .help( "Edit Each Colour Channel Independently" )
                    }

                    if self.perChannel
                    {
                        GridRow
                        {
                            SegmentedControlView( selection: self.$channel, values: Channel.allCases, title: { $0.description } )
                                .gridCellColumns( 3 )
                                .accessibilityIdentifier( AccessibilityIdentifier.ScreenTransferWindowView.channelPicker )
                        }
                    }
                }

                SliderGridRowView( value: self.binding( .shadows ), minimumValue: 0, maximumValue: 1, label: "Shadows", image: "circle.fill", defaultValue: Self.identityChannel.shadows, resetIdentifier: AccessibilityIdentifier.ScreenTransferWindowView.shadowsReset )
                    .accessibilityIdentifier( AccessibilityIdentifier.ScreenTransferWindowView.shadowsSlider )

                SliderGridRowView( value: self.binding( .midtones ), minimumValue: Self.minimumMidtones, maximumValue: Self.maximumMidtones, label: "Midtones", image: "circle.lefthalf.filled", defaultValue: Self.identityChannel.midtones, resetIdentifier: AccessibilityIdentifier.ScreenTransferWindowView.midtonesReset )
                    .accessibilityIdentifier( AccessibilityIdentifier.ScreenTransferWindowView.midtonesSlider )

                SliderGridRowView( value: self.binding( .highlights ), minimumValue: 0, maximumValue: 1, label: "Highlights", image: "circle", defaultValue: Self.identityChannel.highlights, resetIdentifier: AccessibilityIdentifier.ScreenTransferWindowView.highlightsReset )
                    .accessibilityIdentifier( AccessibilityIdentifier.ScreenTransferWindowView.highlightsSlider )

                SliderGridRowView( value: self.binding( .low ), minimumValue: 0, maximumValue: 1, label: "Low Range", image: "arrow.down.to.line", defaultValue: Self.identityChannel.low, resetIdentifier: AccessibilityIdentifier.ScreenTransferWindowView.lowReset )
                    .accessibilityIdentifier( AccessibilityIdentifier.ScreenTransferWindowView.lowSlider )

                SliderGridRowView( value: self.binding( .high ), minimumValue: 0, maximumValue: 1, label: "High Range", image: "arrow.up.to.line", defaultValue: Self.identityChannel.high, resetIdentifier: AccessibilityIdentifier.ScreenTransferWindowView.highReset )
                    .accessibilityIdentifier( AccessibilityIdentifier.ScreenTransferWindowView.highSlider )

                Divider()
                    .gridCellColumns( 2 )

                SliderGridRowView( value: self.$shadowClipFactor, minimumValue: Self.minimumShadowClipFactor, maximumValue: Self.maximumShadowClipFactor, label: "Auto Clip", image: "scissors", defaultValue: Self.defaultShadowClipFactor, resetIdentifier: AccessibilityIdentifier.ScreenTransferWindowView.shadowClipFactorReset )
                    .accessibilityIdentifier( AccessibilityIdentifier.ScreenTransferWindowView.shadowClipFactorSlider )
                    .help( "Shadow Clip, in Median Absolute Deviations Below the Median" )

                SliderGridRowView( value: self.$targetBackground, minimumValue: Self.minimumTargetBackground, maximumValue: Self.maximumTargetBackground, label: "Auto Bkg", image: "target", defaultValue: Self.defaultTargetBackground, resetIdentifier: AccessibilityIdentifier.ScreenTransferWindowView.targetBackgroundReset )
                    .accessibilityIdentifier( AccessibilityIdentifier.ScreenTransferWindowView.targetBackgroundSlider )
                    .help( "The Background Level the Median Is Mapped To" )
            }

            HStack
            {
                Button
                {
                    Task { await self.auto() }
                }
                label:
                {
                    Label( "Auto", systemImage: "wand.and.stars" )
                }
                .accessibilityIdentifier( AccessibilityIdentifier.ScreenTransferWindowView.autoButton )
                .help( "Auto-Compute the Screen Transfer From the Image" )
                .disabled( self.isDeriving || self.image.renderer.canAutoScreenTransfer == false )

                Spacer()

                Button( action: self.reset )
                {
                    Label( "Reset", systemImage: "arrow.counterclockwise" )
                }
                .accessibilityIdentifier( AccessibilityIdentifier.ScreenTransferWindowView.resetButton )
                .help( "Reset the Screen Transfer to the Identity" )
            }
        }
        .disabled( self.image.renderer.isRendering )
        .padding( 16 )
        .frame( maxWidth: .infinity, alignment: .top )
        .navigationTitle( "Screen Transfer — \( self.image.url.lastPathComponent )" )
        .accessibilityElement( children: .contain )
        .accessibilityIdentifier( AccessibilityIdentifier.ScreenTransferWindowView.editor )
        // Follow a change made from outside the editor (e.g. a Reset View): pull it
        // back into the sliders' displayed state.
        .onChange( of: self.adjustments.stretch )
        {
            self.syncFromAdjustments()
        }
        .confirmationDialog( "Switch to Master Mode?", isPresented: self.$showSwitchToMasterConfirmation, titleVisibility: .visible )
        {
            Button( "Switch to Master", role: .destructive )
            {
                self.switchToMaster()
            }
            .accessibilityIdentifier( AccessibilityIdentifier.ScreenTransferWindowView.switchToMasterConfirm )

            Button( "Cancel", role: .cancel )
            {}
        }
        message:
        {
            Text( "Your per-channel adjustments will be discarded." )
        }
    }

    /// The histogram backdrop, drawn from the latest committed render so it
    /// reflects the screen transfer as it is applied.
    @ViewBuilder private var histogram: some View
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

    /// Whether the rendered image is monochrome, in which case per-channel editing
    /// is hidden (the channels are replicated, so it would only tint).
    private var isMono: Bool
    {
        self.image.renderer.result?.histogram.isMono ?? false
    }

    /// A binding to the per-channel toggle.
    ///
    /// Turning it on seeds the per-channel parameters from the master so the switch
    /// is continuous. Turning it off reverts to the master, dropping any
    /// per-channel work — so when per-channel edits exist the switch is confirmed
    /// first rather than performed immediately (the toggle stays on until the user
    /// confirms).
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

    /// Whether any per-channel parameters have been adjusted away from the identity
    /// (i.e. there is per-channel work that switching to master discards).
    private var hasPerChannelEdits: Bool
    {
        self.red.channel.isIdentity == false || self.green.channel.isIdentity == false || self.blue.channel.isIdentity == false
    }

    /// Confirms the switch back to master mode: turns per-channel off and clears
    /// the per-channel parameters, then re-renders from the master.
    private func switchToMaster()
    {
        self.perChannel = false
        self.red        = Self.identityChannel
        self.green      = Self.identityChannel
        self.blue       = Self.identityChannel

        self.commit()
    }

    /// A binding to one STF value of the active parameters (the master, or the
    /// selected channel while editing per channel). Setting it clamps the value,
    /// writes it back and commits.
    ///
    /// - Parameter field: Which STF value to bind.
    /// - Returns: The binding.
    private func binding( _ field: Field ) -> Binding< Double >
    {
        Binding(
            get: { self.activeSTF[ keyPath: Self.keyPath( field ) ] },
            set:
            {
                var stf = self.activeSTF

                self.set( field, to: $0, in: &stf )
                self.writeActiveSTF( stf )
                self.commit()
            }
        )
    }

    /// The parameters the sliders currently edit.
    private var activeSTF: STF
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

    /// Writes back the parameters the sliders currently edit.
    ///
    /// - Parameter stf: The updated parameters.
    private func writeActiveSTF( _ stf: STF )
    {
        guard self.perChannel
        else
        {
            self.master = stf

            return
        }

        switch self.channel
        {
            case .red:   self.red   = stf
            case .green: self.green = stf
            case .blue:  self.blue  = stf
        }
    }

    /// The key path for a field's stored value.
    private static func keyPath( _ field: Field ) -> WritableKeyPath< STF, Double >
    {
        switch field
        {
            case .shadows:    return \.shadows
            case .midtones:   return \.midtones
            case .highlights: return \.highlights
            case .low:        return \.low
            case .high:       return \.high
        }
    }

    /// Sets a field on `stf`, keeping the shadows and highlights — and the low and
    /// high expansion bounds — a minimum gap apart so the mapping stays valid.
    ///
    /// - Parameters:
    ///   - field: The field to set.
    ///   - value: The new value.
    ///   - stf:   The parameters to update, in place.
    private func set( _ field: Field, to value: Double, in stf: inout STF )
    {
        switch field
        {
            case .shadows:    stf.shadows    = min( value, stf.highlights - Self.minimumGap )
            case .midtones:   stf.midtones   = value
            case .highlights: stf.highlights = max( value, stf.shadows + Self.minimumGap )
            case .low:        stf.low        = min( value, stf.high - Self.minimumGap )
            case .high:       stf.high       = max( value, stf.low + Self.minimumGap )
        }
    }

    /// The current parameters, recomposed from the editor's state.
    private var parameters: Processors.Stretch.STFParameters
    {
        self.perChannel
            ? .perChannel( red: self.red.channel, green: self.green.channel, blue: self.blue.channel )
            : .uniform( self.master.channel )
    }

    /// Re-seeds the editor's mode and parameters from the shared adjustments when
    /// the stretch changes from outside the editor — a menu/inspector Reset View,
    /// say — so the sliders follow. Skipped when the adjustments already match what
    /// the editor represents, so the editor's own ``commit()`` writes don't echo
    /// back into a loop; it writes `@State` only, so it updates the display without
    /// re-committing or re-rendering.
    private func syncFromAdjustments()
    {
        guard self.adjustments.stretch != .screenTransfer( self.parameters )
        else
        {
            return
        }

        switch self.adjustments.stretch
        {
            case .screenTransfer( .uniform( let channel ) ):

                self.perChannel = false
                self.master     = STF( channel )
                self.red        = STF( channel )
                self.green      = STF( channel )
                self.blue       = STF( channel )

            case .screenTransfer( .perChannel( let r, let g, let b ) ):

                self.perChannel = true
                self.master     = STF( .identity )
                self.red        = STF( r )
                self.green      = STF( g )
                self.blue       = STF( b )

            default:

                // No STF is applied (a Reset View, or another stretch mode): show
                // the identity rather than stale, unapplied slider values, matching
                // how the inspector drops to its "None" mode.
                self.perChannel = false
                self.master     = Self.identityChannel
                self.red        = Self.identityChannel
                self.green      = Self.identityChannel
                self.blue       = Self.identityChannel
        }
    }

    /// Derives an auto-STF from the image (off the main actor) using the current
    /// auto settings and fills the sliders, then commits. Does nothing when no
    /// derivation is available.
    @MainActor
    private func auto() async
    {
        self.isDeriving = true

        let derived = await self.image.renderer.autoScreenTransfer( shadowClipFactor: self.shadowClipFactor, targetBackground: self.targetBackground )

        self.isDeriving = false

        guard let parameters = derived
        else
        {
            return
        }

        switch parameters
        {
            case .uniform( let channel ):

                self.perChannel = false
                self.master     = STF( channel )
                self.red        = STF( channel )
                self.green      = STF( channel )
                self.blue       = STF( channel )

            case .perChannel( let r, let g, let b ):

                self.perChannel = true
                self.master     = STF( .identity )
                self.red        = STF( r )
                self.green      = STF( g )
                self.blue       = STF( b )

            @unknown default:

                return
        }

        self.commit()
    }

    /// Writes the current parameters into the image's adjustments (as a
    /// ``Processors/Stretch/Algorithm/screenTransfer(_:)`` stretch) and requests a
    /// debounced re-render.
    private func commit()
    {
        self.image.renderer.adjustments.stretch = .screenTransfer( self.parameters )

        self.image.renderer.scheduleReRender()
    }

    /// Resets every channel to the identity and re-renders.
    private func reset()
    {
        self.perChannel = false
        self.master     = Self.identityChannel
        self.red        = Self.identityChannel
        self.green      = Self.identityChannel
        self.blue       = Self.identityChannel

        self.commit()
    }
}

#Preview
{
    if let image = PreviewHelper.image( file: .M42 )
    {
        STFEditorView( image: image )
            .frame( width: 400 )
            .task
            {
                await image.renderer.render()
            }
    }
    else
    {
        Text( "Sample image unavailable." )
    }
}
