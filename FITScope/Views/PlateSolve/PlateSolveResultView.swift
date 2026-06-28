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

/// The plate-solve window's content: a ``PlateSolveHeaderView`` and, depending on
/// the ``PlateSolveSession`` phase, the in-progress detail, the solved
/// calibration and objects, or the failure / cancellation message.
///
/// Composed from dedicated subviews (``PlateSolveHeaderView``,
/// ``PlateSolveCalibrationView``, ``PlateSolveObjectsView``) so each stays small
/// and focused.
struct PlateSolveResultView: View
{
    /// The session whose progress and result are shown.
    @ObservedObject private var session: PlateSolveSession

    /// Creates the result view.
    ///
    /// - Parameter session: The session to observe.
    init( session: PlateSolveSession )
    {
        self.session = session
    }

    /// The view's content. The height is intrinsic so the window can size to it.
    var body: some View
    {
        VStack( alignment: .leading, spacing: 24 )
        {
            PlateSolveHeaderView( previewImage: self.session.previewImage, fileName: self.session.fileName, phase: self.session.phase )

            self.content
        }
        .padding( 20 )
        .frame( maxWidth: .infinity, alignment: .topLeading )
    }

    /// The phase-dependent body below the header.
    @ViewBuilder     private var content: some View
    {
        switch self.session.phase
        {
            case .loggingIn,
                 .uploading,
                 .solving:

                self.solving

            case .succeeded:

                self.results

            case .failed( let message ):

                self.message( message )

            case .cancelled:

                self.message( "The plate solve was cancelled before it finished." )
        }
    }

    /// The in-progress detail: an explanation and a cancel control.
    private var solving: some View
    {
        VStack( alignment: .leading, spacing: 12 )
        {
            Text( "Plate solving runs on nova.astrometry.net and can take a few minutes." )
                .font( .callout )
                .foregroundStyle( .secondary )
                .fixedSize( horizontal: false, vertical: true )

            Button( "Cancel" )
            {
                self.session.cancel()
            }
        }
    }

    /// The solved calibration, objects, and footer actions.
    @ViewBuilder     private var results: some View
    {
        if let result = self.session.result
        {
            PlateSolveCalibrationView( calibration: result.calibration )

            PlateSolveObjectsView( objects: result.objectsInField )

            HStack
            {
                if let url = result.resultsURL
                {
                    Link( "View on Astrometry.net", destination: url )
                }

                Spacer()

                Button( "Plate Solve Again" )
                {
                    self.session.restart()
                }
            }
        }
    }

    /// A neutral message with a re-solve control, for the failed and cancelled
    /// phases.
    ///
    /// - Parameter text: The message to show.
    private func message( _ text: String ) -> some View
    {
        VStack( alignment: .leading, spacing: 12 )
        {
            Text( text )
                .foregroundStyle( .secondary )
                .fixedSize( horizontal: false, vertical: true )

            Button( "Plate Solve Again" )
            {
                self.session.restart()
            }
        }
    }
}
