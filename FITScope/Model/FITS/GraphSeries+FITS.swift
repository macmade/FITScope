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
import SwiftPixel
import SwiftUtilities

/// Decodes a one-dimensional FITS image HDU (`NAXIS=1`) into a neutral
/// ``GraphSeries``, keeping the FITS keyword and byte-format knowledge out of the
/// neutral model. This is the graph counterpart of ``FITSRenderSource`` for images.
public extension GraphSeries
{
    /// Builds a graph series from a one-dimensional FITS image HDU.
    ///
    /// The samples are decoded big-endian per `BITPIX` (reusing SwiftPixel's
    /// `readRawPixels`) and rescaled by `BSCALE`/`BZERO`. The horizontal axis is
    /// physical — `CRVAL1 + (pixel − CRPIX1)·CDELT1`, labelled from `CTYPE1`/`CUNIT1`
    /// — when the header declares a coordinate type and a non-zero increment;
    /// otherwise it is the one-based sample number labelled `"Sample"`. The vertical
    /// axis is labelled from `BUNIT` when present, else `"Value"`.
    ///
    /// - Parameters:
    ///   - header: The image HDU's owning header, holding the geometry and
    ///             world-coordinate keywords.
    ///   - data:   The HDU's raw sample bytes (trailing FITS block padding is
    ///             trimmed to `NAXIS1` samples).
    /// - Throws: ``RuntimeError`` for a missing or unsupported `BITPIX`, an invalid
    ///   `NAXIS1`, or truncated data.
    init( oneDimensionalHeader header: FITSSection, data: Data ) throws
    {
        guard let bitPix = header.bitpix
        else
        {
            throw RuntimeError( message: "Missing BITPIX property" )
        }

        guard let bitsPerPixel = BitsPerPixel.from( value: bitPix )
        else
        {
            throw RuntimeError( message: "Unsupported pixel format: BITPIX \( bitPix ) is not supported (supported values: 8, 16, 32, -32, -64)." )
        }

        guard let nAxis1 = header.naxis( 1 ), let count = Int( exactly: nAxis1 ), count > 0
        else
        {
            throw RuntimeError( message: "Invalid or missing NAXIS1 for a 1-D image" )
        }

        let size      = bitsPerPixel.size( numberOfPixels: count )
        let pixelData = Data( data.prefix( size ) ) // re-wrap: startIndex may be non-zero, and trim block padding

        guard pixelData.count == size
        else
        {
            throw RuntimeError( message: "Data too small: \( data.count ) < \( size )" )
        }

        let raw    = try PixelUtilities.readRawPixels( data: pixelData, width: count, height: 1, bitsPerPixel: bitsPerPixel )
        let scale  = Self.number( header[ "BSCALE" ] ) ?? 1
        let offset = Self.number( header[ "BZERO" ]  ) ?? 0

        // World-coordinate axis keywords. A physical horizontal axis needs a
        // coordinate type and a non-zero increment; otherwise the axis is the plain
        // sample number.
        let cType   = Self.trimmedString( header[ "CTYPE1" ] )
        let cUnit   = Self.trimmedString( header[ "CUNIT1" ] )
        let bUnit   = Self.trimmedString( header[ "BUNIT" ] )
        let cDelt   = Self.number( header[ "CDELT1" ] )
        let refValue = Self.number( header[ "CRVAL1" ] ) ?? 0
        let refPixel = Self.number( header[ "CRPIX1" ] ) ?? 1

        let usePhysicalAxis = cType?.isEmpty == false && cDelt != nil && cDelt != 0

        let points = raw.enumerated().map
        {
            index, value -> Point in

            // FITS pixel coordinates are one-based: the zero-based sample `index`
            // sits at pixel `index + 1`.
            let x = ( usePhysicalAxis && cDelt != nil ) ? refValue + ( Double( index + 1 ) - refPixel ) * ( cDelt ?? 0 ) : Double( index + 1 )
            let y = offset + scale * value

            return Point( index: index, x: x, y: y )
        }

        self.init( points: points, xAxisLabel: Self.axisLabel( type: cType, unit: cUnit, usePhysical: usePhysicalAxis ), yAxisLabel: Self.valueLabel( unit: bUnit ) )
    }

    /// The horizontal-axis label: the coordinate type, suffixed with its unit in
    /// parentheses when both are present, or `"Sample"` when the axis is a plain
    /// sample number.
    ///
    /// - Parameters:
    ///   - type:        The `CTYPE1` value, or `nil`.
    ///   - unit:        The `CUNIT1` value, or `nil`.
    ///   - usePhysical: Whether a physical axis is used.
    /// - Returns: The axis label.
    private static func axisLabel( type: String?, unit: String?, usePhysical: Bool ) -> String
    {
        guard usePhysical, let type, type.isEmpty == false
        else
        {
            return "Sample"
        }

        guard let unit, unit.isEmpty == false
        else
        {
            return type
        }

        return "\( type ) (\( unit ))"
    }

    /// The vertical-axis label: the sample unit (`BUNIT`) when present, else
    /// `"Value"`.
    ///
    /// - Parameter unit: The `BUNIT` value, or `nil`.
    /// - Returns: The axis label.
    private static func valueLabel( unit: String? ) -> String
    {
        guard let unit, unit.isEmpty == false
        else
        {
            return "Value"
        }

        return unit
    }

    /// Reads a keyword's numeric value, accepting either a floating-point or an
    /// integer FITS value.
    ///
    /// - Parameter property: The keyword property, or `nil`.
    /// - Returns: The value as a `Double`, or `nil` when absent or non-numeric.
    private static func number( _ property: FITSProperty? ) -> Double?
    {
        guard let value = property?.value
        else
        {
            return nil
        }

        return value.float ?? value.integer.map( Double.init )
    }

    /// Reads a keyword's whitespace-trimmed string value.
    ///
    /// - Parameter property: The keyword property, or `nil`.
    /// - Returns: The trimmed string, or `nil` when absent or not a string.
    private static func trimmedString( _ property: FITSProperty? ) -> String?
    {
        property?.value.string?.trimmingCharacters( in: .whitespaces )
    }
}
