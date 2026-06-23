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
import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A rendered image packaged for the system share menu (`ShareLink`) as a JPEG.
///
/// Sharing encodes the *display-ready* pixels on demand — nothing is written
/// until the user actually shares — at the same quality the app uses for its
/// other JPEG output.
struct RenderedImageShareItem: Transferable
{
    /// The rendered, display-ready image to share.
    let image: CGImage

    /// The base file name, without extension, suggested to share targets.
    let name: String

    /// The JPEG quality used for the shared image (~90%), matching the export
    /// default.
    static let jpegQuality = 0.9

    /// The file name suggested to share targets, e.g. `M42.jpg`.
    var suggestedFileName: String
    {
        "\( self.name ).jpg"
    }

    /// Encodes the shared image as a ~90%-quality JPEG.
    ///
    /// - Returns: The JPEG file bytes.
    /// - Throws: Any error thrown by ``ImageExporter``.
    func jpegData() throws -> Data
    {
        try ImageExporter.data( for: self.image, format: .jpeg( quality: Self.jpegQuality ) )
    }

    static var transferRepresentation: some TransferRepresentation
    {
        DataRepresentation( exportedContentType: .jpeg )
        {
            try $0.jpegData()
        }
        .suggestedFileName
        {
            $0.suggestedFileName
        }
    }
}
