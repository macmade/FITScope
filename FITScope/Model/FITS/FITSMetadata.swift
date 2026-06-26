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
import SwiftFITS

/// Typed, unit-aware accessors for the astrometry-relevant header fields of a
/// FITS image — world-coordinate-system (WCS) keywords, pointing, observation
/// time, observing site and plate scale.
///
/// Built from typed ``FITSPropertySnapshot`` values rather than the display
/// strings of ``FITSImageInfo`` so that high-precision values (e.g. a WCS
/// reference coordinate written with eleven significant figures) survive intact
/// — display formatting would round them to six.
public struct FITSMetadata: Sendable
{
    /// The header values, keyed by upper-cased keyword name. The first
    /// occurrence of a repeated keyword wins.
    private let values: [ String: FITSValue ]

    /// Creates the accessor from a flat list of typed header properties, e.g.
    /// every section's properties of a parsed file.
    ///
    /// - Parameter properties: The header property snapshots to read.
    public init( properties: [ FITSPropertySnapshot ] )
    {
        var values: [ String: FITSValue ] = [:]

        for property in properties
        {
            let key = property.name.uppercased()

            if values[ key ] == nil
            {
                values[ key ] = property.value
            }
        }

        self.values = values
    }

    // MARK: - Raw WCS keywords

    /// The reference value of axis 1 (`CRVAL1`), in the units of `CTYPE1`
    /// (degrees for a celestial axis).
    public var crval1: Double? { self.double( "CRVAL1" ) }

    /// The reference value of axis 2 (`CRVAL2`).
    public var crval2: Double? { self.double( "CRVAL2" ) }

    /// The reference pixel of axis 1 (`CRPIX1`), 1-based per the FITS convention.
    public var crpix1: Double? { self.double( "CRPIX1" ) }

    /// The reference pixel of axis 2 (`CRPIX2`).
    public var crpix2: Double? { self.double( "CRPIX2" ) }

    /// The coordinate increment per pixel along axis 1 (`CDELT1`), in degrees.
    public var cdelt1: Double? { self.double( "CDELT1" ) }

    /// The coordinate increment per pixel along axis 2 (`CDELT2`), in degrees.
    public var cdelt2: Double? { self.double( "CDELT2" ) }

    /// The rotation of axis 2 (`CROTA2`), in degrees.
    public var crota2: Double? { self.double( "CROTA2" ) }

    /// The `CD1_1` element of the linear transformation matrix, in degrees/pixel.
    public var cd1_1: Double? { self.double( "CD1_1" ) }

    /// The `CD1_2` element of the linear transformation matrix.
    public var cd1_2: Double? { self.double( "CD1_2" ) }

    /// The `CD2_1` element of the linear transformation matrix.
    public var cd2_1: Double? { self.double( "CD2_1" ) }

    /// The `CD2_2` element of the linear transformation matrix.
    public var cd2_2: Double? { self.double( "CD2_2" ) }

    /// The coordinate type of axis 1 (`CTYPE1`), e.g. `"RA---TAN"`.
    public var ctype1: String? { self.string( "CTYPE1" ) }

    /// The coordinate type of axis 2 (`CTYPE2`), e.g. `"DEC--TAN"`.
    public var ctype2: String? { self.string( "CTYPE2" ) }

    // MARK: - Derived astrometry

    /// The right ascension of the image reference, in decimal degrees.
    ///
    /// Prefers the WCS reference `CRVAL1` (already degrees); otherwise reads
    /// `OBJCTRA`, which is conventionally sexagesimal *hours* and so is scaled by
    /// 15; otherwise a plain decimal-degree `RA`.
    public var rightAscension: Double?
    {
        if let value = self.double( "CRVAL1" )
        {
            return value
        }

        if case .string( let text )? = self.values[ "OBJCTRA" ], let hours = Self.sexagesimal( text )
        {
            return hours * 15
        }

        return self.double( "RA" )
    }

    /// The declination of the image reference, in decimal degrees.
    ///
    /// Prefers `CRVAL2`; otherwise reads `OBJCTDEC` / `DEC`, which are
    /// sexagesimal (or decimal) degrees, sign-aware.
    public var declination: Double?
    {
        if let value = self.double( "CRVAL2" )
        {
            return value
        }

        return self.angle( "OBJCTDEC", "DEC" )
    }

    /// The observation start time (`DATE-OBS`), parsed as UTC.
    public var observationDate: Date?
    {
        guard case .string( let text )? = self.values[ "DATE-OBS" ]
        else
        {
            return nil
        }

        return Self.date( from: text )
    }

    /// The observing site latitude (`SITELAT`), in decimal degrees, sign-aware;
    /// accepts sexagesimal or decimal.
    public var latitude: Double? { self.angle( "SITELAT" ) }

