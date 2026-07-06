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

/// A `Codable`, `Hashable` snapshot of one metadata section of an image — a
/// display title paired with its properties.
///
/// Format-neutral: a section maps to whatever grouping a format exposes — a FITS
/// header or extension, an XISF image's property set, a photographic image's
/// metadata dictionary. Format-specific builders live in per-format extensions.
public struct ImageMetadataSection: Codable, Hashable, Identifiable, Sendable
{
    /// A stable identity combining the index and title.
    public let id: String

    /// The section's position within the file.
    public let index: Int

    /// A human-readable title for the section (e.g. `"Primary Header"`).
    public let title: String

    /// The section's properties, as display rows.
    public let properties: [ ImageMetadataProperty ]

    /// Builds a section snapshot from its parts.
    ///
    /// - Parameters:
    ///   - index:      The section's position within the file.
    ///   - title:      The display title.
    ///   - properties: The section's display properties.
    public init( index: Int, title: String, properties: [ ImageMetadataProperty ] )
    {
        self.id         = "\( index )-\( title )"
        self.index      = index
        self.title      = title
        self.properties = properties
    }
}
