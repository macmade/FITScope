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

/// A single row in the files sidebar: a thumbnail placeholder, the file name,
/// and a one-line metadata summary (`FITS • 16-bit • W × H`).
public struct OpenFileRowView: View
{
    /// The file this row represents.
    @ObservedObject private var file: OpenFile

    /// Opens the auxiliary headers window.
    @Environment( \.openWindow ) private var openWindow

    /// Closes this row's file. Supplied by the sidebar.
    private let onClose: () -> Void

    /// Creates a file row.
    ///
    /// The context menu lives here, rather than on the row in the sidebar's list,
    /// so it observes ``file``: its "View FITS Headers" item is enabled as soon as
    /// the image's header info becomes available. Placed on the non-observing
    /// sidebar, the item's disabled state would be evaluated once (while the image
    /// is still loading) and never refresh.
    ///
    /// - Parameters:
    ///   - file:    The open file to display.
    ///   - onClose: Called when the user chooses "Close" from the context menu.
    public init( file: OpenFile, onClose: @escaping () -> Void = {} )
    {
        self.file    = file
        self.onClose = onClose
    }

    /// The view's content.
    public var body: some View
    {
        HStack( spacing: 9 )
        {
            Group
            {
                if let thumbnail = self.file.thumbnail
                {
                    Image( thumbnail, scale: 1.0, label: Text( self.file.displayName ) )
                        .resizable()
                        .aspectRatio( contentMode: .fill )
                }
                else
                {
                    RoundedRectangle( cornerRadius: 5 )
                        .fill( Color( .windowBackgroundColor ) )
                }
            }
            .frame( width: 42, height: 30 )
            .overlay
            {
                // Shown while loading and on every re-render. During a re-render
                // the file already has a thumbnail, so this dims it and spins
                // over the top rather than only filling an empty placeholder.
                if self.file.renderPhase.isInProgress
                {
                    ZStack
                    {
                        Color.black.opacity( 0.35 )
                        ProgressView().controlSize( .small )
                    }
                }
            }
            .clipShape( RoundedRectangle( cornerRadius: 5 ) )

            VStack( alignment: .leading, spacing: 2 )
            {
                Text( self.file.displayName )
                    .lineLimit( 1 )
                    .truncationMode( .middle )
                    .font( .system( size: 12 ) )

                Text( self.metadataSummary )
                    .foregroundStyle( .secondary )
                    .font( .system( size: 10 ) )
            }

            Spacer( minLength: 0 )

            if let warning = self.file.warning
            {
                Image( systemName: "exclamationmark.triangle.fill" )
                    .help( warning )
            }
        }
        .padding( .vertical, 2 )
        .accessibilityElement( children: .contain )
        .accessibilityIdentifier( AccessibilityIdentifier.OpenFileRowView.row )
        .contextMenu
        {
            Button( "View FITS Headers" )
            {
                if let info = self.file.image?.info
                {
                    self.openWindow( id: "InfoWindow", value: info )
                }
            }
            .disabled( self.file.image?.info == nil )

            Button( "Close", role: .destructive )
            {
                self.onClose()
            }
        }
    }

    /// A one-line summary derived from the loaded image's header, or a neutral
    /// placeholder while loading or on error.
    private var metadataSummary: String
    {
        guard let info = self.file.image?.info,
              let summary = ImageInformation( info: info )
        else
        {
            return self.file.error == nil ? "Loading…" : "Failed to load"
        }

        return "FITS • \( summary.bitDepth ) • \( summary.dimensions )"
    }
}
