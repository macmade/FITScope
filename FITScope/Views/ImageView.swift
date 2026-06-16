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

import SwiftFITS
import SwiftUI

/// Displays a rendered FITS image beside its adjustment controls.
///
/// Shows a loading indicator until the first render, then the image with the
/// ``ImageControlsView`` sidebar. A render error after a good image is surfaced
/// as a dismissible ``BannerView`` overlay (so the last good image stays
/// visible); an error before any image fills the pane with an ``ErrorView``.
public struct ImageView: View
{
    /// The renderer whose result and error this view observes.
    @ObservedObject private var renderer: FITSImageRenderer

    /// Whether the user dismissed the current render-error banner. Reset
    /// whenever a new error arrives.
    @State private var errorBannerDismissed = false

    /// Creates the image view.
    ///
    /// - Parameter renderer: The renderer to observe and trigger.
    public init( renderer: FITSImageRenderer )
    {
        self.renderer = renderer
    }

    /// The view's content.
    public var body: some View
    {
        VStack
        {
            if let result = self.renderer.result
            {
                HStack( alignment: .top, spacing: 0 )
                {
                    VStack( alignment: .center )
                    {
                        Image( result.image, scale: 1.0, label: Text( "FITS Image" ) )
                            .resizable()
                            .aspectRatio( contentMode: .fit )
                    }
                    .frame( maxWidth: .infinity, maxHeight: .infinity )
                    .background( .black )
                    .overlay( alignment: .top )
                    {
                        if let error = self.renderer.error, self.errorBannerDismissed == false
                        {
                            BannerView( title: "Error Rendering Image", message: error.localizedDescription, systemImage: "exclamationmark.triangle.fill", tint: .yellow )
                            {
                                self.errorBannerDismissed = true
                            }
                            .padding( 12 )
                        }
                    }

                    Divider()

                    ImageControlsView( adjustments: self.renderer.adjustments, reRender: { self.renderer.scheduleReRender() }, histogram: result.histogram, statistics: result.statistics )
                        .frame( width: 300 )
                        .padding()
                }
            }
            else if let error = self.renderer.error
            {
                ErrorView( title: "Error Rendering Image", message: error.localizedDescription )
                    .padding()
            }
            else
            {
                LoadingView( title: "Rendering Image..." )
                    .padding()
            }
        }
        .task
        {
            await self.renderer.render()
        }
        .onChange( of: self.renderer.error != nil )
        {
            _, hasError in

            if hasError
            {
                self.errorBannerDismissed = false
            }
        }
    }
}

#Preview
{
    VStack
    {
        if let file = PreviewHelper.file( file: .M42 )
        {
            ImageView( renderer: FITSImageRenderer( file: file ) )
        }
        else
        {
            ErrorView( title: "No Data", message: nil )
        }

        Divider()

        if let file = PreviewHelper.file( file: .HST_FOS )
        {
            ImageView( renderer: FITSImageRenderer( file: file ) )
        }
        else
        {
            ErrorView( title: "No Data", message: nil )
        }
    }
}