    /// The observing site longitude (`SITELONG`), in decimal degrees, sign-aware;
    /// accepts sexagesimal or decimal.
    public var longitude: Double? { self.angle( "SITELONG" ) }

    /// The observing site elevation (`SITEELEV`), in metres.
    public var elevation: Double? { self.double( "SITEELEV" ) }

    /// The telescope focal length (`FOCALLEN`), in millimetres.
    public var focalLength: Double? { self.double( "FOCALLEN" ) }

    /// The sensor pixel size (`XPIXSZ`), in micrometres.
    public var pixelSize: Double? { self.double( "XPIXSZ" ) }

    /// The plate scale, in arc-seconds per pixel.
    ///
    /// Derived, in order of preference, from: the `CDELT` increment (degrees/px ×
    /// 3600); else the `CD` matrix (√(CD1_1² + CD2_1²) × 3600); else the focal
    /// length and sensor pixel size (206.265 × pixelSize[µm] / focalLength[mm]).
    public var pixelScale: Double?
    {
        if let increment = self.cdelt2 ?? self.cdelt1
        {
            return abs( increment ) * 3600
        }

        if let a = self.cd1_1, let c = self.cd2_1
        {
            return ( ( a * a ) + ( c * c ) ).squareRoot() * 3600
        }

        if let focalLength = self.focalLength, let pixelSize = self.pixelSize, focalLength > 0
        {
            return 206.265 * pixelSize / focalLength
        }

        return nil
    }

    // MARK: - Value lookups

    /// The first numeric value among `names`: a float or integer keyword, or a
    /// string keyword whose text parses as a plain decimal.
    private func double( _ names: String... ) -> Double?
    {
        for name in names
        {
            switch self.values[ name.uppercased() ]
            {
                case .float( let value ):   return value
                case .integer( let value ): return Double( value )
                case .string( let text ):

                    if let value = Double( text.trimmingCharacters( in: .whitespaces ) )
                    {
                        return value
                    }

                default: break
            }
        }

        return nil
    }

    /// The first non-empty string value among `names`.
    private func string( _ names: String... ) -> String?
    {
        for name in names
        {
            if case .string( let text )? = self.values[ name.uppercased() ]
            {
                let trimmed = text.trimmingCharacters( in: .whitespaces )

                if trimmed.isEmpty == false
                {
                    return trimmed
                }
            }
        }

        return nil
    }

    /// The first angular value among `names`: a float/integer keyword, or a
    /// string keyword parsed as sign-aware sexagesimal (or plain decimal).
    private func angle( _ names: String... ) -> Double?
    {
        for name in names
        {
            switch self.values[ name.uppercased() ]
            {
                case .float( let value ):   return value
                case .integer( let value ): return Double( value )
                case .string( let text ):

                    if let value = Self.sexagesimal( text )
                    {
                        return value
                    }

                default: break
            }
        }

        return nil
    }

    // MARK: - Parsing

    /// Parses a sign-aware sexagesimal angle — `"DD MM SS"`, `"DD:MM:SS"`, or any
    /// truncation thereof — into a decimal value in the leading component's unit.
    /// A bare number (e.g. `"39.41"`) returns unchanged.
    ///
    /// - Parameter string: The sexagesimal or decimal text.
    /// - Returns: The decimal value, or `nil` when the leading component is not a
    ///   number.
    static func sexagesimal( _ string: String ) -> Double?
    {
        let tokens = string
            .replacingOccurrences( of: ":", with: " " )
            .split( separator: " " )
            .map( String.init )

        guard let first = tokens.first, let degrees = Double( first )
        else
        {
            return nil
        }

        var magnitude = abs( degrees )

        if tokens.count > 1, let minutes = Double( tokens[ 1 ] )
        {
            magnitude += minutes / 60
        }

        if tokens.count > 2, let seconds = Double( tokens[ 2 ] )
        {
            magnitude += seconds / 3600
        }

        // The sign lives on the leading component, including a "-00" degrees field
        // whose `Double` value is a signless zero.
        return first.hasPrefix( "-" ) ? -magnitude : magnitude
    }

    /// Parses a FITS `DATE-OBS` string (`YYYY-MM-DDThh:mm:ss[.sss]`, or a bare
    /// date) as UTC.
    ///
    /// - Parameter string: The date text.
    /// - Returns: The parsed date, or `nil` when no supported format matches.
    private static func date( from string: String ) -> Date?
    {
        let trimmed = string.trimmingCharacters( in: .whitespaces )
        let formats =
            [
                "yyyy-MM-dd'T'HH:mm:ss.SSS",
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd",
            ]

        for format in formats
        {
            let formatter        = DateFormatter()
            formatter.locale     = Locale( identifier: "en_US_POSIX" )
            formatter.timeZone   = TimeZone( identifier: "UTC" )
            formatter.dateFormat = format

            if let date = formatter.date( from: trimmed )
            {
                return date
            }
        }

        return nil
    }
}
