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

/// The Weighting tab of the Preferences window: the user-configurable
/// image-weight formula, with live validation against ``WeightFormula``.
public struct WeightingPreferencesView: View
{
    /// The shared, persisted preferences.
    @ObservedObject private var preferences: Preferences

    /// Bridges the keyword palette to the formula editor so a pill click inserts
    /// at the caret.
    @StateObject private var editor = FormulaEditorController()

    /// Creates the Weighting tab.
    ///
    /// - Parameter preferences: The shared, persisted preferences store. Passed
    ///   in explicitly rather than read from the environment, because a `Settings`
    ///   scene's `TabView` does not reliably propagate environment objects across
    ///   the tab boundary.
    public init( preferences: Preferences )
    {
        self._preferences = ObservedObject( wrappedValue: preferences )
    }

    /// The view's content.
    public var body: some View
    {
        Form
        {
            Section( "Weight Formula" )
            {
                // Editor, its description, a separator and the validation/reset
                // line share one row, so no grouped-row separators bracket them.
                VStack( alignment: .leading, spacing: 8 )
                {
                    FormulaTextView( text: self.$preferences.weightFormula, controller: self.editor )
                        .frame( height: 110 )
                        .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.weightFormulaEditor )

                    Text( "Rank images by quality with a formula over the detected star metrics. Lower FWHM, HFR and eccentricity are better; a higher SNR weight is better. The Min/Max placeholders are the smallest and largest values across all open images, so the formula scores each image relative to the set." )
                        .font( .caption )
                        .foregroundStyle( .secondary )
                        .fixedSize( horizontal: false, vertical: true )

                    Divider()

                    HStack( spacing: 8 )
                    {
                        self.validationLabel

                        Spacer()

                        Button( "Restore Default" )
                        {
                            self.preferences.resetWeightFormula()
                        }
                        .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.weightFormulaResetButton )
                    }
                }
            }

            Section( "Available Placeholders" )
            {
                Grid( alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6 )
                {
                    ForEach( Array( Self.placeholderGroups.enumerated() ), id: \.offset )
                    {
                        _, group in

                        GridRow
                        {
                            Text( "\( group.label ):" )
                                .font( .caption )
                                .foregroundStyle( .secondary )
                                .gridColumnAlignment( .leading )

                            ForEach( group.variables, id: \.self )
                            {
                                variable in

                                KeywordPill( variable.rawValue, tooltip: variable.tooltip )
                                {
                                    self.editor.insert( variable.rawValue )
                                }
                            }
                        }
                    }
                }
                .padding( .vertical, 2 )

                VStack( alignment: .leading, spacing: 3 )
                {
                    Text( "Click a placeholder to insert it at the cursor." )
                    Text( "Operators: + − × ÷ ^ (power), and parentheses." )
                    Text( "Names are case-insensitive." )
                }
                .font( .caption )
                .foregroundStyle( .secondary )
            }
        }
        .formStyle( .grouped )
        .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.weightingTab )
    }

    /// The placeholders grouped one metric family per row — a leading label, then
    /// each metric's base, minimum and maximum aligned in columns — with the lone
    /// star count under "Others".
    private static let placeholderGroups: [ ( label: String, variables: [ WeightFormula.Variable ] ) ] =
        [
            ( "Full width at half maximum", [ .fwhm,         .fwhmMin,         .fwhmMax ] ),
            ( "Half-flux radius",           [ .hfr,          .hfrMin,          .hfrMax ] ),
            ( "Eccentricity",               [ .eccentricity, .eccentricityMin, .eccentricityMax ] ),
            ( "Signal-to-noise weight",     [ .snrWeight,    .snrWeightMin,    .snrWeightMax ] ),
            ( "Others",           [ .stars ] ),
        ]

    /// The live validation result, or `nil` when the formula parses.
    private var validationError: WeightFormula.Error?
    {
        do
        {
            _ = try WeightFormula( source: self.preferences.weightFormula )

            return nil
        }
        catch let error as WeightFormula.Error
        {
            return error
        }
        catch
        {
            return nil
        }
    }

    /// A green "valid" confirmation, or the red parse error.
    @ViewBuilder     private var validationLabel: some View
    {
        if let error = self.validationError
        {
            Label( error.description, systemImage: "exclamationmark.triangle.fill" )
                .font( .caption )
                .foregroundStyle( .red )
                .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.weightFormulaValidationMessage )
        }
        else
        {
            Label( "The formula is valid.", systemImage: "checkmark.circle.fill" )
                .font( .caption )
                .foregroundStyle( .green )
                .accessibilityIdentifier( AccessibilityIdentifier.PreferencesView.weightFormulaValidationMessage )
        }
    }
}

#Preview
{
    WeightingPreferencesView( preferences: Preferences() )
        .frame( width: 560, height: 560 )
}
