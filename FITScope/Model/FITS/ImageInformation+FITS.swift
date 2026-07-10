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

/// Builds the neutral ``ImageInformation`` summary from FITS header keywords,
/// keeping the FITS-specific keyword knowledge out of the neutral model. Other
/// formats provide their own builder from their own metadata.
public extension ImageInformation
{
    /// Builds the summary from FITS header metadata, returning `nil` when the
    /// required geometry keywords (`NAXIS1`/`NAXIS2`/`BITPIX`) are absent.
    ///
    /// - Parameter fitsMetadata: The grouped FITS header metadata to summarize.
    init?( fitsMetadata: ImageMetadata )
    {
        let properties = fitsMetadata.sections.flatMap { $0.properties }

        func value( _ names: [ String ] ) -> String?
        {
            for name in names
            {
                if let value = properties.first( where: { $0.name == name } )?.value.trimmingCharacters( in: .whitespaces ), value.isEmpty == false
                {
                    return value
                }
            }

            return nil
        }

        guard let width  = value( [ "NAXIS1" ] ),
              let height = value( [ "NAXIS2" ] ),
              let bitPix = value( [ "BITPIX" ] )
        else
        {
            return nil
        }

        let bayer      = value( [ "BAYERPAT" ] )
        let dimensions = "\( width ) × \( height )"
        let bitDepth   = "\( bitPix.replacingOccurrences( of: "-", with: "" ) )-bit"
        let channels   = bayer == nil ? "1 (Grayscale)" : "1 (CFA)"

        var values: [ InfoField: String ] =
            [
                .dimensions: dimensions,
                .bitDepth:   bitDepth,
                .channels:   channels,
            ]

        func add( _ field: InfoField, _ names: [ String ], suffix: String = "" )
        {
            if let value = value( names )
            {
                values[ field ] = suffix.isEmpty ? value : "\( value )\( suffix )"
            }
        }

        if let bayer = bayer
        {
            values[ .bayer ] = bayer
        }

        add( .object,            [ "OBJECT" ] )
        add( .rightAscension,    [ "OBJCTRA", "RA", "CRVAL1" ] )
        add( .declination,       [ "OBJCTDEC", "DEC", "CRVAL2" ] )
        add( .date,              [ "DATE-OBS" ] )
        add( .exposure,          [ "EXPTIME", "EXPOSURE" ], suffix: " s" )
        add( .filter,            [ "FILTER" ] )
        add( .telescope,         [ "TELESCOP" ] )
        add( .instrument,        [ "INSTRUME" ] )
        add( .focalLength,       [ "FOCALLEN" ] )
        add( .gain,              [ "GAIN", "EGAIN" ] )
        add( .offset,            [ "OFFSET", "BLKLEVEL" ] )
        add( .sensorTemperature, [ "CCD-TEMP" ] )

        // The plate scale and its sampling classification reuse FITSMetadata's
        // unit-aware derivation (CDELT → CD matrix → focal length + pixel size)
        // rather than re-implementing it here. The display strings carry enough
        // precision for a value shown to two decimals.
        let metadata = FITSMetadata(
            properties: properties.map { FITSPropertySnapshot( name: $0.name, value: .string( $0.value ) ) }
        )

        if let scale = metadata.pixelScale, let sampling = metadata.sampling
        {
            let formatted = String( format: "%.2f", scale )

            values[ .sampling ] = "\( formatted )″/px · \( sampling.label )"
        }

        self.init( dimensions: dimensions, bitDepth: bitDepth, channels: channels, values: values )
    }

    /// Builds the summary for a FITS data set shown as a graph — a one-dimensional
    /// spectrum (`NAXIS=1`) or a two-dimensional stack of spectra (`NAXIS=2`).
    /// Returns `nil` when `BITPIX` is absent.
    ///
    /// A graph has no `width × height`, so its "dimensions" read as a sample count
    /// (e.g. `"4096 samples"`), or, for a stack, a sample count and a spectrum count
    /// (e.g. `"2064 samples × 2 spectra"`). The channel field notes the graph shape.
    ///
    /// - Parameters:
    ///   - graphMetadata: The grouped FITS header metadata to summarize.
    ///   - graph:         The decoded graph series, for its line and sample counts.
    init?( graphMetadata: ImageMetadata, graph: GraphSeries )
    {
        let properties = graphMetadata.sections.flatMap { $0.properties }

        guard let bitPix = properties.first( where: { $0.name == "BITPIX" } )?.value.trimmingCharacters( in: .whitespaces ), bitPix.isEmpty == false
        else
        {
            return nil
        }

        let lineCount   = graph.lines.count
        let sampleCount = graph.lines.first?.points.count ?? 0
        let samples     = sampleCount == 1 ? "1 sample" : "\( sampleCount ) samples"
        let dimensions  = lineCount > 1 ? "\( samples ) × \( lineCount ) spectra" : samples
        let bitDepth    = "\( bitPix.replacingOccurrences( of: "-", with: "" ) )-bit"
        let channels    = lineCount > 1 ? "2 (\( lineCount ) spectra)" : "1 (1D)"

        self.init(
            dimensions: dimensions,
            bitDepth:   bitDepth,
            channels:   channels,
            values:
            [
                .dimensions: dimensions,
                .bitDepth:   bitDepth,
                .channels:   channels,
            ]
        )
    }
}
