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

    /// Whether this row is the selected one, so the pill can switch to a white
    /// tint that reads against the selection highlight.
    private let isSelected: Bool

    /// The key the list is sorted by, which the pill reflects: a metric key shows
    /// that metric's value, the other keys show the weight.
    private let sortKey: FileSortKey

    /// Opens the auxiliary headers window.
    @Environment( \.openWindow ) private var openWindow

    /// Opens this row's file in a new window. Supplied by the sidebar.
    private let onOpenInNewWindow: () -> Void

    /// Saves a byte-identical copy of this row's original file. Supplied by the
    /// sidebar.
    private let onSaveAs: () -> Void

    /// Exports this row's rendered image (TIFF/PNG/JPEG). Supplied by the sidebar.
    private let onExport: () -> Void

    /// Reveals this row's file in Finder. Supplied by the sidebar.
    private let onRevealInFinder: () -> Void

    /// Moves this row's file to the Trash. Supplied by the sidebar.
    private let onMoveToTrash: () -> Void

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
    ///   - file:              The open file to display.
    ///   - isSelected:        Whether this row is the selected one.
    ///   - sortKey:           The key the list is sorted by, reflected by the pill.
    ///   - onOpenInNewWindow: Called when the user chooses "Open in New Window".
    ///   - onSaveAs:          Called when the user chooses "Save As…".
    ///   - onExport:          Called when the user chooses "Export…".
    ///   - onRevealInFinder:  Called when the user chooses "Reveal in Finder".
    ///   - onMoveToTrash:     Called when the user chooses "Move to Trash".
    ///   - onClose:           Called when the user chooses "Close".
    public init(
        file:              OpenFile,
        isSelected:        Bool = false,
        sortKey:           FileSortKey = .opened,
        onOpenInNewWindow: @escaping () -> Void = {},
        onSaveAs:          @escaping () -> Void = {},
        onExport:          @escaping () -> Void = {},
        onRevealInFinder:  @escaping () -> Void = {},
        onMoveToTrash:     @escaping () -> Void = {},
        onClose:           @escaping () -> Void = {}
    )
    {
        self.file              = file
        self.isSelected        = isSelected
        self.sortKey           = sortKey
        self.onOpenInNewWindow = onOpenInNewWindow
        self.onSaveAs          = onSaveAs
        self.onExport          = onExport
        self.onRevealInFinder  = onRevealInFinder
        self.onMoveToTrash     = onMoveToTrash
        self.onClose           = onClose
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

            if let pill = self.sortKey.pillText( for: self.file, formattedWeight: self.file.formattedWeight )
            {
                Pill(
                    pill,
                    tint:              self.isSelected ? .white : .accentColor,
                    backgroundOpacity: self.isSelected ? 0.25 : 0.15
                )
                .help( self.sortKey.pillTooltip )
                .accessibilityIdentifier( AccessibilityIdentifier.OpenFileRowView.weightPill )
            }

            if self.hasAdjustments
            {
                Image( systemName: "slider.horizontal.3" )
                    .font( .system( size: 11 ) )
                    .foregroundStyle( .secondary )
                    .help( "This image has adjustments applied." )
                    .accessibilityIdentifier( AccessibilityIdentifier.OpenFileRowView.adjustedMarker )
            }

            if let warning = self.file.warning
            {
                Image( systemName: "exclamationmark.triangle.fill" )
                    .help( warning )
            }
        }
        .padding( .vertical, 2 )
        .accessibilityElement( children: .contain )
        .accessibilityIdentifier( AccessibilityIdentifier.OpenFileRowView.row )
        .help( self.file.url.path )
        .contextMenu
        {
            Button( "Open in New Window" )
            {
                self.onOpenInNewWindow()
            }

            Button( "View FITS Headers" )
            {
                if let info = self.file.image?.info
                {
                    self.openWindow( id: "InfoWindow", value: info )
                }
            }
            .disabled( self.file.image?.info == nil )

            Divider()

            Button( "Save As\u{2026}" )
            {
                self.onSaveAs()
            }

            Button( "Export\u{2026}" )
            {
                self.onExport()
            }
            .disabled( self.file.image?.renderer.result == nil )

            Button( "Reveal in Finder" )
            {
                self.onRevealInFinder()
            }

            Divider()

            Button( "Move to Trash", role: .destructive )
            {
                self.onMoveToTrash()
            }

            Button( "Close", role: .destructive )
            {
                self.onClose()
            }
        }
    }

    /// Whether the row's image has any adjustment applied, so the row shows an
    /// "edited" marker. `false` before the image has loaded.
    private var hasAdjustments: Bool
    {
        self.file.hasAdjustments
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
