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

/// A compact, borderless reset affordance: a small circular-arrow button that
/// restores a single control to its default.
///
/// Shared by the per-field slider resets, the inspector's per-section resets and
/// the Levels/Curves editors' per-channel resets, so the affordance looks and
/// behaves identically wherever a value can be reset. The caller decides when it
/// is shown (typically only when the value differs from its default) and attaches
/// any accessibility identifier.
public struct ResetButton: View
{
    /// The reset action, typically restoring one adjustment field to its default.
    private let action: () -> Void

    /// The tooltip shown on hover.
    private let help: String

    /// Creates a reset button.
    ///
    /// - Parameters:
    ///   - help:   The tooltip; defaults to a generic "Reset to Default".
    ///   - action: The reset action to perform when pressed.
    public init( help: String = "Reset to Default", action: @escaping () -> Void )
    {
        self.help   = help
        self.action = action
    }

    /// The view's content.
    public var body: some View
    {
        Button( action: self.action )
        {
            Image( systemName: "arrow.counterclockwise" )
                .imageScale( .small )
        }
        .buttonStyle( .borderless )
        .help( self.help )
    }
}

#Preview
{
    HStack( spacing: 16 )
    {
        ResetButton {}
        ResetButton( help: "Reset Brightness" ) {}
    }
    .padding()
}
