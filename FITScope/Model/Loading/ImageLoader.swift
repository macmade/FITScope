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
import UniformTypeIdentifiers

/// Selects the ``ImageLoading`` conformer that decodes a given file, so
/// ``OpenFile`` dispatches by type rather than hard-coding one format.
///
/// This is the single place a new format is wired in: as each format's loader is
/// added, its ``UTType`` gains a case here.
public enum ImageLoader
{
    /// Returns the loader that should decode the file at the given URL, chosen by
    /// the file's uniform type.
    ///
    /// A FITS file is routed to ``FITSImageLoader``; any other type resolves to an
    /// ``UnsupportedImageLoader`` that fails ``ImageLoading/load()`` with a clear
    /// error. The return is intentionally non-optional and non-throwing: the app
    /// accepts any file and reports failures *per file* (a dropped file always
    /// becomes an entry, then surfaces its error via ``OpenFile/warning``), so the
    /// unsupported case is a failing loader rather than a `nil`/`throw` the
    /// non-failable ``OpenFile``/``WindowModel`` would have to handle.
    ///
    /// As formats are added, each gains a case here keyed on its ``UTType``.
    ///
    /// - Parameter url: The file to load.
    /// - Returns: The loader for the file's type.
    @MainActor
    public static func loader( for url: URL ) -> any ImageLoading
    {
        let type = UTType( filenameExtension: url.pathExtension )

        if type?.conforms( to: .fits ) == true
        {
            return FITSImageLoader( url: url )
        }

        if type?.conforms( to: .xisf ) == true
        {
            return XISFImageLoader( url: url )
        }

        // Camera RAW decodes through SwiftRAW (LibRAW) into a linear sensor mosaic.
        // Checked before the photographic formats because a DNG also conforms to
        // `public.tiff`, and it must route to the RAW loader, not the ImageIO one.
        if type?.conforms( to: .rawImage ) == true
        {
            return RAWImageLoader( url: url )
        }

        // The photographic formats decode through the same ImageIO path. HEIC is a
        // container that may hold several images, which the loader surfaces as frames.
        if let type, [ .tiff, .png, .jpeg, .heic, .heif ].contains( where: { type.conforms( to: $0 ) } )
        {
            return ImageIOImageLoader( url: url )
        }

        return UnsupportedImageLoader( url: url )
    }
}
