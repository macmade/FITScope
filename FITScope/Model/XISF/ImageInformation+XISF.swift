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

/// Builds the neutral ``ImageInformation`` summary for an XISF image, mirroring the
/// FITS adapter: the geometry comes from the image's own layout, and the remaining
/// fields (object, pointing, exposure, plate scale, …) from its embedded FITS
/// keywords through the same accessors the FITS path uses.
public extension ImageInformation
{
    /// Builds the summary from an XISF image's info snapshot.
    ///
    /// - Parameter xisfInfo: The parsed XISF image info.
    init( xisfInfo: XISFImageInfo )
    {
        let layout     = xisfInfo.imageProperties
        let properties = xisfInfo.sections.flatMap { $0.properties }

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

        let dimensions = "\( layout.width ) × \( layout.height )"
        let bitDepth   = "\( layout.sampleFormat.bytesPerSample * 8 )-bit"
        let channels   = xisfInfo.isColorFilterArray ? "1 (CFA)" : ( layout.colorSpace == .rgb ? "3 (RGB)" : "1 (Grayscale)" )

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

        if let pattern = layout.colorFilterArrayPattern
        {
            values[ .bayer ] = pattern
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
        // unit-aware derivation over the embedded keywords, as for the FITS builder.
        let metadata = xisfInfo.metadata

        if let scale = metadata.pixelScale, let sampling = metadata.sampling
        {
            let formatted = String( format: "%.2f", scale )

            values[ .sampling ] = "\( formatted )″/px · \( sampling.label )"
        }

        self.init( dimensions: dimensions, bitDepth: bitDepth, channels: channels, values: values )
    }
}
