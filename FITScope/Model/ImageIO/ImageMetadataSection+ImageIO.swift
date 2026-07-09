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

/// ImageIO adapter for ``ImageMetadataSection``: builds a format-neutral metadata
/// section from a `CGImageSource` metadata dictionary (the top-level image
/// properties, or a nested group such as EXIF, TIFF or GPS).
public extension ImageMetadataSection
{
    /// Builds a section from the scalar entries of a `CGImageSource` metadata
    /// dictionary, or `nil` when it holds no scalar entries (so an absent or purely
    /// nested group is not shown as an empty section).
    ///
    /// The entries are sorted by key for a stable display order; nested
    /// dictionaries (the EXIF/TIFF/GPS groups within the top-level properties) have
    /// no scalar representation and are skipped, so the same builder produces the
    /// top-level "Image" section and each nested group's section.
    ///
    /// - Parameters:
    ///   - index:      The section's position within the file.
    ///   - title:      The display title.
    ///   - dictionary: The `CGImageSource` metadata dictionary.
    /// - Returns: The section, or `nil` when it holds no scalar entries.
    init?( index: Int, title: String, dictionary: [ String: Any ] )
    {
        let rows = dictionary.keys.sorted().compactMap
        {
            key -> ( name: String, value: String )? in

            guard let raw = dictionary[ key ], let value = ImageMetadataProperty.stringForImageIOValue( raw )
            else
            {
                return nil
            }

            return ( name: key, value: value )
        }

        guard rows.isEmpty == false
        else
        {
            return nil
        }

        let properties = rows.enumerated().map
        {
            ImageMetadataProperty( index: $0.offset, name: $0.element.name, kind: "String", value: $0.element.value, comment: "" )
        }

        self.init( index: index, title: title, properties: properties )
    }
}
