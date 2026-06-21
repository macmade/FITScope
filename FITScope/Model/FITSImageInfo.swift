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

/// A `Codable`, `Hashable` snapshot of a FITS file's header metadata, suitable
/// for passing to an auxiliary window via SwiftUI's value-based scenes.
public struct FITSImageInfo: Codable, Hashable
{
    /// The URL of the source file.
    public let url:      URL

    /// The file's metadata sections (primary header and any extensions), in file
    /// order. Data-only sections are excluded.
    public let sections: [ FITSImageSection ]

    /// Builds the metadata snapshot from a parsed file.
    ///
    /// Only header and extension sections are kept; sections that
    /// ``FITSImageSection`` cannot represent (e.g. pure data) are dropped.
    ///
    /// - Parameters:
    ///   - url:  The URL the file was loaded from.
    ///   - file: The parsed FITS file.
    public init( url: URL, file: FITSFile )
    {
        self.url      = url
        self.sections = file.sections.enumerated().compactMap
        {
            FITSImageSection( index: $0.offset, section: $0.element )
        }
    }

    /// Creates an info snapshot directly from sections, for tests and previews.
    ///
    /// - Parameters:
    ///   - url:      The source URL.
    ///   - sections: The metadata sections.
    public init( url: URL, sections: [ FITSImageSection ] )
    {
        self.url      = url
        self.sections = sections
    }

    /// Whether the image is a colour-filter-array (CFA) image — one that declares
    /// a Bayer pattern via a non-empty `BAYERPAT` keyword. Only such an image is
    /// debayered into colour; a file without it is treated as monochrome, so the
    /// debayer controls have nothing to act on.
    public var isColorFilterArray: Bool
    {
        self.sections.contains
        {
            $0.properties.contains
            {
                $0.name == "BAYERPAT" && $0.value.trimmingCharacters( in: .whitespaces ).isEmpty == false
            }
        }
    }
}
