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

/// A display-ready summary of a FITS image's key header values, extracted from a
/// ``FITSImageInfo`` for the sidebar's Image Information panel and the file row
/// metadata line.
public struct ImageInformation
{
    /// A single labelled field shown in the Image Information panel.
    public struct Row: Equatable
    {
        /// The field label, e.g. `"Exposure"`.
        public let label: String

        /// The field value, always non-empty.
        public let value: String
    }

    /// The ordered, present-only fields. Absent keywords are omitted entirely
    /// rather than shown as placeholders.
    public let rows: [ Row ]

    /// The image dimensions, e.g. `"6240 × 4160"`. Used by the file row and
    /// status bar.
    public let dimensions: String

    /// The bit depth, e.g. `"16-bit"`. Used by the file row and status bar.
    public let bitDepth:   String

    /// The channel description, e.g. `"1 (Grayscale)"`.
    public let channels:   String

    /// Builds the summary from header info, returning `nil` when the required
    /// geometry keywords (`NAXIS1`/`NAXIS2`/`BITPIX`) are absent.
    ///
    /// - Parameter info: The header info to summarize.
    public init?( info: FITSImageInfo )
    {
        let properties = info.sections.flatMap { $0.properties }

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

        let bayer       = value( [ "BAYERPAT" ] )
        self.dimensions = "\( width ) × \( height )"
        self.bitDepth   = "\( bitPix.replacingOccurrences( of: "-", with: "" ) )-bit"
        self.channels   = bayer == nil ? "1 (Grayscale)" : "1 (CFA)"

        var rows: [ Row ] =
            [
                Row( label: "Dimensions", value: self.dimensions ),
                Row( label: "Bit Depth",  value: self.bitDepth ),
                Row( label: "Channels",   value: self.channels ),
            ]

        func add( _ label: String, _ names: [ String ], suffix: String = "" )
        {
            if let value = value( names )
            {
                rows.append( Row( label: label, value: suffix.isEmpty ? value : "\( value )\( suffix )" ) )
            }
        }

        if let bayer = bayer
        {
            rows.append( Row( label: "Bayer", value: bayer ) )
        }

        add( "Object",       [ "OBJECT" ] )
        add( "RA",           [ "OBJCTRA", "RA", "CRVAL1" ] )
        add( "Dec",          [ "OBJCTDEC", "DEC", "CRVAL2" ] )
        add( "Date",         [ "DATE-OBS" ] )
        add( "Exposure",     [ "EXPTIME", "EXPOSURE" ], suffix: " s" )
        add( "Filter",       [ "FILTER" ] )
        add( "Telescope",    [ "TELESCOP" ] )
        add( "Instrument",   [ "INSTRUME" ] )
        add( "Focal Length", [ "FOCALLEN" ] )
        add( "Gain",         [ "GAIN", "EGAIN" ] )
        add( "Offset",       [ "OFFSET", "BLKLEVEL" ] )
        add( "Sensor Temp",  [ "CCD-TEMP" ] )

        self.rows = rows
    }
}
