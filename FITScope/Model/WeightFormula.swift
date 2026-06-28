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

import Foundation

/// A parsed, validated image-weight formula.
///
/// The formula is a small arithmetic expression over the star-metric
/// placeholders in ``Variable`` — `+`, `-`, `*`, `/`, `^` (power), unary minus,
/// parentheses and numeric literals — used to rank images by quality. Parsing
/// happens once, in ``init(source:)``, which throws a descriptive ``Error`` on
/// invalid input so the Preferences editor can validate live; ``evaluate(_:)``
/// then computes a weight from a set of metric values.
///
/// Names are matched case-insensitively. Evaluation follows IEEE arithmetic —
/// division by zero yields infinity or NaN rather than trapping — so a
/// degenerate input never crashes the app; callers decide how to treat a
/// non-finite result.
public struct WeightFormula
{
    /// A metric a formula can reference.
    ///
    /// The bare metrics (`FWHM`, `HFR`, `Eccentricity`, `SNRWeight`) are an
    /// image's own values; the `…Min` / `…Max` variants are the minimum and
    /// maximum of that metric across the whole loaded set, so a formula can rank
    /// each image relative to the others. `Stars` is the detected star count.
    public enum Variable: String, CaseIterable, Sendable
    {
        /// This image's FWHM.
        case fwhm = "FWHM"

        /// The minimum FWHM across the set.
        case fwhmMin = "FWHMMin"

        /// The maximum FWHM across the set.
        case fwhmMax = "FWHMMax"

        /// This image's HFR.
        case hfr = "HFR"

        /// The minimum HFR across the set.
        case hfrMin = "HFRMin"

        /// The maximum HFR across the set.
        case hfrMax = "HFRMax"

        /// This image's eccentricity.
        case eccentricity = "Eccentricity"

        /// The minimum eccentricity across the set.
        case eccentricityMin = "EccentricityMin"

        /// The maximum eccentricity across the set.
        case eccentricityMax = "EccentricityMax"

        /// This image's SNR weight.
        case snrWeight = "SNRWeight"

        /// The minimum SNR weight across the set.
        case snrWeightMin = "SNRWeightMin"

        /// The maximum SNR weight across the set.
        case snrWeightMax = "SNRWeightMax"

        /// The detected star count.
        case stars = "Stars"

        /// The variable whose name matches `name`, case-insensitively, or `nil`.
        ///
        /// - Parameter name: The identifier text from the formula.
        static func named( _ name: String ) -> Variable?
        {
            self.allCases.first { $0.rawValue.caseInsensitiveCompare( name ) == .orderedSame }
        }

        /// A short description of what the placeholder represents, for the
        /// editor's keyword tooltips.
        public var tooltip: String
        {
            switch self
            {
                case .fwhm:            return "Median star FWHM, in pixels, for this image."
                case .fwhmMin:         return "Smallest image FWHM across all open images."
                case .fwhmMax:         return "Largest image FWHM across all open images."
                case .hfr:             return "Median star half-flux radius, in pixels, for this image."
                case .hfrMin:          return "Smallest image HFR across all open images."
                case .hfrMax:          return "Largest image HFR across all open images."
                case .eccentricity:    return "Median star eccentricity (0 = round) for this image."
                case .eccentricityMin: return "Smallest image eccentricity across all open images."
                case .eccentricityMax: return "Largest image eccentricity across all open images."
                case .snrWeight:       return "Signal-to-noise weight for this image."
                case .snrWeightMin:    return "Smallest image SNR weight across all open images."
                case .snrWeightMax:    return "Largest image SNR weight across all open images."
                case .stars:           return "Number of stars detected in this image."
            }
        }
    }

    /// A reason a formula failed to parse.
    public enum Error: Swift.Error, Equatable, LocalizedError, CustomStringConvertible
    {
        /// The formula was empty or whitespace only.
        case emptyExpression

        /// A character outside the grammar was found.
        case unexpectedCharacter( Character )

        /// An identifier did not name a known ``Variable``.
        case unknownIdentifier( String )

        /// An operand was expected but missing (e.g. a dangling operator).
        case expectedExpression

        /// Parentheses did not balance.
        case unbalancedParentheses

        /// Tokens remained after an otherwise complete expression.
        case trailingTokens

