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

/// The stretch section of the controls panel: a mode picker (None or Screen
/// Transfer) plus the Screen Transfer editor actions. The Screen Transfer is the
/// only tone stretch — a PixInsight-style midtones auto-stretch.
public struct StretchControlView: View
{
    /// The stretch modes offered by the picker.
    public enum Mode: CaseIterable, CustomStringConvertible
    {
        /// No stretch; the image stays linear.
        case none

        /// Screen Transfer Function (STF): a PixInsight-style midtones auto-stretch,
        /// edited in a dedicated window.
        case screenTransfer

        /// The picker label for the mode.
        public var description: String
        {
            switch self
            {
                case .none:           return "None"
                case .screenTransfer: return "Screen Transfer"
            }
        }
    }

    /// The scene identifier of the dedicated Screen Transfer editor window.
    static let screenTransferWindowID = "ScreenTransferWindow"

    /// The shared adjustment values this control observes and writes to.
    @ObservedObject private var adjustments: ImageAdjustments

    /// Requests a debounced re-render after a change.
    private let reRender: () -> Void

    /// Whether an auto-STF can currently be derived, used to enable or disable the
    /// Auto toggle (matching the editor window). Cheap enough to call each render.
    private let canAutoScreenTransfer: () -> Bool

    /// Opens the dedicated Screen Transfer editor window.
    @Environment( \.openWindow ) private var openWindow

    /// Whether an auto-STF derivation is in flight, disabling the Auto toggle while
    /// it runs off the main actor.
    @State private var isDerivingAuto = false

    /// The pending per-channel engage awaiting the user's white-balance-removal
    /// decision, or `nil` when no confirmation is showing. Set when engaging Auto would
    /// remove active white balance (see ``engageAuto()``); the confirmation dialog
    /// resolves it.
    @State private var pendingRequest: ImageAdjustments.PerChannelStretchRequest?

    /// The selected stretch mode. Seeded from the image's adjustments so the
    /// control reflects the file it belongs to, and re-synced when the
    /// adjustments change from outside the control (see ``syncFromAdjustments()``).
    @State private var mode: Mode

    /// The current screen-transfer parameters, edited in the Screen Transfer
    /// window and mirrored here so the applied stretch can be recomposed and kept
    /// in sync with the shared adjustments.
    @State private var screenTransfer: Processors.Stretch.STFParameters

    /// Creates the stretch control.
    ///
    /// The mode and the screen-transfer parameters are seeded from the image's
    /// current adjustments, so the control reflects the file it belongs to.
    ///
    /// - Parameters:
    ///   - adjustments:          The shared adjustment values to write to.
    ///   - reRender:             The closure to call after a change.
    ///   - canAutoScreenTransfer: Whether a derivation is currently possible, used
    ///                            to enable the Auto toggle. Defaults to `false`.
    public init( adjustments: ImageAdjustments, reRender: @escaping () -> Void, canAutoScreenTransfer: @escaping () -> Bool = { false } )
    {
        self.adjustments           = adjustments
        self.reRender              = reRender
        self.canAutoScreenTransfer = canAutoScreenTransfer
        self.mode                  = Self.mode( adjustments.stretch )
        self.screenTransfer        = adjustments.stretch ?? .identity
    }

    /// Maps the applied stretch back to the control's mode, used to seed the
    /// control from an image's adjustments.
    ///
    /// - Parameter stretch: The applied Screen Transfer parameters, or `nil` for a
    ///                      linear image.
    /// - Returns: The corresponding mode.
    static func mode( _ stretch: Processors.Stretch.STFParameters? ) -> Mode
    {
        stretch == nil ? .none : .screenTransfer
    }

