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

import SwiftUI
import SwiftUtilities
import UniformTypeIdentifiers

/// A read-only document wrapper exposing a FITS file's raw bytes to SwiftUI's
/// document architecture.
///
/// The document holds only the unparsed file contents; parsing into a
/// ``FITSImage`` happens later in ``FITSImageLoader``. Writing is not supported.
public struct FITSDocument: FileDocument
{
    /// The raw, unparsed bytes of the FITS file.
    public let data: Data

    /// Reads a document from the framework-supplied file contents.
    ///
    /// - Parameter configuration: The read configuration provided by SwiftUI.
    /// - Throws: `CocoaError(.fileReadCorruptFile)` when the file has no regular
    ///   file contents to read.
    public init( configuration: ReadConfiguration ) throws
    {
        if let data = configuration.file.regularFileContents
        {
            self.data = data
        }
        else
        {
            throw CocoaError( .fileReadCorruptFile )
        }
    }

    /// Creates a document directly from raw bytes, used for previews and tests.
    ///
    /// - Parameter data: The raw FITS file bytes.
    public init( data: Data )
    {
        self.data = data
    }

    /// The content types this document can open — the FITS uniform type.
    public static var readableContentTypes: [ UTType ]
    {
        [ .fits ]
    }

    /// Writing FITS files is not supported.
    ///
    /// - Parameter configuration: The write configuration provided by SwiftUI.
    /// - Returns: Never returns normally.
    /// - Throws: Always throws ``RuntimeError`` because saving is unimplemented.
    public func fileWrapper( configuration: WriteConfiguration ) throws -> FileWrapper
    {
        throw RuntimeError( message: "Writing FITS files is not supported yet" )
    }
}
