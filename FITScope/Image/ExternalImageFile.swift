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

/// Writes a rendered image to a temporary lossless TIFF so an external
/// application can open the *processed* image (as opposed to the original FITS
/// file).
///
/// The temp files live in a dedicated subdirectory of the system temporary
/// directory, and each write clears the previous one, so at most one such file
/// exists at a time and they never accumulate. The file is named after the
/// source so it reads meaningfully in the external app.
public enum ExternalImageFile
{
    /// The subdirectory, under the temporary directory, that holds the exported
    /// images handed to external applications.
    private static let directoryName = "OpenWith"

    /// The fallback base name used when the source has no usable base name.
    private static let fallbackName = "Image"

    /// The temporary file name for a rendered image, derived from the source
    /// file's name with a `.tiff` extension (e.g. `M31.fits` → `M31.tiff`).
    /// Falls back to a generic name when the source has no base name.
    ///
    /// - Parameter source: The source file's name.
    /// - Returns: The temporary file name.
    public static func fileName( forSource source: String ) -> String
    {
        let base = ( source as NSString ).deletingPathExtension
        let name = base.isEmpty ? self.fallbackName : base

        return "\( name ).tiff"
    }

    /// Writes the rendered image as a lossless TIFF into the temporary *Open
    /// With* directory, named after the source file, and returns its URL.
    ///
    /// Any previously written temp image is removed first, so the exported files
    /// do not accumulate: only the most recent one is kept on disk (the external
    /// app reads it once at launch).
    ///
    /// - Parameters:
    ///   - image:      The rendered image to write.
    ///   - sourceName: The source file's name, used to name the temp file.
    ///   - parent:     The directory to create the *Open With* subdirectory in.
    ///                 Defaults to the system temporary directory; injectable for
    ///                 testing.
    /// - Returns: The URL of the written TIFF.
    /// - Throws: Any error thrown creating the directory or encoding/writing the
    ///   image.
    @discardableResult
    public static func write( _ image: CGImage, sourceName: String, in parent: URL = FileManager.default.temporaryDirectory ) throws -> URL
    {
        let directory = self.directory( in: parent )

        // Clear any previous export so the temp files never pile up, then recreate
        // the directory fresh for this write.
        try? FileManager.default.removeItem( at: directory )
        try FileManager.default.createDirectory( at: directory, withIntermediateDirectories: true )

        let url = directory.appendingPathComponent( self.fileName( forSource: sourceName ) )

        try ImageExporter.write( image, format: .tiff, to: url )

        return url
    }

    /// Removes the temporary *Open With* directory and every export in it.
    ///
    /// Called when the app terminates, so the last handed-off image does not
    /// linger — `write(_:sourceName:in:)` only clears the *previous* export, so
    /// without this the final one would survive until the OS purged the temp
    /// directory. Best-effort and safe to call when nothing was ever written.
    ///
    /// - Parameter parent: The directory the *Open With* subdirectory lives in.
    ///                     Defaults to the system temporary directory.
    public static func removeTemporaryFiles( in parent: URL = FileManager.default.temporaryDirectory )
    {
        try? FileManager.default.removeItem( at: self.directory( in: parent ) )
    }

    /// The temporary *Open With* subdirectory inside `parent`.
    ///
    /// - Parameter parent: The directory the subdirectory lives in.
    /// - Returns: The subdirectory URL.
    private static func directory( in parent: URL ) -> URL
    {
        parent.appendingPathComponent( self.directoryName, isDirectory: true )
    }
}
