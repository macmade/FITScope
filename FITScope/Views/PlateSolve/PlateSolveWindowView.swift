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
import SwiftUtilities

/// The plate-solving results window: resolves the live ``PlateSolveSession`` for
/// the file it was opened for and hands it to ``PlateSolveResultView``.
///
/// The window carries only the file's identifier (a value SwiftUI can restore);
/// the session itself lives on the ``AppModel`` so the long-running solve
/// survives the window opening, closing, and reopening.
public struct PlateSolveWindowView: View
{
    /// The identifier of the file being solved, supplied by the scene's value.
    private let fileID: OpenFile.ID?

    /// The app-wide model that owns the plate-solve sessions.
    @EnvironmentObject private var appModel: AppModel

    /// Creates the window view.
    ///
    /// - Parameter fileID: The identifier of the file to show the solve for.
    public init( fileID: OpenFile.ID? )
    {
        self.fileID = fileID
    }

    /// The view's content.
    public var body: some View
    {
        Group
        {
            if let fileID = self.fileID, let session = self.appModel.plateSolveSession( for: fileID )
            {
                PlateSolveResultView( session: session )
            }
            else
            {
                ErrorView( title: "No Plate Solve in Progress", message: "Start a plate solve from the image toolbar or the Image menu." )
                    .padding()
            }
        }
        // A fixed width with an intrinsic height, so the window adapts its height
        // to each phase's content (with `.windowResizability( .contentSize )` on
        // the scene).
        .frame( width: 430 )
        // The file name is shown in the window's content header instead of the
        // title bar, so the title bar stays a plain, generic label.
        .navigationTitle( "Plate Solve" )
        // Center the window when shown, matching the other auxiliary windows
        // (e.g. Preferences) — the system does not position this scene
        // declaratively.
        .background( WindowAccessor { $0.center() } )
    }
}

#Preview
{
    PlateSolveWindowView( fileID: nil )
        .environmentObject( AppModel() )
}
