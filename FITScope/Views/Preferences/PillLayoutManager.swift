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

import AppKit

/// A layout manager that fills `.backgroundColor` ranges with a rounded "pill"
/// instead of the default rectangle, giving the ``FormulaTextView`` keyword
/// highlights their shape.
final class PillLayoutManager: NSLayoutManager
{
    /// The fill colour, kept so the rounded fill matches the requested tint.
    private let pillColor: NSColor

    /// Creates the layout manager.
    ///
    /// - Parameter pillColor: The pill fill colour.
    init( pillColor: NSColor )
    {
        self.pillColor = pillColor

        super.init()
    }

    /// Not supported — the manager is only created in code.
    ///
    /// - Parameter coder: Unused.
    required init?( coder: NSCoder )
    {
        nil
    }

    /// Draws each background rectangle as a horizontally-padded rounded capsule.
    ///
    /// - Parameters:
    ///   - rectArray: The rectangles to fill.
    ///   - rectCount: The number of valid rectangles.
    ///   - charRange: The character range being filled.
    ///   - color:     The requested fill colour.
    override func fillBackgroundRectArray( _ rectArray: UnsafePointer< NSRect >, count rectCount: Int, forCharacterRange charRange: NSRange, color: NSColor )
    {
        self.pillColor.setFill()

        ( 0 ..< rectCount ).forEach
        {
            let rect = rectArray[ $0 ].insetBy( dx: -3, dy: 1 )
            let path = NSBezierPath( roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2 )

            path.fill()
        }
    }
}