        /// A human-readable description of the failure.
        public var description: String
        {
            switch self
            {
                case .emptyExpression:             return "The formula is empty."
                case .unexpectedCharacter( let c ): return "Unexpected character “\( c )”."
                case .unknownIdentifier( let name ): return "Unknown variable “\( name )”."
                case .expectedExpression:          return "Expected a value or expression."
                case .unbalancedParentheses:       return "Unbalanced parentheses."
                case .trailingTokens:              return "Unexpected text after the formula."
            }
        }

        /// The localized description, mirroring ``description``.
        public var errorDescription: String? { self.description }
    }

    /// One node of the parsed expression tree.
    private indirect enum Node
    {
        /// A numeric literal.
        case number( Double )

        /// A variable reference.
        case variable( Variable )

        /// Arithmetic negation of an operand.
        case negate( Node )

        /// A binary operation over two operands.
        case binary( Operator, Node, Node )
    }

    /// A binary arithmetic operator.
    private enum Operator
    {
        /// Addition.
        case add

        /// Subtraction.
        case subtract

        /// Multiplication.
        case multiply

        /// Division.
        case divide

        /// Exponentiation.
        case power
    }

    /// The PixInsight SubframeSelector-style default weighting expression: a
    /// min/max-normalized blend of FWHM (15 %), eccentricity (15 %) and SNR
    /// weight (20 %), inverted where lower is better, over a base of 50.
    public static let defaultExpression =
        """
        ( 15 * ( 1 - ( FWHM - FWHMMin ) / ( FWHMMax - FWHMMin ) )
        + 15 * ( 1 - ( Eccentricity - EccentricityMin ) / ( EccentricityMax - EccentricityMin ) )
        + 20 * ( SNRWeight - SNRWeightMin ) / ( SNRWeightMax - SNRWeightMin ) )
        + 50
        """

    /// The formula's source text, as entered.
    public let source: String

    /// The parsed expression tree.
    private let root: Node

    /// Parses and validates a formula.
    ///
    /// - Parameter source: The formula text.
    /// - Throws: An ``Error`` describing the first problem found.
    public init( source: String ) throws
    {
        let tokens = try Self.tokenize( source )

        guard tokens.isEmpty == false
        else
        {
            throw Error.emptyExpression
        }

        var parser   = Parser( tokens: tokens )
        let root     = try parser.parseExpression()

        guard parser.isAtEnd
        else
        {
            // A leftover ")" is an unbalanced paren; anything else is trailing.
            throw parser.peek() == .rightParenthesis ? Error.unbalancedParentheses : Error.trailingTokens
        }

        self.source = source
        self.root   = root
    }

    /// Evaluates the formula against a set of metric values.
    ///
    /// A variable absent from `values` evaluates to zero, so a partially-measured
    /// image still yields a number rather than trapping.
    ///
    /// - Parameter values: The value for each referenced variable.
    /// - Returns: The computed weight (possibly non-finite on a degenerate input).
    public func evaluate( _ values: [ Variable: Double ] ) -> Double
    {
        Self.evaluate( self.root, values )
    }

    // MARK: - Editor support

    /// Every valid placeholder occurrence in `text`, as its range paired with the
    /// matched variable's canonical name.
    ///
    /// Scans identifier runs and keeps those that name a ``Variable``
    /// (case-insensitively), ignoring unknown identifiers. Unlike
    /// ``init(source:)`` it never throws and tolerates an incomplete formula, so
    /// the Preferences editor can highlight recognized keywords as pills — and
    /// correct their case to the canonical form — while the user types.
    ///
    /// - Parameter text: The formula text to scan.
    /// - Returns: Each recognized keyword's range and canonical name, in order.
    public static func keywordMatches( in text: String ) -> [ ( range: NSRange, name: String ) ]
    {
        guard let regex = try? NSRegularExpression( pattern: "[A-Za-z][A-Za-z0-9]*" )
        else
        {
            return []
        }

        let whole = NSRange( location: 0, length: ( text as NSString ).length )

        return regex.matches( in: text, range: whole ).compactMap
        {
            match in

            guard let range = Range( match.range, in: text ), let variable = Variable.named( String( text[ range ] ) )
            else
            {
                return nil
            }

            return ( match.range, variable.rawValue )
        }
    }

