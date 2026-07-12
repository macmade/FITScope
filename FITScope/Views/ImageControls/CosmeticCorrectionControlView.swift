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

/// The cosmetic-correction section of the controls panel: a single mode picker
/// choosing which defective pixels to repair.
///
/// It follows the compact Debayer pattern — a `Mode` picker in a one-row grid —
/// binding directly to ``ImageAdjustments/cosmeticCorrection`` and re-rendering on
/// any change (there is no auto-stretch cross-dependency as there is for white
/// balance). The picker folds the enable and hot/cold choices into a single menu;
/// the detection strength is left at the model's conservative default, since
/// tuning it is not meaningful for a viewer/inspection tool (real cosmetic
/// correction happens at calibration time). The pure mapping between the
/// parameters and the picker lives in ``mode(for:)`` / ``parameters(for:applyingTo:)``
/// so it can be unit-tested without SwiftUI.
public struct CosmeticCorrectionControlView: View
{
    /// The defect-repair choices offered by the picker.
    public enum Mode: CaseIterable, CustomStringConvertible
    {
        /// Do not repair any defects.
        case off

        /// Repair both hot (bright) and cold (dark) defects.
        case hotAndCold

        /// Repair only hot (bright) defects.
        case hotOnly

        /// Repair only cold (dark) defects.
        case coldOnly

        /// The picker label for the mode.
        public var description: String
        {
            switch self
            {
                case .off:        return "Off"
                case .hotAndCold: return "Hot & Cold"
                case .hotOnly:    return "Hot Only"
                case .coldOnly:   return "Cold Only"
            }
        }
    }

    /// The shared adjustment values this control observes and writes to.
    @ObservedObject private var adjustments: ImageAdjustments

    /// Requests a debounced re-render after a change.
    private let reRender: () -> Void

    /// Creates the cosmetic-correction control.
    ///
    /// - Parameters:
    ///   - adjustments: The shared adjustment values to observe and write to.
    ///   - reRender:    The closure to call after a change.
    public init( adjustments: ImageAdjustments, reRender: @escaping () -> Void )
    {
        self.adjustments = adjustments
        self.reRender    = reRender
    }

    // MARK: - Pure model ↔ UI mapping (unit-testable)

    /// Maps the current parameters to the picker's mode: disabled — or enabled with
    /// neither correction — reads as ``Mode/off``.
    ///
    /// - Parameter parameters: The current cosmetic-correction parameters.
    /// - Returns: The mode the picker should show.
    static func mode( for parameters: Processors.CosmeticCorrection.Parameters ) -> Mode
    {
        guard parameters.isEnabled
        else
        {
            return .off
        }

        switch ( parameters.correctHot, parameters.correctCold )
        {
            case ( true,  true  ): return .hotAndCold
            case ( true,  false ): return .hotOnly
            case ( false, true  ): return .coldOnly
            case ( false, false ): return .off
        }
    }

    /// Applies a picked mode to the existing parameters, changing only the enable
    /// and hot/cold flags and preserving the thresholds.
    ///
    /// - Parameters:
    ///   - mode:       The picked mode.
    ///   - parameters: The parameters to update.
    /// - Returns: The updated parameters.
    static func parameters( for mode: Mode, applyingTo parameters: Processors.CosmeticCorrection.Parameters ) -> Processors.CosmeticCorrection.Parameters
    {
        var result = parameters

        switch mode
        {
            case .off:

                result.isEnabled = false

            case .hotAndCold:

                result.isEnabled   = true
                result.correctHot  = true
                result.correctCold = true

            case .hotOnly:

                result.isEnabled   = true
                result.correctHot  = true
                result.correctCold = false

            case .coldOnly:

                result.isEnabled   = true
                result.correctHot  = false
                result.correctCold = true
        }

        return result
    }

    // MARK: - View

    /// The picker's selected mode, derived from the observed adjustments so it
    /// always reflects the current state — including an external Reset.
    private var mode: Mode
    {
        Self.mode( for: self.adjustments.cosmeticCorrection )
    }

    /// The view's content.
    public var body: some View
    {
        Grid( alignment: .leading )
        {
            GridRow
            {
                Text( "Mode" )
                Picker( "Mode", selection: self.modeBinding )
                {
                    ForEach( Mode.allCases, id: \.self )
                    {
                        Text( $0.description ).tag( $0 )
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier( AccessibilityIdentifier.CosmeticCorrectionControlView.modePicker )
                .help( "Choose Which Defective Pixels to Repair" )
            }
        }
        // The picker writes back into the observed `cosmeticCorrection` value, so a
        // single change observer re-renders — from this control or a Reset.
        .onChange( of: self.adjustments.cosmeticCorrection )
        {
            self.reRender()
        }
    }

    /// A binding for the mode picker, reading the derived ``mode`` and writing the
    /// matching parameters back to the adjustments.
    private var modeBinding: Binding< Mode >
    {
        Binding(
            get: { self.mode },
            set: { self.adjustments.cosmeticCorrection = Self.parameters( for: $0, applyingTo: self.adjustments.cosmeticCorrection ) }
        )
    }
}

#Preview
{
    CosmeticCorrectionControlView( adjustments: ImageAdjustments(), reRender: {} )
        .frame( maxWidth: .infinity, alignment: .leading )
        .frame( maxHeight: .infinity, alignment: .top )
        .padding()
}
