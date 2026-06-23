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
import SwiftFITS
import SwiftUtilities

/// Renders a FITS file to a display-ready `CGImage` with the default processing
/// settings and no user adjustments.
///
/// This is the one place the "open a FITS file and show its default render"
/// logic lives, shared by the app's first render and the QuickLook extensions,
/// so a Finder thumbnail/preview matches what the app shows on open. It has no
/// SwiftUI/AppKit dependencies, so it compiles into the extension targets.
public enum FITSPreviewRenderer
{
    /// Selects the first renderable image HDU and returns its bytes paired with
    /// the owning header's property snapshots — the same selection rule the app's
    /// renderer uses (first `.data` section, paired with the header that precedes
    /// it in file order).
    ///
    /// - Parameter sections: The file's sections, in file order.
    /// - Returns: The image data bytes and owning-header property snapshots.
    /// - Throws: ``RuntimeError`` when the file contains no image data section.
    public static func imageHDU( from sections: [ FITSSection ] ) throws -> ( data: Data, properties: [ FITSPropertySnapshot ] )
    {
        guard let dataIndex = sections.firstIndex( where: { $0.kind == .data } ), dataIndex > 0
        else
        {
            throw RuntimeError( message: "FITS file contains no image HDU" )
        }

        let properties = sections[ dataIndex - 1 ].properties.map { FITSPropertySnapshot( name: $0.name, value: $0.value ) }

        return ( sections[ dataIndex ].data, properties )
    }

    /// Renders the given FITS file bytes to a `CGImage` with default settings.
    ///
    /// - Parameter data: The raw FITS file bytes.
    /// - Returns: The rendered, display-ready image.
    /// - Throws: Any error parsing the file or rendering the image.
    public static func render( data: Data ) throws -> CGImage
    {
        let file = try FITSFile( data: data, options: .lenient )
        let hdu  = try self.imageHDU( from: file.sections )

        return try ImageProcessor.render( data: hdu.data, properties: hdu.properties ).image
    }

    /// Reads and renders the FITS file at the given URL with default settings.
    ///
    /// - Parameter url: The FITS file to read and render.
    /// - Returns: The rendered, display-ready image.
    /// - Throws: Any error reading, parsing, or rendering the file.
    public static func render( contentsOf url: URL ) throws -> CGImage
    {
        try self.render( data: try Data( contentsOf: url ) )
    }
}
