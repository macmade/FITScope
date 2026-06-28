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

/// The floating toolbar's plate-solve button. It owns its own appearance and
/// tooltip for each state — solving (pulsing), solved (tinted), or idle — so the
/// toolbar that hosts it needs no per-state knowledge.
///
/// It stays clickable while solving (``ImageToolbarButton/disablesWhileLoading``
/// is `false`), so the results window can be reopened mid-solve.
struct PlateSolveToolbarButton: View
{
    /// Whether the current image has a successful plate solve (tinted state).
    private let isSolved: Bool

    /// Whether a plate solve is currently running (pulsing state).
    private let isSolving: Bool

    /// The action performed on click.
    private let action: () -> Void

    /// Creates the plate-solve toolbar button.
    ///
    /// - Parameters:
    ///   - isSolved:  Whether the image has been solved.
    ///   - isSolving: Whether a solve is in progress.
    ///   - action:    The action performed on click.
    init( isSolved: Bool, isSolving: Bool, action: @escaping () -> Void )
    {
        self.isSolved  = isSolved
        self.isSolving = isSolving
        self.action    = action
    }

    /// The view's content.
    var body: some View
    {
        ImageToolbarButton(
            systemImage:          "point.3.connected.trianglepath.dotted",
            help:                 self.help,
            identifier:           AccessibilityIdentifier.ImageToolbarView.plateSolve,
            isActive:             self.isSolved,
            isLoading:            self.isSolving,
            disablesWhileLoading: false,
            action:               self.action
        )
    }

    /// The tooltip for the button's current state.
    private var help: String
    {
        if self.isSolving
        {
            return "Plate Solving\u{2026} \u{2014} Show Progress"
        }

        if self.isSolved
        {
            return "Plate Solved \u{2014} View Results or Solve Again"
        }

        return "Plate Solve with Astrometry.net"
    }
}

#Preview
{
    HStack
    {
        PlateSolveToolbarButton( isSolved: false, isSolving: false, action: {} )
        PlateSolveToolbarButton( isSolved: true,  isSolving: false, action: {} )
        PlateSolveToolbarButton( isSolved: false, isSolving: true,  action: {} )
    }
    .buttonStyle( .borderless )
    .padding()
    .background( .black )
}
