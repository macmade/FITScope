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

/// The inspector column for a single open file.
///
/// Observes the file so the column updates as it loads: the adjustment
/// ``InspectorView`` once an image is available, an ``InspectorPlaceholderView``
/// on a load or render error, and an empty column while still loading. The file
/// is observed here — rather than inlined in the window — because its load state
/// is set asynchronously and would otherwise not refresh the column.
public struct InspectorColumnView: View
{
    /// The file being inspected.
    @ObservedObject private var file: OpenFile

    /// Creates the inspector column.
    ///
    /// - Parameter file: The open file to inspect.
    public init( file: OpenFile )
    {
        self.file = file
    }

    /// The view's content.
    public var body: some View
    {
        if let image = self.file.image
        {
            // Tie the inspector's identity to the image, so switching the selected
            // file recreates the controls rather than reusing them. Each control's
            // @State mirrors the image's adjustments and is seeded from it at init;
            // a reused control would keep the previous image's state (e.g. gamma
            // still shown as enabled). A new identity discards that and reseeds.
            InspectorView( image: image )
                .id( ObjectIdentifier( image ) )
        }
        else if self.file.error != nil
        {
            ScrollView
            {
                InspectorPlaceholderView()
            }
        }
        else
        {
            Color.clear
        }
    }
}

#Preview
{
    if let file = PreviewHelper.openFile( file: .M42 )
    {
        InspectorColumnView( file: file )
            .frame( width: 255 )
            .task
            {
                await file.load()
            }
    }
    else
    {
        Text( "Sample file unavailable." )
    }
}
