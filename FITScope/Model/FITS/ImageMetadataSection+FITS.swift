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

/// FITS adapter for ``ImageMetadataSection``: builds a format-neutral metadata
/// section from a parsed FITS section, keeping only the header and extension
/// sections that carry displayable keywords.
public extension ImageMetadataSection
{
    /// Builds a section snapshot from a parsed FITS section, succeeding only for
    /// header and extension sections.
    ///
    /// - Parameters:
    ///   - index:   The section's position within the file.
    ///   - section: The parsed FITS section.
    /// - Returns: `nil` when the section is neither a header nor an extension
    ///   (e.g. a pure data section), which carries no displayable keywords.
    init?( index: Int, section: FITSSection )
    {
        guard section.kind == .header || section.kind == .xtension
        else
        {
            return nil
        }

        let title      = Self.title( for: section )
        let properties = section.properties.enumerated().map
        {
            ImageMetadataProperty( index: $0.offset, property: $0.element )
        }

        self.init( index: index, title: title, properties: properties )
    }

    /// Derives a human-readable title for a section from its kind, using the
    /// `XTENSION` keyword to name extensions when present.
    ///
    /// - Parameter section: The section to title.
    /// - Returns: A display title such as `"Primary Header"`, `"Extension: …"`,
    ///   `"Data"` or `"Unknown"`.
    static func title( for section: FITSSection ) -> String
    {
        switch section.kind
        {
            case .header:

                return "Primary Header"

            case .xtension:

                if let property = section.properties.first, property.name == "XTENSION", let value = property.value.string, value.trimmingCharacters( in: .whitespaces ).isEmpty == false
                {
                    return "Extension: \( value )"
                }

                return "Extension"

            case .data:

                return "Data"

            @unknown default:

                return "Unknown"
        }
    }
}
