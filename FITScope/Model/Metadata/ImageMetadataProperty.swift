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

/// A display-ready, `Codable` snapshot of a single metadata entry — a labelled
/// key/value pair with a value-type description and an optional comment.
///
/// Format-neutral: any image format (FITS keywords, XISF properties, EXIF tags,
/// …) flattens one metadata entry into these plain strings so it can populate a
/// `Table` and travel across SwiftUI's value-based scenes. Format-specific
/// builders live in per-format extensions (e.g. the FITS keyword adapter).
public struct ImageMetadataProperty: Codable, Hashable, Identifiable, Sendable
{
    /// A stable identity combining the index, name, kind, value and comment, so
    /// distinct rows never collide even when keys repeat.
    public let id: String

    /// The property's position within its section.
    public let index: Int

    /// The key name (e.g. `BITPIX`, `Exposure Time`).
    public let name: String

    /// A human-readable description of the value's type (logical, integer, …).
    public let kind: String

    /// The value formatted as a display string, or `""` when absent.
    public let value: String

    /// The property's comment, or `""` when absent.
    public let comment: String

    /// Builds a display property from its display strings.
    ///
    /// - Parameters:
    ///   - index:   The property's position within its section.
    ///   - name:    The key name.
    ///   - kind:    The value-type description.
    ///   - value:   The display value (`""` when absent).
    ///   - comment: The comment (`""` when absent).
    public init( index: Int, name: String, kind: String, value: String, comment: String )
    {
        self.index   = index
        self.name    = name
        self.kind    = kind
        self.value   = value
        self.comment = comment
        self.id      = "\( index )-\( name )-\( kind )-\( value.isEmpty ? "<nil>" : value )-\( comment.isEmpty ? "<nil>" : comment )"
    }
}
