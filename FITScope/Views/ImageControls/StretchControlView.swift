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

    /// Derives auto-STF parameters from the current image for the Auto action, or
    /// `nil` when no derivation is possible (no image or no detection buffer). The
    /// derivation runs off the main actor, so this is `async`. Injected so the
    /// control stays decoupled from the image model.
    private let autoScreenTransfer: () async -> Processors.Stretch.STFParameters?

    /// Whether an auto-STF can currently be derived, used to enable or disable the
    /// Auto action (matching the editor window). Cheap enough to call each render.
    private let canAutoScreenTransfer: () -> Bool

    /// Opens the dedicated Screen Transfer editor window.
    @Environment( \.openWindow ) private var openWindow

    /// Whether an auto-STF derivation is in flight, disabling the Auto action while
    /// it runs off the main actor.
    @State private var isDerivingAuto = false

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
    ///   - autoScreenTransfer:   Derives auto-STF parameters from the current image
    ///                           (off the main actor), or `nil` when unavailable.
    ///                           Defaults to no derivation.
    ///   - canAutoScreenTransfer: Whether a derivation is currently possible, used
    ///                            to enable the Auto action. Defaults to `false`.
    public init( adjustments: ImageAdjustments, reRender: @escaping () -> Void, autoScreenTransfer: @escaping () async -> Processors.Stretch.STFParameters? = { nil }, canAutoScreenTransfer: @escaping () -> Bool = { false } )
    {
        self.adjustments           = adjustments
        self.reRender              = reRender
        self.autoScreenTransfer    = autoScreenTransfer
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
                        Button
                        {
                            Task { await self.applyAutoScreenTransfer() }
                        }
                        label:
                        {
                            Label( "Auto", systemImage: "wand.and.stars" )
                                .frame( maxWidth: .infinity )
                        }
                        .accessibilityIdentifier( AccessibilityIdentifier.StretchControlView.autoButton )
                        .help( "Auto-Compute the Screen Transfer From the Image" )
                        .disabled( self.isDerivingAuto || self.canAutoScreenTransfer() == false )

                        Button
                        {
                            self.openWindow( id: Self.screenTransferWindowID )
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
        // A change the control makes: push it to the shared adjustments and
        // re-render.
        .onChange( of: self.stretchParameters )
        {
            self.adjustments.stretch = self.stretchParameters

            self.reRender()
        }
        // A change from outside the control (e.g. a menu Reset View): pull it
        // back into the control's displayed state.
        .onChange( of: self.adjustments.stretch )
        {
            self.syncFromAdjustments()
        }
    }

    /// The applied stretch derived from the current mode.
    private var stretchParameters: Processors.Stretch.STFParameters?
    {
        Self.stretch( mode: self.mode, screenTransfer: self.screenTransfer )
    }

    /// Derives an auto-STF from the current image (off the main actor) and applies
    /// it as the screen transfer, switching the control into screen-transfer mode.
    /// Does nothing when no derivation is available (no image or no detection
    /// buffer). The parameter change flows through ``stretchParameters`` to the
    /// shared adjustments and a re-render.
    @MainActor
    private func applyAutoScreenTransfer() async
    {
        self.isDerivingAuto = true

        let parameters = await self.autoScreenTransfer()

        self.isDerivingAuto = false

        guard let parameters
        else
        {
            return
        }

        self.mode           = .screenTransfer
        self.screenTransfer = parameters
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

#Preview
{
    StretchControlView( adjustments: ImageAdjustments(), reRender: {} )
        .frame( maxWidth: .infinity, alignment: .leading )
        .frame( maxHeight: .infinity, alignment: .top )
        .padding()
}
