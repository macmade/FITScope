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

/// Provides Finder thumbnails for the supported formats (FITS, XISF) by rendering
/// them with the app's default settings (no user adjustments) via the shared
/// ``PreviewRenderer`` and drawing the result scaled to fit the requested size.
class ThumbnailProvider: QLThumbnailProvider
{
    override func provideThumbnail( for request: QLFileThumbnailRequest, _ handler: @escaping ( QLThumbnailReply?, Error? ) -> Void )
    {
        do
        {
            let image = try PreviewRenderer.render( contentsOf: request.fileURL )
            let size  = ThumbnailLayout.fittedSize( imageWidth: image.width, imageHeight: image.height, within: request.maximumSize )

            handler(
                QLThumbnailReply( contextSize: size )
                {
                    ( context: CGContext ) -> Bool in

                    // The context's backing store is `size × displayScale` pixels
                    // and is handed to us unscaled — its coordinate space is that
                    // full pixel extent — so fill `context.width × context.height`
                    // rather than the point-sized `size`. Drawing into `size`
                    // would place the image in the bottom-left corner at a
                    // fraction of the context and leave white margins on the top
                    // and right. Because `size` is aspect-fitted to the image,
                    // filling the whole context does not distort it.
                    let bounds = CGRect( x: 0, y: 0, width: context.width, height: context.height )

                    context.draw( image, in: bounds )

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
}
