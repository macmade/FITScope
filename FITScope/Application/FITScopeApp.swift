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
import UniformTypeIdentifiers

/// The application entry point.
///
/// Declares the app's scenes: a `DocumentGroup` that opens FITS files into a
/// ``DocumentView``, an auxiliary window that shows a file's header properties
/// in an ``InfoView``, and a custom About window. The standard *About* menu item
/// is replaced with one that opens the app's own ``AboutView``.
@main
public struct FITScopeApp: App
{
    /// Opens an auxiliary window by identifier, used to present the custom About
    /// window.
    @Environment( \.openWindow ) private var openWindow

    /// Creates the application.
    public init()
    {}

    /// The app's scene graph.
    public var body: some Scene
    {
        WindowGroup
        {
            MainWindowView()
        }
        .windowStyle( .titleBar )
        .commands
        {
            CommandGroup( replacing: CommandGroupPlacement.appInfo )
            {
                Button( action: { openWindow( id: "AboutWindow" ) } )
                {
                    Text( "About \( Bundle.main.title )..." )
                }
            }
        }

        WindowGroup( id: "InfoWindow", for: FITSImageInfo.self )
        {
            if let info = $0.wrappedValue
            {
                InfoView( info: info )
                    .navigationTitle( info.url.lastPathComponent )
            }
            else
            {
                ErrorView( title: "No document loaded", message: nil )
                    .padding()
            }
        }
        .windowStyle( .titleBar )

        Window( "About \( Bundle.main.title )", id: "AboutWindow" )
        {
            AboutView()
                .padding()
                .fixedSize()
        }
        .windowStyle( .hiddenTitleBar )
        .windowResizability( .contentSize )
    }
}
