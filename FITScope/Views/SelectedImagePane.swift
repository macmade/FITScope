/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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

/// The center pane for one open file: triggers its load + render and shows the
/// rendered image fit-to-pane, a loading indicator, or an error.
public struct SelectedImagePane: View
{
    /// The file to display.
    @ObservedObject private var file: OpenFile

    /// Creates the pane.
    ///
    /// - Parameter file: The open file to display.
    public init( file: OpenFile )
    {
        self.file = file
    }

    /// The view's content.
    public var body: some View
    {
        ZStack
        {
            Color.black

            if let image = self.file.image
            {
                if let result = image.renderer.result
                {
                    Image( result.image, scale: 1.0, label: Text( self.file.displayName ) )
                        .resizable()
                        .aspectRatio( contentMode: .fit )
                }
                else if let error = image.renderer.error
                {
                    ErrorView( title: "Error Rendering Image", message: error.localizedDescription )
                }
                else
                {
                    LoadingView( title: "Rendering Image..." )
                }
            }
            else if let error = self.file.error
            {
                ErrorView( title: "Error Loading FITS File", message: error.localizedDescription )
            }
            else
            {
                LoadingView( title: "Loading FITS file..." )
            }
        }
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .task( id: self.file.id )
        {
            await self.file.load()
            await self.file.image?.renderer.render()
        }
    }
}
