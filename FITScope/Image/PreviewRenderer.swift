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
import UniformTypeIdentifiers

/// Renders a supported file to a display-ready `CGImage` with default settings,
/// dispatching by format — the single entry the QuickLook thumbnail and preview
/// extensions use so both handle every format the app declares.
///
/// It selects the renderer by the file's uniform type (the same basis as the app's
/// ``ImageLoader``), so extension variants (`fits`/`fit`) resolve through type
/// conformance rather than a hard-coded list. Each supported format is matched
/// explicitly — XISF to ``XISFPreviewRenderer``, FITS to ``FITSPreviewRenderer`` —
/// and an unrecognized type throws rather than being silently treated as FITS.
/// Extension-safe (no SwiftUI/AppKit).
public enum PreviewRenderer
{
    /// Reads and renders the file at the given URL with default settings.
    ///
    /// - Parameter url: The file to read and render.
    /// - Returns: The rendered, display-ready image.
    /// - Throws: ``RuntimeError`` when the file's type is neither FITS nor XISF, or
    ///   any error reading, parsing, or rendering the file.
    public static func render( contentsOf url: URL ) throws -> CGImage
    {
        let type = UTType( filenameExtension: url.pathExtension )

        if type?.conforms( to: .xisf ) == true
        {
            return try XISFPreviewRenderer.render( contentsOf: url )
        }

        if type?.conforms( to: .fits ) == true
        {
            return try FITSPreviewRenderer.render( contentsOf: url )
        }

        throw RuntimeError( message: "Unsupported file type for preview: \( url.lastPathComponent )" )
    }
}
