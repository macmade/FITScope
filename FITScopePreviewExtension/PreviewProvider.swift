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

import Cocoa
import Quartz
import UniformTypeIdentifiers

/// Provides Finder Quick Look previews for FITS files. It renders the file with
/// the app's default settings (no user adjustments) via the shared
/// ``FITSPreviewRenderer`` and returns the result as PNG data, so the spacebar
/// preview matches what the app shows on open.
///
/// This is a data-based preview (`QLIsDataBasedPreview` in the Info.plist), so
/// there is no view controller or nib.
class PreviewProvider: QLPreviewProvider, QLPreviewingController
{
    func providePreview( for request: QLFilePreviewRequest ) async throws -> QLPreviewReply
    {
        let image = try FITSPreviewRenderer.render( contentsOf: request.fileURL )
        let size  = CGSize( width: image.width, height: image.height )

        return QLPreviewReply( dataOfContentType: .png, contentSize: size )
        {
            _ in try ImageExporter.data( for: image, format: .png )
        }
    }
}