    /// Maps the control's selection to the applied stretch.
    ///
    /// - Parameters:
    ///   - mode:           The selected stretch mode.
    ///   - screenTransfer: The current screen-transfer parameters, used for the
    ///                     ``Mode/screenTransfer`` mode (edited in its window).
    /// - Returns: The parameters for ``Mode/screenTransfer``, or `nil` for
    ///            ``Mode/none``.
    static func stretch( mode: Mode, screenTransfer: Processors.Stretch.STFParameters ) -> Processors.Stretch.STFParameters?
    {
        switch mode
        {
            case .none:           return nil
            case .screenTransfer: return screenTransfer
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
                .accessibilityIdentifier( AccessibilityIdentifier.StretchControlView.modePicker )
                .help( "Choose the Tone-Stretch Mode" )
            }

            if self.mode == .screenTransfer
            {
                // The screen transfer is edited in its own window (like Levels and
                // Curves); the inspector offers a one-click Auto and a way to open
                // the editor.
                GridRow
                {
                    Text( "Editor" )

                    HStack
                    {
                        Toggle( isOn: self.autoBinding )
                        {
                            Label( "Auto", systemImage: "wand.and.stars" )
                                .frame( maxWidth: .infinity )
                        }
                        .toggleStyle( .button )
                        .accessibilityIdentifier( AccessibilityIdentifier.StretchControlView.autoButton )
                        .help( "Manage the Screen Transfer Automatically" )
                        .disabled( self.isDerivingAuto || self.canAutoScreenTransfer() == false )

                        Button
                        {
                            self.openWindow( id: Self.screenTransferWindowID, value: SingletonWindow.token )
                        }
                        label:
                        {
                            Label( "Edit\u{2026}", systemImage: "slider.horizontal.3" )
                                .frame( maxWidth: .infinity )
                        }
                        .accessibilityIdentifier( AccessibilityIdentifier.StretchControlView.editButton )
                        .help( "Open the Screen Transfer Editor" )
                    }
                }
            }
        }
        // A change the control makes (the mode picker): push it to the shared
        // adjustments and re-render. Skipped when it already matches — a managed engage
        // sets the stretch through the model, and the resulting `syncFromAdjustments`
        // must not echo it back as a direct write, which would disengage Auto.
        .onChange( of: self.stretchParameters )
        {
            guard self.stretchParameters != self.adjustments.stretch
            else
            {
                return
            }

            self.adjustments.stretch = self.stretchParameters

            self.reRender()
        }
        // A change from outside the control (e.g. a menu Reset View, or a managed
        // engage): pull it back into the control's displayed state.
        .onChange( of: self.adjustments.stretch )
        {
            self.syncFromAdjustments()
        }
        // Engaging a per-channel Auto stretch while white balance is active needs the
        // user to choose how to resolve the collision before anything is committed.
        .confirmationDialog( "Remove White Balance?", isPresented: self.isConfirmingWhiteBalanceRemoval, titleVisibility: .visible )
        {
            Button( "Remove White Balance" )
            {
                self.resolve( .removeWhiteBalance )
            }
            .keyboardShortcut( .defaultAction )
            .accessibilityIdentifier( AccessibilityIdentifier.StretchControlView.removeWhiteBalanceButton )

            Button( "Keep White Balance" )
            {
                self.resolve( .keepWhiteBalance )
            }
            .accessibilityIdentifier( AccessibilityIdentifier.StretchControlView.keepWhiteBalanceButton )

            Button( "Cancel", role: .cancel )
            {
                self.pendingRequest = nil
            }
            .accessibilityIdentifier( AccessibilityIdentifier.StretchControlView.cancelWhiteBalanceRemovalButton )
        }
        message:
        {
            Text( "A per-channel auto stretch neutralizes the colour cast on its own, so white balance is redundant. Remove it for the clean result, or keep both and switch to manual." )
        }
    }

    /// The applied stretch derived from the current mode.
    private var stretchParameters: Processors.Stretch.STFParameters?
    {
        Self.stretch( mode: self.mode, screenTransfer: self.screenTransfer )
    }

    /// The Auto (managed) toggle's binding: reads the model's engaged state, and
    /// engages or disengages on change.
    ///
    /// Engaging runs the (async, off-main-actor) derivation, so it is dispatched on a
    /// task; disengaging is immediate. The toggle reflects ``ImageAdjustments/isAutoStretch``,
    /// so when engaging routes to the white-balance confirmation (nothing committed yet)
    /// it stays visually off until the user resolves it.
    private var autoBinding: Binding< Bool >
    {
        Binding(
            get: { self.adjustments.isAutoStretch },
            set:
            { engage in

                if engage
                {
                    Task { await self.engageAuto() }
                }
                else
                {
                    self.adjustments.disengageAutoStretch()
                }
            }
        )
    }

    /// Whether the white-balance-removal confirmation is showing, derived from whether a
    /// request is pending. Dismissing it (tapping outside) discards the request.
    private var isConfirmingWhiteBalanceRemoval: Binding< Bool >
    {
        Binding(
            get: { self.pendingRequest != nil },
            set: { if $0 == false { self.pendingRequest = nil } }
        )
    }

    /// Engages the managed Auto stretch: derives a per-channel STF (off the main actor)
    /// and applies it through the model's mutual-exclusion rule. When white balance is
    /// active the collision is not committed silently — the returned request is held so
    /// the confirmation dialog can resolve it; otherwise the stretch is applied and the
    /// image re-rendered.
    @MainActor
    private func engageAuto() async
    {
        self.isDerivingAuto = true

        let request = await self.adjustments.requestPerChannelAutoStretch()

        self.isDerivingAuto = false

        guard let request
        else
        {
            // Applied and engaged directly (no white balance to resolve), or nothing was
            // derivable — either way a re-render reflects the current stretch.
            self.reRender()

            return
        }

        self.pendingRequest = request
    }

    /// Commits the pending per-channel engage the way the user resolved the white-balance
    /// collision, clears the request and re-renders.
    ///
    /// - Parameter resolution: The chosen outcome (remove or keep white balance).
    private func resolve( _ resolution: ImageAdjustments.PerChannelStretchResolution )
    {
        guard let request = self.pendingRequest
        else
        {
            return
        }

        self.adjustments.resolve( request, as: resolution )

        self.pendingRequest = nil

        self.reRender()
    }

    /// Re-seeds the control's mode and screen-transfer parameters from the shared
    /// adjustments when they change from outside the control — a menu Reset View,
    /// say — so the displayed state follows. Skipped when the adjustments already
    /// match what the control represents, so the control's own writes don't echo
    /// back into a loop.
    private func syncFromAdjustments()
    {
        let stretch = self.adjustments.stretch

        guard stretch != self.stretchParameters
        else
        {
            return
        }

        self.mode = Self.mode( stretch )

        if let stretch
        {
            self.screenTransfer = stretch
        }
    }
}

