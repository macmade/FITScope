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
import UniformTypeIdentifiers

/// Serializes an image's metadata to a delimited text table — CSV or TSV — for
/// export from the headers window.
///
/// Every section (for FITS, the primary header and any extensions) is included,
/// one row per property, prefixed with its section title so a multi-section file
/// stays unambiguous. The columns mirror the headers table: Section, Index, Name,
/// Kind, Value, Comment. Fields are escaped per the chosen format so the result
/// opens cleanly in a spreadsheet.
public enum HeaderExport
{
    /// A delimited text format, with its delimiters, file extension and UTI.
    public enum Format: String, CaseIterable, Identifiable, Hashable
    {
        /// Comma-separated values, escaped per RFC 4180.
        case csv

        /// Tab-separated values.
        case tsv

        /// The stable identity for `ForEach`/`Picker`.
        public var id: String { self.rawValue }

        /// The label shown in the format picker.
        public var title: String
        {
            switch self
            {
                case .csv: return "CSV"
                case .tsv: return "TSV"
            }
        }

        /// The field delimiter.
        var fieldSeparator: String
        {
            switch self
            {
                case .csv: return ","
                case .tsv: return "\t"
            }
        }

        /// The row delimiter. CSV uses CRLF (RFC 4180); TSV uses LF.
        var rowSeparator: String
        {
            switch self
            {
                case .csv: return "\r\n"
                case .tsv: return "\n"
            }
        }

        /// The file extension for a saved document.
        public var fileExtension: String
        {
            switch self
            {
                case .csv: return "csv"
                case .tsv: return "tsv"
            }
        }

        /// The uniform type identifier for the save panel.
        public var contentType: UTType
        {
            switch self
            {
                case .csv: return .commaSeparatedText
                case .tsv: return .tabSeparatedText
            }
        }
    }

    /// The column header row, in output order.
    static let columns = [ "Section", "Index", "Name", "Kind", "Value", "Comment" ]

    /// Serializes an image's metadata to the given format.
    ///
    /// - Parameters:
    ///   - metadata: The image's metadata.
    ///   - format:   The output format.
    /// - Returns: The serialized table as a string.
    public static func export( _ metadata: ImageMetadata, as format: Format ) -> String
    {
        Self.export( metadata.sections, as: format )
    }

    /// Serializes the given metadata sections to the given format.
    ///
    /// - Parameters:
    ///   - sections: The sections to export (one section for the displayed section,
    ///               all of them for the whole file).
    ///   - format:   The output format.
    /// - Returns: The serialized table as a string.
    public static func export( _ sections: [ ImageMetadataSection ], as format: Format ) -> String
    {
        let header = Self.row( Self.columns, for: format )

        let rows = sections.flatMap
        {
            section in section.properties.map
            {
                Self.row( [ section.title, "\( $0.index )", $0.name, $0.kind, $0.value, $0.comment ], for: format )
            }
        }

        return ( [ header ] + rows ).joined( separator: format.rowSeparator )
    }

    /// Joins a row's fields with the format's field separator, escaping each field.
    ///
    /// - Parameters:
    ///   - fields: The raw field values.
    ///   - format: The output format.
    /// - Returns: The serialized row.
    static func row( _ fields: [ String ], for format: Format ) -> String
    {
        fields.map { Self.escape( $0, for: format ) }.joined( separator: format.fieldSeparator )
    }

    /// Escapes a single field for the given format.
    ///
    /// CSV follows RFC 4180: a field containing a comma, double quote, CR or LF is
    /// wrapped in double quotes, with embedded quotes doubled. TSV has no quoting,
    /// so embedded tabs and line breaks are replaced with single spaces.
    ///
    /// - Parameters:
    ///   - field:  The raw field value.
    ///   - format: The output format.
    /// - Returns: The escaped field.
    static func escape( _ field: String, for format: Format ) -> String
    {
        switch format
        {
            case .csv:

                guard field.contains( where: { $0 == "\"" || $0 == "," || $0 == "\n" || $0 == "\r" } )
                else
                {
                    return field
                }

                return "\"\( field.replacingOccurrences( of: "\"", with: "\"\"" ) )\""

            case .tsv:

                return field
                    .replacingOccurrences( of: "\t",   with: " " )
                    .replacingOccurrences( of: "\r\n", with: " " )
                    .replacingOccurrences( of: "\n",   with: " " )
                    .replacingOccurrences( of: "\r",   with: " " )
        }
    }
}
