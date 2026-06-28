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

@testable import FITScope
import Foundation
import Testing

/// Tests for ``WeightFormula``: the parser, validator and evaluator behind the
/// user-configurable image-weight formula.
@Suite( "WeightFormula" )
struct WeightFormulaTests
{
    // MARK: - Vocabulary

    /// Every placeholder the milestone defines is a known variable, and no
    /// others — guarding the vocabulary the Preferences help text advertises.
    @Test
    func recognizesExactlyTheDefinedPlaceholders()
    {
        let expected: Set< String > =
            [
                "FWHM", "FWHMMin", "FWHMMax",
                "HFR", "HFRMin", "HFRMax",
                "Eccentricity", "EccentricityMin", "EccentricityMax",
                "SNRWeight", "SNRWeightMin", "SNRWeightMax",
                "Stars",
            ]

        #expect( Set( WeightFormula.Variable.allCases.map { $0.rawValue } ) == expected )
    }

    /// Every placeholder has a non-empty tooltip describing what it is.
    @Test
    func everyPlaceholderHasATooltip()
    {
        #expect( WeightFormula.Variable.allCases.allSatisfy { $0.tooltip.isEmpty == false } )
    }

    /// Placeholder names match regardless of case, so `fwhm` and `FWHM` are the
    /// same variable.
    @Test
    func matchesPlaceholderNamesCaseInsensitively() throws
    {
        let formula = try WeightFormula( source: "fwhm + Hfr" )

        #expect( Self.isClose( formula.evaluate( [ .fwhm: 1, .hfr: 2 ] ), 3 ) )
    }

    // MARK: - Evaluation

    /// `*` and `/` bind tighter than `+` and `-`, and parentheses override that.
    @Test
    func evaluatesArithmeticWithCorrectPrecedence() throws
    {
        #expect( Self.isClose( try WeightFormula( source: "2 + 3 * 4" ).evaluate( [ : ] ), 14 ) )
        #expect( Self.isClose( try WeightFormula( source: "(2 + 3) * 4" ).evaluate( [ : ] ), 20 ) )
        #expect( Self.isClose( try WeightFormula( source: "10 - 4 - 3" ).evaluate( [ : ] ), 3 ) )
        #expect( Self.isClose( try WeightFormula( source: "20 / 4 / 5" ).evaluate( [ : ] ), 1 ) )
    }

    /// `^` binds tighter than `*`, is right-associative, and sits below unary
    /// minus so `-2 ^ 2` is `-(2 ^ 2)`.
    @Test
    func evaluatesPower() throws
    {
        #expect( Self.isClose( try WeightFormula( source: "2 ^ 3" ).evaluate( [ : ] ), 8 ) )
        #expect( Self.isClose( try WeightFormula( source: "2 ^ 3 ^ 2" ).evaluate( [ : ] ), 512 ) )
        #expect( Self.isClose( try WeightFormula( source: "-2 ^ 2" ).evaluate( [ : ] ), -4 ) )
        #expect( Self.isClose( try WeightFormula( source: "2 ^ -1" ).evaluate( [ : ] ), 0.5 ) )
    }

    /// A leading or embedded unary minus negates its operand.
    @Test
    func evaluatesUnaryMinus() throws
    {
        #expect( Self.isClose( try WeightFormula( source: "-5 + 2" ).evaluate( [ : ] ), -3 ) )
        #expect( Self.isClose( try WeightFormula( source: "3 * -2" ).evaluate( [ : ] ), -6 ) )
    }

    /// A variable absent from the supplied values evaluates to zero rather than
    /// trapping — the evaluator never crashes on missing data.
    @Test
    func aMissingVariableEvaluatesToZero() throws
    {
        #expect( Self.isClose( try WeightFormula( source: "Stars + 5" ).evaluate( [ : ] ), 5 ) )
    }

    /// The PixInsight-style default formula, with every metric at the midpoint of
    /// its set range, yields the mid-scale weight of 75 (each normalized term is
    /// 0.5 → 7.5 + 7.5 + 10 + 50).
    @Test
    func evaluatesTheDefaultFormulaAtMidpoints() throws
    {
        let formula = try WeightFormula( source: WeightFormula.defaultExpression )

        let values: [ WeightFormula.Variable: Double ] =
            [
                .fwhm: 2, .fwhmMin: 1, .fwhmMax: 3,
                .eccentricity: 0.5, .eccentricityMin: 0, .eccentricityMax: 1,
                .snrWeight: 5, .snrWeightMin: 0, .snrWeightMax: 10,
            ]

        #expect( Self.isClose( formula.evaluate( values ), 75 ) )
    }

    /// The default expression is itself a valid formula.
    @Test
    func theDefaultExpressionParses() throws
    {
        #expect( throws: Never.self ) { try WeightFormula( source: WeightFormula.defaultExpression ) }
    }

    // MARK: - Validation

