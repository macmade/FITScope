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

/// Sizing for the Finder thumbnail drawn by the QuickLook thumbnail extension.
///
/// This is the one place the thumbnail's fit math lives, so it can be unit-
/// tested independently of the extension's QuickLook plumbing (the extension
/// itself is not reachable from the test target). It is compiled into both the
/// app and the thumbnail extension.
public enum ThumbnailLayout
{
    /// The context size to request for a rendered image's Finder thumbnail: the
    /// image scaled down to fit within QuickLook's requested maximum size while
    /// preserving its aspect ratio.
    ///
    /// The extension makes the reply's drawing context this size and then fills
    /// it with the image. Because the size carries the image's aspect ratio,
    /// filling the context leaves no margins and does not distort the image.
    ///
    /// - Parameters:
    ///   - imageWidth:  The rendered image's width in pixels.
    ///   - imageHeight: The rendered image's height in pixels.
    ///   - maximumSize: The largest thumbnail size QuickLook will accept.
    /// - Returns: The aspect-fitted thumbnail size, never larger than
    ///   `maximumSize` on either axis. Falls back to `maximumSize` when the
    ///   image has no positive dimensions.
    public static func fittedSize( imageWidth: Int, imageHeight: Int, within maximumSize: CGSize ) -> CGSize
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
