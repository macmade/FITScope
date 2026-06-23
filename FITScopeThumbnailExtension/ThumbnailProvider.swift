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
import QuickLookThumbnailing

/// Provides Finder thumbnails for FITS files by rendering them with the app's
/// default settings (no user adjustments) via the shared ``FITSPreviewRenderer``
/// and drawing the result scaled to fit the requested thumbnail size.
class ThumbnailProvider: QLThumbnailProvider
{
    override func provideThumbnail( for request: QLFileThumbnailRequest, _ handler: @escaping ( QLThumbnailReply?, Error? ) -> Void )
    {
        do
        {
            let image = try FITSPreviewRenderer.render( contentsOf: request.fileURL )
            let size  = Self.fittedSize( imageWidth: image.width, imageHeight: image.height, within: request.maximumSize )

            handler(
                QLThumbnailReply( contextSize: size )
                {
                    ( context: CGContext ) -> Bool in

                    context.draw( image, in: CGRect( origin: .zero, size: size ) )

                    return true
                },
                nil
            )
        }
        catch
        {
            handler( nil, error )
        }
    }

    /// Scales the image's dimensions down to fit within the requested maximum
    /// size while preserving its aspect ratio.
    ///
    /// - Parameters:
    ///   - imageWidth:  The rendered image's width in pixels.
    ///   - imageHeight: The rendered image's height in pixels.
    ///   - maximumSize: The largest thumbnail size QuickLook will accept.
    /// - Returns: The aspect-fitted thumbnail size.
    private static func fittedSize( imageWidth: Int, imageHeight: Int, within maximumSize: CGSize ) -> CGSize
    {
        guard imageWidth > 0, imageHeight > 0
        else
        {
            return maximumSize
        }

        let scale = min( maximumSize.width / CGFloat( imageWidth ), maximumSize.height / CGFloat( imageHeight ) )

        return CGSize( width: CGFloat( imageWidth ) * scale, height: CGFloat( imageHeight ) * scale )
    }
}