    /// An empty or whitespace-only formula is rejected.
    @Test
    func rejectsAnEmptyFormula()
    {
        #expect( throws: WeightFormula.Error.self ) { try WeightFormula( source: "" ) }
        #expect( throws: WeightFormula.Error.self ) { try WeightFormula( source: "   \n  " ) }
    }

    /// An unknown identifier names the offending token so the UI can report it.
    @Test
    func rejectsAnUnknownIdentifier()
    {
        #expect( throws: WeightFormula.Error.unknownIdentifier( "FOO" ) ) { try WeightFormula( source: "FOO + 1" ) }
    }

    /// Unbalanced parentheses, in either direction, are rejected.
    @Test
    func rejectsUnbalancedParentheses()
    {
        #expect( throws: WeightFormula.Error.self ) { try WeightFormula( source: "(1 + 2" ) }
        #expect( throws: WeightFormula.Error.self ) { try WeightFormula( source: "1 + 2)" ) }
    }

    /// A dangling or leading operator is rejected.
    @Test
    func rejectsADanglingOperator()
    {
        #expect( throws: WeightFormula.Error.self ) { try WeightFormula( source: "1 +" ) }
        #expect( throws: WeightFormula.Error.self ) { try WeightFormula( source: "* 2" ) }
    }

    /// A character outside the grammar is rejected.
    @Test
    func rejectsAnUnexpectedCharacter()
    {
        #expect( throws: WeightFormula.Error.self ) { try WeightFormula( source: "1 & 2" ) }
    }

    /// Division by zero follows IEEE arithmetic — infinity, not a crash — so a
    /// degenerate set range never traps the app.
    @Test
    func divisionByZeroDoesNotCrash() throws
    {
        #expect( try WeightFormula( source: "1 / 0" ).evaluate( [ : ] ).isInfinite )
        #expect( try WeightFormula( source: "0 / 0" ).evaluate( [ : ] ).isNaN )
    }

    // MARK: - Keyword ranges (for editor highlighting)

    /// Valid keywords are located by range, and non-keyword identifiers are
    /// ignored — even in an otherwise incomplete formula, so the editor can
    /// highlight as the user types.
    @Test
    func findsRangesOfValidKeywords()
    {
        let ranges = WeightFormula.validKeywordRanges( in: "FWHM + foo * HFRMin" )

        #expect( ranges == [ NSRange( location: 0, length: 4 ), NSRange( location: 13, length: 6 ) ] )
    }

    /// Matching is case-insensitive and spans the whole identifier, so a partial
    /// or differently-cased name is handled correctly.
    @Test
    func keywordRangesAreCaseInsensitiveWholeIdentifiers()
    {
        #expect( WeightFormula.validKeywordRanges( in: "fwhm" ) == [ NSRange( location: 0, length: 4 ) ] )
        #expect( WeightFormula.validKeywordRanges( in: "FWHMMin" ) == [ NSRange( location: 0, length: 7 ) ] )
        #expect( WeightFormula.validKeywordRanges( in: "FWHMX" ).isEmpty )
    }

    /// A differently-cased keyword reports its canonical name, so the editor can
    /// correct the case as the user types.
    @Test
    func keywordMatchesReportTheCanonicalName()
    {
        let matches = WeightFormula.keywordMatches( in: "fwhm + snrweightmax" )

        #expect( matches.map { $0.name } == [ "FWHM", "SNRWeightMax" ] )
    }

    // MARK: - Referenced variables

    /// A formula reports exactly the variables it mentions, and nothing else.
    @Test
    func referencedVariablesListsOnlyUsedVariables() throws
    {
        let formula = try WeightFormula( source: "FWHM + 2 * SNRWeightMax" )

        #expect( formula.referencedVariables == [ .fwhm, .snrWeightMax ] )
    }

    /// Literal-only formulas reference no variables.
    @Test
    func referencedVariablesIsEmptyForLiteralFormula() throws
    {
        let formula = try WeightFormula( source: "1 + 2 * 3" )

        #expect( formula.referencedVariables.isEmpty )
    }

    /// A repeated variable is reported once.
    @Test
    func referencedVariablesDeduplicates() throws
    {
        let formula = try WeightFormula( source: "FWHM + FWHM * FWHM" )

        #expect( formula.referencedVariables == [ .fwhm ] )
    }

    /// The default formula references the FWHM, eccentricity and SNR-weight
    /// families (each with its set-wide min/max), but neither HFR nor Stars.
    @Test
    func referencedVariablesOfDefaultFormula() throws
    {
        let formula  = try WeightFormula( source: WeightFormula.defaultExpression )
        let expected: Set< WeightFormula.Variable > =
            [
                .fwhm, .fwhmMin, .fwhmMax,
                .eccentricity, .eccentricityMin, .eccentricityMax,
                .snrWeight, .snrWeightMin, .snrWeightMax,
            ]

        #expect( formula.referencedVariables == expected )
    }

    // MARK: - Helpers

    /// Whether two values are within a tight tolerance, for floating-point
    /// expectations.
    private static func isClose( _ a: Double, _ b: Double ) -> Bool
    {
        abs( a - b ) < 1e-9
    }
}
