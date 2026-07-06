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

/// A `Codable`, `Hashable` snapshot of an image file's metadata, grouped into
/// sections of properties, suitable for passing to the Info window via SwiftUI's
/// value-based scenes.
///
/// Format-neutral: every image format (FITS, XISF, photographic) adapts its own
/// metadata into this shape, giving the Info window a single value type to
/// display regardless of the source format.
public struct ImageMetadata: Codable, Hashable, Sendable
{
    /// The URL of the source file.
    public let url: URL

    /// The file's metadata sections, in file order.
    public let sections: [ ImageMetadataSection ]

    /// Builds a metadata snapshot from its sections.
    ///
    /// - Parameters:
    ///   - url:      The source URL.
    ///   - sections: The metadata sections.
    public init( url: URL, sections: [ ImageMetadataSection ] )
    {
        self.url      = url
        self.sections = sections
    }
}
