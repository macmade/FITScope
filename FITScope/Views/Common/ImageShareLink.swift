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

import SwiftUI

/// The window-toolbar control that shares the selected file's *rendered* image
/// through the system share menu, as a JPEG.
///
/// It observes the file so the control enables as soon as a rendered result is
/// available, and re-encodes the current pixels each time the user shares — so
/// the shared image always reflects the latest adjustments. Until a result
/// exists there is nothing to share, so a disabled placeholder is shown rather
/// than a missing button, mirroring the *Export…* menu command.
struct ImageShareLink: View
{
    /// The file whose rendered image is shared. Observed, so the control
    /// re-validates when the render result commits.
    @ObservedObject var file: OpenFile

    /// The view's content.
    var body: some View
    {
        if let image = self.file.image?.renderer.result?.image
        {
            ShareLink(
                item:    RenderedImageShareItem( image: image, name: self.baseName ),
                preview: SharePreview( self.baseName, image: Image( image, scale: 1, label: Text( self.baseName ) ) )
            )
            .help( "Share Image" )
            .accessibilityIdentifier( AccessibilityIdentifier.MainWindowView.share )
        }
        else
        {
            Button
            {}
            label:
            {
                Image( systemName: "square.and.arrow.up" )
            }
            .disabled( true )
            .help( "Share Image" )
            .accessibilityIdentifier( AccessibilityIdentifier.MainWindowView.share )
        }
    }

    /// The file's display name without its extension, used as both the share
    /// preview title and the suggested file name's base.
    private var baseName: String
    {
        ( self.file.displayName as NSString ).deletingPathExtension
    }
}
