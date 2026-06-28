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

/// Bridges the SwiftUI placeholder palette to the AppKit ``FormulaTextView`` so
/// clicking a keyword pill inserts that keyword into the formula at the caret.
///
/// The editor registers its text view here when it appears; the palette holds the
/// same controller and calls ``insert(_:)``.
@MainActor
public final class FormulaEditorController: ObservableObject
{
    /// The attached text view, set by ``FormulaTextView`` when it is created.
    /// Weak so the editor's lifetime is not extended by the controller.
    weak var textView: NSTextView?

    /// Creates a controller with no attached editor.
    public init()
    {}

    /// Inserts `keyword` at the current caret, replacing any selection.
    ///
    /// Routes the edit through the text view so undo and the change notification
    /// fire, keeping the bound formula text and the keyword highlighting in sync.
    /// Does nothing when no editor is attached.
    ///
    /// - Parameter keyword: The keyword to insert.
    public func insert( _ keyword: String )
    {
        guard let textView = self.textView
        else
        {
            return
        }

        textView.window?.makeFirstResponder( textView )
        textView.insertText( keyword, replacementRange: textView.selectedRange() )
    }
}