// Auto engaged: the image opened auto-stretched, so the toggle reads on.
#Preview( "Auto engaged" )
{
    StretchControlView(
        adjustments:
        {
            let opened = ImageProcessor.Settings( normalize: .identity, stretch: .uniform( .init( midtones: 0.3 ) ) )

            return ImageAdjustments( baseline: ImageProcessor.Settings(), opened: opened )
        }(),
        reRender:              {},
        canAutoScreenTransfer: { true }
    )
    .frame( maxWidth: .infinity, alignment: .leading )
    .frame( maxHeight: .infinity, alignment: .top )
    .padding()
}

// Manual stretch: a hand-set STF, so the toggle reads off (Auto disengaged) while the
// Screen Transfer editor actions stay available.
#Preview( "Auto off (manual)" )
{
    StretchControlView(
        adjustments:
        {
            let adjustments = ImageAdjustments()

            adjustments.stretch = .uniform( .init( midtones: 0.3 ) )

            return adjustments
        }(),
        reRender:              {},
        canAutoScreenTransfer: { true }
    )
    .frame( maxWidth: .infinity, alignment: .leading )
    .frame( maxHeight: .infinity, alignment: .top )
    .padding()
}

// None: no stretch, so the Screen Transfer actions (and the Auto toggle) are hidden.
#Preview( "None" )
{
    StretchControlView( adjustments: ImageAdjustments(), reRender: {} )
        .frame( maxWidth: .infinity, alignment: .leading )
        .frame( maxHeight: .infinity, alignment: .top )
        .padding()
}
