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

/// A single control in the floating image toolbar: an SF Symbol with a
/// consistent hit area, a tooltip and a stable accessibility identifier.
///
/// One control covers every state the toolbar needs, so the buttons stay visually
/// consistent and no per-state copy is duplicated at the call site:
///
/// - a plain action button (the default),
/// - a toggle that tints with the accent colour while ``isActive``,
/// - a disabled button (``isEnabled`` is `false`),
/// - a ``isLoading`` button that disables itself and gently pulses its icon to
///   signal background work — e.g. an overlay whose data is still being computed.
///
/// The idle appearance is the borderless default (it sets no foreground style
/// when inactive), so every button matches regardless of which states it uses.
public struct ImageToolbarButton: View
{
    /// The SF Symbol shown on the button.
    private let systemImage: String

    /// The tooltip shown on hover.
    private let help: String

    /// The stable accessibility identifier.
    private let identifier: String

    /// Whether the button responds to clicks. A loading button is always
    /// non-interactive regardless of this.
    private let isEnabled: Bool

    /// Whether the button is in its "on" state, tinting the icon with the accent
    /// colour. Used by toggles.
    private let isActive: Bool

    /// Whether the button is showing background work: its icon pulses until the
    /// work completes (and, unless ``disablesWhileLoading`` is `false`, it is
    /// disabled).
    private let isLoading: Bool

    /// Whether a ``isLoading`` button is also disabled. `true` for work the button
    /// can't be re-invoked during (an overlay still computing); `false` when the
    /// button stays actionable while busy (e.g. a plate solve whose progress
    /// window can be reopened mid-solve).
    private let disablesWhileLoading: Bool

    /// The action performed on click.
    private let action: () -> Void

    /// Creates a toolbar button.
    ///
    /// - Parameters:
    ///   - systemImage: The SF Symbol to show.
    ///   - help:        The tooltip shown on hover.
    ///   - identifier:  The stable accessibility identifier.
    ///   - isEnabled:   Whether the button responds to clicks. Defaults to `true`.
    ///   - isActive:    Whether to tint the icon as "on". Defaults to `false`.
    ///   - isLoading:   Whether to show the pulsing loading state. Defaults to
    ///                  `false`.
    ///   - disablesWhileLoading: Whether a loading button is also disabled.
    ///                  Defaults to `true`.
    ///   - action:      The action performed on click.
    public init( systemImage: String, help: String, identifier: String, isEnabled: Bool = true, isActive: Bool = false, isLoading: Bool = false, disablesWhileLoading: Bool = true, action: @escaping () -> Void )
    {
        self.systemImage          = systemImage
        self.help                 = help
        self.identifier           = identifier
        self.isEnabled            = isEnabled
        self.isActive             = isActive
        self.isLoading            = isLoading
        self.disablesWhileLoading = disablesWhileLoading
        self.action               = action
    }

    /// The view's content.
    public var body: some View
    {
        let button = Button( action: self.action )
        {
            Image( systemName: self.systemImage )
                .frame( width: 26, height: 24 )
                .contentShape( Rectangle() )
                .symbolEffect( .pulse, options: .repeating, isActive: self.isLoading )
        }
        .help( self.help )
        .disabled( self.isEnabled == false || ( self.isLoading && self.disablesWhileLoading ) )
        .accessibilityIdentifier( self.identifier )

        // Tint only when active; otherwise inherit the borderless default so an
        // idle button matches the rest of the toolbar (setting a colour here is
        // what made the toggles render brighter than their neighbours).
        if self.isActive
        {
            button.foregroundStyle( Color.accentColor )
        }
        else
        {
            button
        }
    }
}

#Preview
{
    HStack
    {
        ImageToolbarButton( systemImage: "scope",    help: "Plain",    identifier: "preview.plain",    action: {} )
        ImageToolbarButton( systemImage: "minus",    help: "Disabled", identifier: "preview.disabled", isEnabled: false, action: {} )
        ImageToolbarButton( systemImage: "sparkles", help: "Active",   identifier: "preview.active",   isActive: true,   action: {} )
        ImageToolbarButton( systemImage: "sparkles", help: "Loading",  identifier: "preview.loading",  isLoading: true,  action: {} )
    }
    .buttonStyle( .borderless )
    .padding()
    .background( .black )
}
