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

import SwiftPixel
import SwiftUI

/// The white-balance section of the controls panel: a mode picker plus, in
/// manual mode, per-channel gain sliders.
public struct WhiteBalanceControlView: View
{
    /// The white-balance choices offered by the picker.
    public enum Mode: CaseIterable, CustomStringConvertible
    {
        /// No white balancing.
        case none

        /// Automatic, channel-equalizing white balance.
        case auto

        /// Manual per-channel gains.
        case manual

        /// The picker label for the mode.
        public var description: String
        {
            switch self
            {
                case .none:   return "None"
                case .auto:   return "Auto"
                case .manual: return "Manual"
            }
        }
    }

    /// Seed for the manual white-balance gains. Identity gains leave the image
    /// unchanged when the user first switches to Manual; zero gains would blank
    /// every channel to black.
    static let defaultManualGain = 1.0

    /// The shared adjustment values this control observes and writes to.
    @ObservedObject private var adjustments: ImageAdjustments

    /// Requests a debounced re-render after a change.
    private let reRender: () -> Void

    /// The selected white-balance mode. Seeded from the image's adjustments so
    /// the control reflects the file it belongs to, and re-synced when the
    /// adjustments change from outside the control (see ``syncFromAdjustments()``).
    @State private var mode: Mode

    /// The manual red-channel gain.
    @State private var red: Double

    /// The manual green-channel gain.
    @State private var green: Double

    /// The manual blue-channel gain.
    @State private var blue: Double

    /// A pending request to add white balance that would collide with a hand-built
    /// per-channel stretch, or `nil` when no confirmation is showing. Set when
    /// ``applyWhiteBalance()`` gets one back from the model; the confirmation dialog
    /// resolves it.
    @State private var pendingRequest: ImageAdjustments.WhiteBalanceRequest?

    /// Creates the white-balance control.
    ///
    /// The manual gains are seeded from the image's adjustments when Manual is
    /// active, and from the identity default otherwise.
    ///
    /// - Parameters:
    ///   - adjustments: The shared adjustment values to write to.
    ///   - reRender:    The closure to call after a change.
    public init( adjustments: ImageAdjustments, reRender: @escaping () -> Void )
    {
        self.adjustments = adjustments
        self.reRender    = reRender

        var red   = Self.defaultManualGain
        var green = Self.defaultManualGain
        var blue  = Self.defaultManualGain

        if case .manual( let r, let g, let b )? = adjustments.whiteBalance
        {
            red   = r
            green = g
            blue  = b
        }

        self.mode  = Self.mode( adjustments.whiteBalance )
        self.red   = red
        self.green = green
        self.blue  = blue
    }

    /// Maps a white-balance mode back to the control's mode, used to seed the
    /// control from an image's adjustments.
    ///
    /// - Parameter mode: The white-balance mode, or `nil` for untouched channels.
    /// - Returns: The corresponding control mode.
    static func mode( _ mode: Processors.WhiteBalance.Mode? ) -> Mode
    {
        guard let mode
        else
        {
            return .none
        }

        switch mode
        {
            case .auto:        return .auto
            case .manual:      return .manual
            @unknown default:  return .none
        }
    }

    /// Maps the control's selection and slider values to a white-balance mode.
    ///
    /// - Parameters:
    ///   - mode:  The selected white-balance mode.
    ///   - red:   The manual red gain.
    ///   - green: The manual green gain.
    ///   - blue:  The manual blue gain.
    /// - Returns: The corresponding mode, or `nil` for `.none`.
    static func mode( _ mode: Mode, red: Double, green: Double, blue: Double ) -> Processors.WhiteBalance.Mode?
    {
        switch mode
        {
            case .none:   return nil
            case .auto:   return .auto
            case .manual: return .manual( red: red, green: green, blue: blue )
        }
    }

