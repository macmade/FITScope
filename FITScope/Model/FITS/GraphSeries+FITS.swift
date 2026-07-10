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
        guard let nAxis1 = header.naxis( 1 ), let count = Int( exactly: nAxis1 ), count > 0
        else
        {
            throw RuntimeError( message: "Invalid or missing NAXIS1 for a 1-D image" )
        }

        let raw  = try Self.samples( header: header, data: data, sampleCount: count )
        let axis = Self.axis( header: header )

        self.init( lines: [ Line( index: 0, name: nil, points: axis.points( from: raw ) ) ], xAxisLabel: axis.xAxisLabel, yAxisLabel: axis.yAxisLabel )
    }

    /// Builds a graph series from a two-dimensional stacked-spectra FITS image HDU
    /// (`NAXIS=2`) — one row per spectrum, sharing the horizontal dispersion axis.
    ///
    /// Each of the `NAXIS2` rows is decoded like a one-dimensional spectrum (samples
    /// big-endian per `BITPIX`, rescaled by `BSCALE`/`BZERO`) and becomes a named
    /// line (`"Row 1"`, `"Row 2"`, …); every row shares the same horizontal axis,
    /// built from `CTYPE1`/`CDELT1`/… exactly as for a `NAXIS=1` spectrum. This is
    /// only ever used for a genuine spectra stack (see ``isSpectraStack(header:)``);
    /// a normal 2-D image keeps taking the raster pipeline.
    ///
    /// - Parameters:
    ///   - header: The image HDU's owning header, holding the geometry and
    ///             world-coordinate keywords.
    ///   - data:   The HDU's raw sample bytes (row-major, first axis fastest;
    ///             trailing FITS block padding is trimmed).
    /// - Throws: ``RuntimeError`` when the HDU is not a spectra stack, for a missing
    ///   or unsupported `BITPIX`, an invalid `NAXIS1`/`NAXIS2`, or truncated data.
    init( stackedSpectraHeader header: FITSSection, data: Data ) throws
    {
        guard Self.isSpectraStack( header: header )
        else
        {
            throw RuntimeError( message: "Not a stacked-spectra image HDU" )
        }

        guard let nAxis1 = header.naxis( 1 ), let width = Int( exactly: nAxis1 ), width > 0
        else
        {
            throw RuntimeError( message: "Invalid or missing NAXIS1 for a stacked-spectra image" )
        }

        guard let nAxis2 = header.naxis( 2 ), let rows = Int( exactly: nAxis2 ), rows > 0
        else
        {
            throw RuntimeError( message: "Invalid or missing NAXIS2 for a stacked-spectra image" )
        }

        // Guard the sample count against overflow so a crafted header degrades
        // gracefully (throw, then fall through to the raster path) rather than
        // trapping — matching how the raster decode's `readRawPixels` guards it.
        let ( count, overflow ) = width.multipliedReportingOverflow( by: rows )

        guard overflow == false
        else
        {
            throw RuntimeError( message: "NAXIS1 × NAXIS2 overflows for a stacked-spectra image" )
        }

        // FITS stores the first axis fastest, so the samples arrive row-major: row
        // `r` (a single spectrum) is the contiguous `width`-sample slice at `r·width`.
        let raw  = try Self.samples( header: header, data: data, sampleCount: count )
        let axis = Self.axis( header: header )

        let lines = ( 0 ..< rows ).map
        {
            row -> Line in

            let start      = row * width
            let rowSamples = Array( raw[ start ..< start + width ] )

            return Line( index: row, name: "Row \( row + 1 )", points: axis.points( from: rowSamples ) )
        }

        self.init( lines: lines, xAxisLabel: axis.xAxisLabel, yAxisLabel: axis.yAxisLabel )
    }

    /// Whether a `NAXIS=2` image HDU is a stack of one-dimensional spectra (one row
    /// per spectrum) rather than an ordinary image, so it takes the multi-line graph
    /// branch instead of the raster pipeline.
    ///
    /// The rule keys strictly on a *known* spectral `CTYPE1` (the FITS WCS Paper III
    /// codes) so a normal image — which carries a spatial `CTYPE1` (`RA---`, `DEC--`,
    /// `GLON`…) or none at all — is never misclassified as a graph. It additionally
    /// requires `CTYPE2` not to be a spatial coordinate, so a long-slit spectrogram
    /// (a spectral dispersion axis and a spatial slit axis), which is genuinely a
    /// 2-D image, keeps rendering as an image.
    ///
    /// - Parameter header: The image HDU's header.
    /// - Returns: `true` when the HDU is a stacked-spectra image.
    static func isSpectraStack( header: FITSSection ) -> Bool
    {
        guard let nAxis = header.naxis, nAxis == 2
        else
        {
            return false
        }

        guard let cType1 = Self.trimmedString( header[ "CTYPE1" ] ), Self.isSpectralType( cType1 )
        else
        {
            return false
        }

        if let cType2 = Self.trimmedString( header[ "CTYPE2" ] ), Self.isSpatialType( cType2 )
        {
            return false
        }

        return true
    }

    /// The FITS WCS spectral coordinate type codes (Greisen et al. 2006,
    /// "Representations of spectral coordinates in FITS", Table 1): the four-character
    /// `CTYPEia` roots whose axis measures a spectral quantity.
    private static let spectralTypeCodes: Set< String > = [ "FREQ", "ENER", "WAVN", "VRAD", "WAVE", "VOPT", "ZOPT", "AWAV", "VELO", "BETA" ]

    /// Whether a `CTYPE` value names a known spectral coordinate.
    ///
    /// - Parameter cType: The `CTYPE` value.
    /// - Returns: `true` when its root is a spectral type code.
    private static func isSpectralType( _ cType: String ) -> Bool
    {
        Self.spectralTypeCodes.contains( Self.coordinateRoot( cType ) )
    }

    /// Whether a `CTYPE` value names a spatial (celestial) coordinate — right
    /// ascension, declination, or any longitude/latitude pair (`GLON`/`GLAT`,
    /// `ELON`/`ELAT`, …).
    ///
    /// - Parameter cType: The `CTYPE` value.
    /// - Returns: `true` when its root is a spatial type.
    private static func isSpatialType( _ cType: String ) -> Bool
    {
        let root = Self.coordinateRoot( cType )

        return root == "RA" || root == "DEC" || root.hasSuffix( "LON" ) || root.hasSuffix( "LAT" )
    }

    /// The coordinate-name root of a `CTYPE` value: its text before the algorithm-code
    /// suffix, uppercased. A `CTYPE` is a four-character name optionally followed by a
    /// `-` and a three-character algorithm code, with short names dash-padded — so
    /// `"WAVE-F2W"` → `"WAVE"` and `"RA---TAN"` → `"RA"`.
    ///
    /// - Parameter cType: The `CTYPE` value.
    /// - Returns: The uppercased coordinate-name root.
    private static func coordinateRoot( _ cType: String ) -> String
    {
        String( cType.uppercased().split( separator: "-" ).first ?? "" )
    }

    /// Decodes `sampleCount` big-endian samples from a FITS data segment per `BITPIX`,
    /// re-wrapping the slice (its start index may be non-zero) and trimming trailing
    /// FITS block padding to the exact sample count. Shared by the one-dimensional and
    /// stacked-spectra decoders.
    ///
    /// - Parameters:
    ///   - header:      The HDU's header, for `BITPIX`.
    ///   - data:        The HDU's raw sample bytes.
    ///   - sampleCount: The number of samples to decode.
    /// - Returns: The decoded, unscaled samples.
    /// - Throws: ``RuntimeError`` for a missing or unsupported `BITPIX`, or truncated
    ///   data.
    private static func samples( header: FITSSection, data: Data, sampleCount: Int ) throws -> [ Double ]
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

        let size      = bitsPerPixel.size( numberOfPixels: sampleCount )
        let pixelData = Data( data.prefix( size ) )

        guard pixelData.count == size
        else
        {
            throw RuntimeError( message: "Data too small: \( data.count ) < \( size )" )
        }

        return try PixelUtilities.readRawPixels( data: pixelData, width: sampleCount, height: 1, bitsPerPixel: bitsPerPixel )
    }

    /// The horizontal-axis scaling and labelling shared by every line of a graph,
    /// built once from the header. A physical horizontal axis needs a coordinate type
    /// and a non-zero increment; otherwise the axis is the plain sample number.
    ///
    /// - Parameter header: The HDU's header, holding the world-coordinate and scaling
    ///   keywords.
    /// - Returns: The axis configuration.
    private static func axis( header: FITSSection ) -> Axis
    {
        let cType    = Self.trimmedString( header[ "CTYPE1" ] )
        let cUnit    = Self.trimmedString( header[ "CUNIT1" ] )
        let bUnit    = Self.trimmedString( header[ "BUNIT"  ] )
        let cDelt    = Self.number( header[ "CDELT1" ] )
        let refValue = Self.number( header[ "CRVAL1" ] ) ?? 0
        let refPixel = Self.number( header[ "CRPIX1" ] ) ?? 1

        let usePhysical = cType?.isEmpty == false && cDelt != nil && cDelt != 0

        return Axis(
            scale:       Self.number( header[ "BSCALE" ] ) ?? 1,
            offset:      Self.number( header[ "BZERO"  ] ) ?? 0,
            usePhysical: usePhysical,
            refValue:    refValue,
            refPixel:    refPixel,
            increment:   cDelt ?? 0,
            xAxisLabel:  Self.axisLabel( type: cType, unit: cUnit, usePhysical: usePhysical ),
            yAxisLabel:  Self.valueLabel( unit: bUnit )
        )
    }

    /// The shared horizontal-axis scaling and labels for a graph's lines. Building it
    /// once and reusing it across rows keeps a stacked spectrum's lines on one axis
    /// and avoids re-reading the header per row.
    private struct Axis
    {
        /// The value scaling factor (`BSCALE`).
        let scale: Double

        /// The value scaling offset (`BZERO`).
        let offset: Double

        /// Whether the horizontal axis is a physical world coordinate rather than the
        /// plain sample number.
        let usePhysical: Bool

        /// The reference-point world value (`CRVAL1`).
        let refValue: Double

        /// The reference pixel (`CRPIX1`), one-based.
        let refPixel: Double

        /// The per-pixel world-coordinate increment (`CDELT1`).
        let increment: Double

        /// The horizontal-axis label.
        let xAxisLabel: String

        /// The vertical-axis label.
        let yAxisLabel: String

        /// Builds the plotted points for one row of samples, applying the value
        /// scaling and the shared horizontal axis.
        ///
        /// - Parameter samples: The row's unscaled samples, in order.
        /// - Returns: The plotted points.
        func points( from samples: [ Double ] ) -> [ Point ]
        {
            samples.enumerated().map
            {
                index, value -> Point in

                // FITS pixel coordinates are one-based: the zero-based sample `index`
                // sits at pixel `index + 1`.
                let x = self.usePhysical ? self.refValue + ( Double( index + 1 ) - self.refPixel ) * self.increment : Double( index + 1 )
                let y = self.offset + self.scale * value

                return Point( index: index, x: x, y: y )
            }
        }
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
