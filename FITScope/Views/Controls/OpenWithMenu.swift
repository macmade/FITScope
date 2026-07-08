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
import UniformTypeIdentifiers

/// A reusable *Open With* submenu, shared by the *File* menu (``FileCommands``)
/// and the open-file context menu (``FileContextMenu``) so the two are
/// identical. It lists the applications the system associates with a file kind —
/// each with its Finder icon — followed by an *Other…* item that presents an
/// application chooser.
///
/// The candidate applications are enumerated lazily, inside the menu's content:
/// `Menu` builds its content only when it is opened, so the (main-thread)
/// LaunchServices query runs on demand rather than on every parent redraw.
public struct OpenWithMenu: View
{
    /// What to enumerate applications for.
    public enum Source
    {
        /// The applications that can open a specific file.
        case url( URL )

        /// The applications that can open a file of a given content type.
        case contentType( UTType )
    }

    /// The menu's title.
    private let title: String

    /// The SF Symbol shown beside the title.
    private let systemImage: String

    /// What the candidate applications are enumerated for.
    private let source: Source

    /// Opens the file with the chosen application.
    private let open: ( ExternalApplication ) -> Void

    /// Opens the file with a user-picked application (the *Other…* item).
    private let openOther: () -> Void

    /// Whether the menu is enabled, taken from the environment so a caller's
    /// `.disabled(…)` drives it. A submenu (`Menu`) in the macOS menu bar stays
    /// openable when only its items are disabled, so when disabled this renders a
    /// plain disabled button instead — which greys the whole entry as expected.
    @Environment( \.isEnabled ) private var isEnabled

    /// Creates an *Open With* submenu.
    ///
    /// - Parameters:
    ///   - title:       The menu's title.
    ///   - systemImage: The SF Symbol shown beside the title.
    ///   - source:      What to enumerate applications for.
    ///   - open:        Opens the file with the chosen application.
    ///   - openOther:   Opens the file with a user-picked application.
    public init( title: String, systemImage: String, source: Source, open: @escaping ( ExternalApplication ) -> Void, openOther: @escaping () -> Void )
    {
        self.title       = title
        self.systemImage = systemImage
        self.source      = source
        self.open        = open
        self.openOther   = openOther
    }

    /// The submenu: one item per candidate application (name + icon), a divider,
    /// then *Other…*. When disabled it collapses to a plain, greyed button so the
    /// whole entry reads as disabled rather than an openable submenu of disabled
    /// items.
    @ViewBuilder     public var body: some View
    {
        if self.isEnabled
        {
            self.menu
        }
        else
        {
            Button( action: {} )
            {
                Label( self.title, systemImage: self.systemImage )
            }
            .disabled( true )
        }
    }

    /// The enabled submenu.
    private var menu: some View
    {
        Menu
        {
            let applications = self.applications

            ForEach( applications )
            {
                application in

                Button
                {
                    self.open( application )
                }
                label:
                {
                    Label
                    {
                        Text( application.name )
                    }
                    icon:
                    {
                        Image( nsImage: application.icon ).renderingMode( .original )
                    }
                }
            }

            if applications.isEmpty == false
            {
                Divider()
            }

            Button( "Other\u{2026}" )
            {
                self.openOther()
            }
        }
        label:
        {
            Label( self.title, systemImage: self.systemImage )
        }
    }

    /// The candidate applications for the menu's source, de-duplicated and
    /// name-sorted. Evaluated inside the menu content, so it runs only when the
    /// menu is opened.
    private var applications: [ ExternalApplication ]
    {
        switch self.source
        {
            case .url( let url ):              return ExternalApplication.applications( toOpen: url )
            case .contentType( let contentType ): return ExternalApplication.applications( toOpen: contentType )
        }
    }
}

#Preview
{
    OpenWithMenu(
        title:       "Open Rendered Image With",
        systemImage: "photo",
        source:      .contentType( .tiff ),
        open:        { _ in },
        openOther:   {}
    )
    .padding()
}
