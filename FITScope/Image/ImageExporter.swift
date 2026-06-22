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
import ImageIO
import UniformTypeIdentifiers

/// Encodes a rendered `CGImage` to a raster file using `ImageIO`.
///
/// This exports the *rendered* image (the display-ready pixels), not the
/// original FITS data — see ``OpenFile/copyOriginalFile(to:)`` for the latter.
public enum ImageExporter
{
    /// A raster image format the rendered image can be exported to.
    public enum Format: Equatable
    {
        /// Tagged Image File Format — lossless.
        case tiff

        /// Portable Network Graphics — lossless.
        case png

        /// JPEG, with a lossy compression quality in `0...1` (1 is best quality).
        case jpeg( quality: Double )

        /// The uniform type used both to encode the image and to drive the save
        /// panel's file extension.
        public var utType: UTType
        {
            switch self
            {
                case .tiff: return .tiff
                case .png:  return .png
                case .jpeg: return .jpeg
            }
        }
    }

    /// A failure encoding the image.
    public enum Failure: Error
    {
        /// `ImageIO` could not create a destination for the requested type.
        case destinationCreationFailed

        /// `ImageIO` could not finalize (write out) the encoded image.
        case encodingFailed
    }

    /// Encodes the image in the given format and returns the file bytes.
    ///
    /// - Parameters:
    ///   - image:  The rendered image to encode.
    ///   - format: The target format (and, for JPEG, its quality).
    /// - Returns: The encoded file contents.
    /// - Throws: ``Failure`` if `ImageIO` cannot create the destination or encode.
    public static func data( for image: CGImage, format: Format ) throws -> Data
    {
        let data = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData( data, format.utType.identifier as CFString, 1, nil )
        else
        {
            throw Failure.destinationCreationFailed
        }

        var properties: [ CFString: Any ] = [ : ]

        if case .jpeg( let quality ) = format
        {
            properties[ kCGImageDestinationLossyCompressionQuality ] = min( 1, max( 0, quality ) )
        }

        CGImageDestinationAddImage( destination, image, properties as CFDictionary )

        guard CGImageDestinationFinalize( destination )
        else
        {
            throw Failure.encodingFailed
        }

        return data as Data
    }

    /// Encodes the image in the given format and writes it to a file.
    ///
    /// - Parameters:
    ///   - image:  The rendered image to encode.
    ///   - format: The target format (and, for JPEG, its quality).
    ///   - url:    The destination file URL.
    /// - Throws: ``Failure`` on an encoding error, or any error thrown writing
    ///   the file.
    public static func write( _ image: CGImage, format: Format, to url: URL ) throws
    {
        try self.data( for: image, format: format ).write( to: url )
    }
}
