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
        /// The field this row presents.
        public let field: InfoField

        /// The field value, always non-empty.
        public let value: String

        /// The field's display label, e.g. `"Exposure"`.
        public var label: String { self.field.label }

        /// The name of the SF Symbol shown beside the field.
        public var systemImageName: String { self.field.systemImageName }
    }

    /// The present value for each field that has one, keyed by ``InfoField``.
    /// Absent keywords have no entry, so they are never shown as placeholders.
    /// ``rows(for:)`` reads from this to honour the user's selection and order.
    private let values: [ InfoField: String ]

    /// The ordered, present-only fields in the canonical default order — every
    /// available field, geometry first.
    ///
    /// The configurable panel uses ``rows(for:)`` instead; this convenience
    /// covers callers that want the full default layout.
    public var rows: [ Row ]
    {
        self.rows( for: InfoField.allCases )
    }

    /// The image dimensions, e.g. `"6240 × 4160"`. Used by the file row and
    /// status bar.
    public let dimensions: String

    /// The bit depth, e.g. `"16-bit"`. Used by the file row and status bar.
    public let bitDepth:   String

    /// The channel description, e.g. `"1 (Grayscale)"`.
    public let channels:   String

    /// The present-only rows for the given fields, in the given order.
    ///
    /// A field with no value in this image — its keyword is absent — is omitted
    /// entirely, so the panel never shows empty placeholders. The result order
    /// follows `fields`, letting the caller drive both selection and order from
    /// the user's configuration.
    ///
    /// - Parameter fields: The fields to show, in display order.
    /// - Returns: One row per present field, in `fields` order.
    public func rows( for fields: [ InfoField ] ) -> [ Row ]
    {
        fields.compactMap
        {
            field in self.values[ field ].map { Row( field: field, value: $0 ) }
        }
    }

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

        var values: [ InfoField: String ] =
            [
                .dimensions: self.dimensions,
                .bitDepth:   self.bitDepth,
                .channels:   self.channels,
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

        self.values = values
    }
}
