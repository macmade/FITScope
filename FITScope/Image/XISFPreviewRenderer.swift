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

import CoreGraphics
import Foundation
import SwiftUtilities
import SwiftXISF

/// Renders an XISF file to a display-ready `CGImage` with the default processing
/// settings and no user adjustments — the XISF counterpart of ``FITSPreviewRenderer``.
///
/// Shared by the app and the QuickLook extensions so a Finder thumbnail/preview
/// matches what the app shows on open. It has no SwiftUI/AppKit dependencies, so it
/// compiles into the extension targets. A multi-image file previews its first image.
public enum XISFPreviewRenderer
{
    /// Renders the given XISF file bytes to a `CGImage` with default settings.
    ///
    /// - Parameter data: The raw XISF file bytes.
    /// - Returns: The rendered, display-ready image.
    /// - Throws: ``RuntimeError`` when the file contains no image, or any error
    ///   parsing the file or rendering the image.
    public static func render( data: Data ) throws -> CGImage
    {
        let file = try XISFFile( data: data, options: .lenient )

        guard let image = file.images.first
        else
        {
            throw RuntimeError( message: "XISF file contains no image" )
        }

        return try ImageProcessor.render( data: image.data, xisf: XISFImageProperties( image: image ) ).image
    }

    /// Reads and renders the XISF file at the given URL with default settings.
    ///
    /// - Parameter url: The XISF file to read and render.
    /// - Returns: The rendered, display-ready image.
    /// - Throws: Any error reading, parsing, or rendering the file.
    public static func render( contentsOf url: URL ) throws -> CGImage
    {
        try self.render( data: try Data( contentsOf: url ) )
    }
}