    /// The ranges of every valid placeholder name in `text`.
    ///
    /// - Parameter text: The formula text to scan.
    /// - Returns: The `NSRange` of each recognized keyword, in source order.
    public static func validKeywordRanges( in text: String ) -> [ NSRange ]
    {
        self.keywordMatches( in: text ).map { $0.range }
    }

    // MARK: - Evaluation

    /// Recursively evaluates a node.
    ///
    /// - Parameters:
    ///   - node:   The node to evaluate.
    ///   - values: The variable values.
    /// - Returns: The node's value.
    private static func evaluate( _ node: Node, _ values: [ Variable: Double ] ) -> Double
    {
        switch node
        {
            case .number( let value ):

                return value

            case .variable( let variable ):

                return values[ variable ] ?? 0

            case .negate( let operand ):

                return -self.evaluate( operand, values )

            case .binary( let op, let lhs, let rhs ):

                let left  = self.evaluate( lhs, values )
                let right = self.evaluate( rhs, values )

                switch op
                {
                    case .add:      return left + right
                    case .subtract: return left - right
                    case .multiply: return left * right
                    case .divide:   return left / right
                    case .power:    return pow( left, right )
                }
        }
    }

    // MARK: - Tokenizing

    /// A lexical token of a formula.
    private enum Token: Equatable
    {
        /// A numeric literal.
        case number( Double )

        /// A resolved variable reference.
        case variable( Variable )

        /// `+`.
        case plus

        /// `-`.
        case minus

        /// `*`.
        case star

        /// `/`.
        case slash

        /// `^`.
        case caret

        /// `(`.
        case leftParenthesis

        /// `)`.
        case rightParenthesis
    }

    /// Splits the source into tokens, resolving identifiers to variables.
    ///
    /// - Parameter source: The formula text.
    /// - Throws: ``Error/unexpectedCharacter(_:)`` or
    ///   ``Error/unknownIdentifier(_:)``.
    /// - Returns: The tokens, in order.
    private static func tokenize( _ source: String ) throws -> [ Token ]
    {
        let characters = Array( source )
        var index      = 0
        var tokens     = [ Token ]()

        while index < characters.count
        {
            let character = characters[ index ]

            if character.isWhitespace
            {
                index += 1
            }
            else if let single = Self.singleCharacterToken( character )
            {
                tokens.append( single )
                index += 1
            }
            else if character.isNumber || character == "."
            {
                tokens.append( try Self.scanNumber( characters, &index ) )
            }
            else if character.isLetter
            {
                tokens.append( try Self.scanIdentifier( characters, &index ) )
            }
            else
            {
                throw Error.unexpectedCharacter( character )
            }
        }

        return tokens
    }

    /// The token for a single-character operator or parenthesis, or `nil`.
    ///
    /// - Parameter character: The character to map.
    private static func singleCharacterToken( _ character: Character ) -> Token?
    {
        switch character
        {
            case "+": return .plus
            case "-": return .minus
            case "*": return .star
            case "/": return .slash
            case "^": return .caret
            case "(": return .leftParenthesis
            case ")": return .rightParenthesis
            default:  return nil
        }
    }

    /// Scans a numeric literal — digits with at most one decimal point —
    /// advancing `index` past it.
    ///
    /// - Parameters:
    ///   - characters: The source characters.
    ///   - index:      The current position, advanced past the number.
    /// - Throws: ``Error/unexpectedCharacter(_:)`` if the run is not a number.
    /// - Returns: A ``Token/number(_:)``.
    private static func scanNumber( _ characters: [ Character ], _ index: inout Int ) throws -> Token
    {
        let start  = index
        var hasDot = false

        while index < characters.count, characters[ index ].isNumber || ( characters[ index ] == "." && hasDot == false )
        {
            hasDot = hasDot || characters[ index ] == "."
            index += 1
        }

        let text = String( characters[ start ..< index ] )

        guard let value = Double( text )
        else
        {
            throw Error.unexpectedCharacter( characters[ start ] )
        }

        return .number( value )
    }

