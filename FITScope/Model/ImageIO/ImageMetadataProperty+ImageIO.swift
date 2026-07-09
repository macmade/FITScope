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

/// ImageIO adapter for ``ImageMetadataProperty``: formats a value from a
/// `CGImageSource` metadata dictionary into a display string.
public extension ImageMetadataProperty
{
    /// Formats a `CGImageSource` metadata value for display, or `nil` when it has no
    /// scalar representation (e.g. a nested dictionary, which is surfaced as its own
    /// section instead).
    ///
    /// The values bridge from Core Foundation types: a `CFString` to `String`, a
    /// `CFNumber`/`CFBoolean` to `NSNumber`, a `CFArray` to `[Any]` (joined), and a
    /// `CFData` to a byte count.
    ///
    /// - Parameter value: The metadata value.
    /// - Returns: The display string, or `nil` when it cannot be represented.
    static func stringForImageIOValue( _ value: Any ) -> String?
    {
        switch value
        {
            case let string as String:

                return string

            case let number as NSNumber:

                return number.stringValue

            case let array as [ Any ]:

                let parts = array.compactMap { Self.stringForImageIOValue( $0 ) }

                return parts.isEmpty ? nil : parts.joined( separator: ", " )

            case let data as Data:

                return "\( data.count ) bytes"

            default:

                return nil
        }
    }
}