    /// The view's content.
    public var body: some View
    {
        Grid( alignment: .leading )
        {
            GridRow
            {
                Text( "Mode" )
                Picker( "Mode", selection: $mode )
                {
                    ForEach( Mode.allCases, id: \.self )
                    {
                        Text( $0.description ).tag( $0 )
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier( AccessibilityIdentifier.WhiteBalanceControlView.modePicker )
                .help( "Choose How to White-Balance the Channels" )
            }

            if self.mode == .manual
            {
                SliderGridRowView( value: $red,   minimumValue: 0, maximumValue: 255, label: "Red",   image: "r.circle.fill", defaultValue: Self.defaultManualGain, resetIdentifier: AccessibilityIdentifier.WhiteBalanceControlView.redReset )
                    .accessibilityIdentifier( AccessibilityIdentifier.WhiteBalanceControlView.redSlider )
                    .help( "Red Gain" )
                SliderGridRowView( value: $green, minimumValue: 0, maximumValue: 255, label: "Green", image: "g.circle.fill", defaultValue: Self.defaultManualGain, resetIdentifier: AccessibilityIdentifier.WhiteBalanceControlView.greenReset )
                    .accessibilityIdentifier( AccessibilityIdentifier.WhiteBalanceControlView.greenSlider )
                    .help( "Green Gain" )
                SliderGridRowView( value: $blue,  minimumValue: 0, maximumValue: 255, label: "Blue",  image: "b.circle.fill", defaultValue: Self.defaultManualGain, resetIdentifier: AccessibilityIdentifier.WhiteBalanceControlView.blueReset )
                    .accessibilityIdentifier( AccessibilityIdentifier.WhiteBalanceControlView.blueSlider )
                    .help( "Blue Gain" )
            }
        }
        // A change the control makes: route it through the model so the managed
        // mutual-exclusion rule is enforced (enabling white balance over a managed
        // per-channel stretch silently re-derives that stretch as uniform), then
        // re-render. Skipped when it already matches the model — a managed re-derivation
        // syncs the control, and that must not echo back as a redundant write.
        .onChange( of: self.whiteBalanceMode )
        {
            guard self.whiteBalanceMode != self.adjustments.whiteBalance
            else
            {
                return
            }

            Task { await self.applyWhiteBalance() }
        }
        // A change from outside the control (e.g. a menu Reset View, or the stretch
        // forcing white balance off): pull it back into the control's displayed state.
        .onChange( of: self.adjustments.whiteBalance )
        {
            self.syncFromAdjustments()
        }
        // Adding white balance over a hand-built per-channel stretch would discard that
        // work, so confirm how to resolve it before committing anything.
        .confirmationDialog( "Add White Balance?", isPresented: self.isConfirmingCoexistence, titleVisibility: .visible )
        {
            Button( "Convert Stretch to Uniform" )
            {
                self.resolve( .convertStretchToUniform )
            }
            .keyboardShortcut( .defaultAction )
            .accessibilityIdentifier( AccessibilityIdentifier.WhiteBalanceControlView.convertStretchButton )

            Button( "Keep Both" )
            {
                self.resolve( .keepBoth )
            }
            .accessibilityIdentifier( AccessibilityIdentifier.WhiteBalanceControlView.keepBothButton )

            Button( "Cancel", role: .cancel )
            {
                self.cancelWhiteBalance()
            }
            .accessibilityIdentifier( AccessibilityIdentifier.WhiteBalanceControlView.cancelWhiteBalanceButton )
        }
        message:
        {
            Text( "A per-channel stretch and white balance both neutralize the colour cast. Convert the stretch to uniform so they compose, keep both (they may double up), or cancel." )
        }
    }

    /// Whether the coexistence confirmation is showing, derived from whether a request is
    /// pending. Dismissing it (tapping outside) cancels, reverting the picker.
    private var isConfirmingCoexistence: Binding< Bool >
    {
        Binding(
            get: { self.pendingRequest != nil },
            // Revert only on a genuine dismissal (Cancel, or tapping outside): the
            // affirmative buttons clear `pendingRequest` before the dialog dismisses, so
            // reverting here too would transiently flip the picker back to "None" before the
            // async resolve re-applies it.
            set: { if $0 == false, self.pendingRequest != nil { self.cancelWhiteBalance() } }
        )
    }

    /// Applies the control's white-balance selection through the model's mutual-exclusion
    /// rule, then re-renders. The rule may re-derive the stretch off the main actor
    /// (enabling white balance over a managed per-channel stretch yields it to uniform), so
    /// this is async. When adding white balance would discard a hand-built per-channel
    /// stretch, the model returns a request instead of committing — held for the
    /// confirmation dialog.
    @MainActor
    private func applyWhiteBalance() async
    {
        let request = await self.adjustments.setWhiteBalance( self.whiteBalanceMode )

        if let request
        {
            self.pendingRequest = request
        }

        self.reRender()
    }

    /// Commits the pending white-balance addition the way the user resolved the collision,
    /// clears the request and re-renders.
    ///
    /// - Parameter resolution: The chosen outcome (convert the stretch to uniform, or keep both).
    private func resolve( _ resolution: ImageAdjustments.WhiteBalanceResolution )
    {
        guard let request = self.pendingRequest
        else
        {
            return
        }

        self.pendingRequest = nil

        Task
        {
            await self.adjustments.resolve( request, as: resolution )

            self.reRender()
        }
    }

    /// Cancels a pending white-balance addition: nothing is committed, so the picker is
    /// reverted to the model's (unchanged) white-balance state.
    private func cancelWhiteBalance()
    {
        self.pendingRequest = nil

        self.syncFromAdjustments()
    }

    /// The white-balance mode derived from the current selection and gains.
    private var whiteBalanceMode: Processors.WhiteBalance.Mode?
    {
        Self.mode( self.mode, red: self.red, green: self.green, blue: self.blue )
    }

    /// Re-seeds the control's mode and, in Manual, its gains from the shared
    /// adjustments when they change from outside the control — a menu Reset View,
    /// say — so the displayed state follows. Skipped when the adjustments already
    /// match what the control represents, so the control's own writes don't echo
    /// back into a loop.
    private func syncFromAdjustments()
    {
        let value = self.adjustments.whiteBalance

        guard value != self.whiteBalanceMode
        else
        {
            return
        }

        self.mode = Self.mode( value )

        if case .manual( let r, let g, let b )? = value
        {
            self.red   = r
            self.green = g
            self.blue  = b
        }
    }
}

#Preview
{
    WhiteBalanceControlView( adjustments: ImageAdjustments(), reRender: {} )
        .frame( maxWidth: .infinity, alignment: .leading )
        .frame( maxHeight: .infinity, alignment: .top )
        .padding()
}