    /// Scans an identifier and resolves it to a variable, advancing `index` past
    /// it.
    ///
    /// - Parameters:
    ///   - characters: The source characters.
    ///   - index:      The current position, advanced past the identifier.
    /// - Throws: ``Error/unknownIdentifier(_:)`` for an unknown name.
    /// - Returns: A ``Token/variable(_:)``.
    private static func scanIdentifier( _ characters: [ Character ], _ index: inout Int ) throws -> Token
    {
        let start = index

        while index < characters.count, characters[ index ].isLetter || characters[ index ].isNumber
        {
            index += 1
        }

        let name = String( characters[ start ..< index ] )

        guard let variable = Variable.named( name )
        else
        {
            throw Error.unknownIdentifier( name )
        }

        return .variable( variable )
    }

    // MARK: - Parsing

    /// A recursive-descent parser over a token stream.
    ///
    /// Precedence, lowest to highest: `+` `-`, then `*` `/`, then unary `-`, then
    /// `^` (right-associative). The grammar is small enough that the mutable
    /// cursor is clearer than a functional reduction.
    private struct Parser
    {
        /// The tokens to parse.
        private let tokens: [ Token ]

        /// The cursor into ``tokens``.
        private var index = 0

        /// Creates a parser.
        ///
        /// - Parameter tokens: The tokens to parse.
        init( tokens: [ Token ] )
        {
            self.tokens = tokens
        }

        /// Whether every token has been consumed.
        var isAtEnd: Bool { self.index >= self.tokens.count }

        /// The current token without consuming it, or `nil` at the end.
        func peek() -> Token?
        {
            self.isAtEnd ? nil : self.tokens[ self.index ]
        }

        /// Consumes and returns the current token.
        private mutating func advance() -> Token
        {
            let token  = self.tokens[ self.index ]
            self.index += 1

            return token
        }

        /// Parses an additive expression: `term (('+' | '-') term)*`.
        ///
        /// - Throws: A parse ``Error``.
        /// - Returns: The parsed node.
        mutating func parseExpression() throws -> Node
        {
            var node = try self.parseTerm()

            while let token = self.peek(), token == .plus || token == .minus
            {
                _ = self.advance()

                let right = try self.parseTerm()
                node      = .binary( token == .plus ? .add : .subtract, node, right )
            }

            return node
        }

        /// Parses a multiplicative expression: `unary (('*' | '/') unary)*`.
        ///
        /// - Throws: A parse ``Error``.
        /// - Returns: The parsed node.
        private mutating func parseTerm() throws -> Node
        {
            var node = try self.parseUnary()

            while let token = self.peek(), token == .star || token == .slash
            {
                _ = self.advance()

                let right = try self.parseUnary()
                node      = .binary( token == .star ? .multiply : .divide, node, right )
            }

            return node
        }

        /// Parses a unary minus or falls through to a power: `'-' unary | power`.
        ///
        /// - Throws: A parse ``Error``.
        /// - Returns: The parsed node.
        private mutating func parseUnary() throws -> Node
        {
            if self.peek() == .minus
            {
                _ = self.advance()

                return .negate( try self.parseUnary() )
            }

            return try self.parsePower()
        }

        /// Parses a (right-associative) power: `primary ('^' unary)?`.
        ///
        /// The exponent is a `unary`, so `2 ^ -1` and `2 ^ 3 ^ 2` parse as
        /// expected.
        ///
        /// - Throws: A parse ``Error``.
        /// - Returns: The parsed node.
        private mutating func parsePower() throws -> Node
        {
            let base = try self.parsePrimary()

            guard self.peek() == .caret
            else
            {
                return base
            }

            _ = self.advance()

            return .binary( .power, base, try self.parseUnary() )
        }

        /// Parses a primary: a number, a variable, or a parenthesized expression.
        ///
        /// - Throws: ``Error/expectedExpression`` or
        ///   ``Error/unbalancedParentheses``.
        /// - Returns: The parsed node.
        private mutating func parsePrimary() throws -> Node
        {
            guard self.isAtEnd == false
            else
            {
                throw Error.expectedExpression
            }

            switch self.advance()
            {
                case .number( let value ):

                    return .number( value )

                case .variable( let variable ):

                    return .variable( variable )

                case .leftParenthesis:

                    let node = try self.parseExpression()

                    guard self.peek() == .rightParenthesis
                    else
                    {
                        throw Error.unbalancedParentheses
                    }

                    _ = self.advance()

                    return node

                default:

                    throw Error.expectedExpression
            }
        }
    }
}
