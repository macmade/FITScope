/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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
    /// The image dimensions, e.g. `"6240 × 4160"`.
    public let dimensions: String

    /// The bit depth, e.g. `"16-bit"`.
    public let bitDepth:   String

    /// The channel description, e.g. `"1 (Grayscale)"`.
    public let channels:   String

    /// The Bayer pattern, e.g. `"None"` or `"RGGB"`.
    public let bayer:      String

    /// The observation date, or `"—"` when absent.
    public let date:       String

    /// The exposure, e.g. `"10.00 s"`, or `"—"`.
    public let exposure:   String

    /// The filter name, or `"—"`.
    public let filter:     String

    /// The telescope name, or `"—"`.
    public let telescope:  String

    /// The instrument name, or `"—"`.
    public let instrument: String

    /// Builds the summary from header info, returning `nil` when the required
    /// geometry keywords (`NAXIS1`/`NAXIS2`/`BITPIX`) are absent.
    ///
    /// - Parameter info: The header info to summarize.
    public init?( info: FITSImageInfo )
    {
        let properties = info.sections.flatMap { $0.properties }

        func value( _ name: String ) -> String?
        {
            properties.first { $0.name == name }?.value.trimmingCharacters( in: .whitespaces ).nonEmpty
        }

        guard let width  = value( "NAXIS1" ),
              let height = value( "NAXIS2" ),
              let bitPix = value( "BITPIX" )
        else
        {
            return nil
        }

        self.dimensions = "\( width ) × \( height )"
        self.bitDepth   = "\( bitPix.replacingOccurrences( of: "-", with: "" ) )-bit"

        let bayer       = value( "BAYERPAT" )
        self.bayer      = bayer ?? "None"
        self.channels   = bayer == nil ? "1 (Grayscale)" : "1 (CFA)"

        self.date       = value( "DATE-OBS" ) ?? "—"
        self.exposure   = value( "EXPTIME" ).map { "\( $0 ) s" } ?? value( "EXPOSURE" ).map { "\( $0 ) s" } ?? "—"
        self.filter     = value( "FILTER" )   ?? "—"
        self.telescope  = value( "TELESCOP" ) ?? "—"
        self.instrument = value( "INSTRUME" ) ?? "—"
    }
}

private extension String
{
    /// Returns `self` when non-empty, otherwise `nil`.
    var nonEmpty: String?
    {
        self.isEmpty ? nil : self
    }
}
