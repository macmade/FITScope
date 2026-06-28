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
import SwiftUI

/// A multi-line formula editor that renders each valid ``WeightFormula``
/// placeholder as a rounded pill inline as the user types.
///
/// SwiftUI's `TextField` cannot style sub-ranges, so this wraps an AppKit
/// `NSTextView` built on a TextKit 1 stack whose ``PillLayoutManager`` draws the
/// rounded backgrounds. The bound ``text`` round-trips to the editor, and the
/// shared ``FormulaEditorController`` lets the palette insert keywords at the
/// caret.
struct FormulaTextView: NSViewRepresentable
{
    /// The formula text, two-way bound to the host.
    @Binding var text: String

    /// The controller the palette uses to insert keywords at the caret.
    let controller: FormulaEditorController

    /// The pill background tint, shared with ``KeywordPill`` (desaturated in dark
    /// mode).
    private static let pillColor = PillTint.background

    /// The keyword text colour, shared with ``KeywordPill``.
    private static let keywordColor = PillTint.foreground

    /// The editor's monospaced font, sized to match the placeholder pills' caption
    /// text.
    private static let font = NSFont.monospacedSystemFont( ofSize: NSFont.smallSystemFontSize, weight: .regular )

    /// Creates the coordinator that bridges editing back to SwiftUI.
    func makeCoordinator() -> Coordinator
    {
        Coordinator( self )
    }

    /// Builds the scrolling text view on a TextKit 1 stack with the pill layout
    /// manager.
    ///
    /// - Parameter context: The representable context.
    /// - Returns: The hosting scroll view.
    func makeNSView( context: Context ) -> NSScrollView
    {
        let textStorage   = NSTextStorage()
        let layoutManager = PillLayoutManager( pillColor: Self.pillColor )
        let container     = NSTextContainer()

        textStorage.addLayoutManager( layoutManager )
        layoutManager.addTextContainer( container )

        // The container does not track the text view's width and is unbounded in
        // both axes, so lines are never wrapped — long formulas scroll
        // horizontally instead.
        container.widthTracksTextView = false
        container.size                = NSSize( width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude )

        let textView                = NSTextView( frame: .zero, textContainer: container )
        textView.delegate           = context.coordinator
        textView.font               = Self.font
        textView.isRichText         = false
        textView.allowsUndo         = true
        textView.isAutomaticQuoteSubstitutionEnabled  = false
        textView.isAutomaticDashSubstitutionEnabled   = false
        textView.isAutomaticTextReplacementEnabled    = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize( width: 4, height: 6 )

        // Resizable in both axes with an unbounded max size, so the text view
        // grows with its content and both scrollers can engage (no wrapping).
        textView.isVerticallyResizable   = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask        = []
        textView.minSize                 = NSSize( width: 0, height: 0 )
        textView.maxSize                 = NSSize( width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude )
        textView.string                  = self.text

        self.controller.textView = textView
        context.coordinator.highlight( textView )

        let scrollView                   = NSScrollView()
        scrollView.documentView          = textView
        scrollView.hasVerticalScroller   = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers    = true
        scrollView.borderType            = .bezelBorder
        scrollView.drawsBackground       = true

        return scrollView
    }

    /// Syncs an external text change (e.g. "Restore Default") into the editor and
    /// re-applies highlighting.
    ///
    /// - Parameters:
    ///   - scrollView: The hosting scroll view.
    ///   - context:    The representable context.
    func updateNSView( _ scrollView: NSScrollView, context: Context )
    {
        guard let textView = scrollView.documentView as? NSTextView
        else
        {
            return
        }

        if textView.string != self.text
        {
            textView.string = self.text
            context.coordinator.highlight( textView )
        }
    }

    /// Bridges the `NSTextView`'s edits back to the SwiftUI binding and keeps the
    /// keyword highlighting current.
    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate
    {
        /// The owning representable.
        private let parent: FormulaTextView

        /// Creates the coordinator.
        ///
        /// - Parameter parent: The owning representable.
        init( _ parent: FormulaTextView )
        {
            self.parent = parent
        }

        /// Corrects keyword case, pushes edits to the binding, and re-highlights.
        ///
        /// - Parameter notification: The change notification.
        func textDidChange( _ notification: Notification )
        {
            guard let textView = notification.object as? NSTextView
            else
            {
                return
            }

            self.normalizeKeywordCase( textView )

            self.parent.text = textView.string

            self.highlight( textView )
        }

        /// Rewrites every recognized keyword to its canonical case (e.g. `fwhm` →
        /// `FWHM`) in place.
        ///
        /// Because a case-only correction preserves length, the caret and every
        /// other range stay put, so the edit is invisible apart from the casing.
        /// Done straight on the text storage (not through the text view's editing
        /// API) so it does not re-enter ``textDidChange(_:)``.
        ///
        /// - Parameter textView: The text view to normalize.
        private func normalizeKeywordCase( _ textView: NSTextView )
        {
            guard let storage = textView.textStorage
            else
            {
                return
            }

            let text       = storage.string
            let nsText     = text as NSString
            let mismatched = WeightFormula.keywordMatches( in: text ).filter { nsText.substring( with: $0.range ) != $0.name }

            guard mismatched.isEmpty == false
            else
            {
                return
            }

            let selection = textView.selectedRange()

            storage.beginEditing()
            mismatched.forEach { storage.replaceCharacters( in: $0.range, with: $0.name ) }
            storage.endEditing()

            textView.setSelectedRange( selection )
        }

        /// Tints every valid-keyword range as a pill and resets the rest to the
        /// default text colour.
        ///
        /// - Parameter textView: The text view to highlight.
        func highlight( _ textView: NSTextView )
        {
            guard let storage = textView.textStorage
            else
            {
                return
            }

            let whole = NSRange( location: 0, length: storage.length )

            storage.removeAttribute( .backgroundColor, range: whole )
            storage.addAttribute( .foregroundColor, value: NSColor.labelColor, range: whole )

            WeightFormula.validKeywordRanges( in: textView.string ).forEach
            {
                storage.addAttribute( .backgroundColor, value: FormulaTextView.pillColor, range: $0 )
                storage.addAttribute( .foregroundColor, value: FormulaTextView.keywordColor, range: $0 )
            }

            // New text typed after a pill must not inherit its colours.
            textView.typingAttributes =
                [
                    .font:            FormulaTextView.font,
                    .foregroundColor: NSColor.labelColor,
                ]
        }
    }
}
