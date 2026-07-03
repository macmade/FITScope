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

/// The plate-solve window header: a small image preview alongside the file name
/// and the current status, the text block centred against the preview.
struct PlateSolveHeaderView: View
{
    /// A snapshot of the image being solved, or `nil` when none has rendered.
    private let previewImage: CGImage?

    /// The name of the file being solved.
    private let fileName: String

    /// The current solve phase, driving the status line.
    private let phase: PlateSolveSession.Phase

    /// The side length of the square preview thumbnail.
    private static let previewSize: CGFloat = 84

    /// Creates the header.
    ///
    /// - Parameters:
    ///   - previewImage: The image snapshot to preview.
    ///   - fileName:     The file's name.
    ///   - phase:        The current solve phase.
    init( previewImage: CGImage?, fileName: String, phase: PlateSolveSession.Phase )
    {
        self.previewImage = previewImage
        self.fileName     = fileName
        self.phase        = phase
    }

    /// The view's content.
    var body: some View
    {
        HStack( alignment: .center, spacing: 14 )
        {
            self.preview

            VStack( alignment: .leading, spacing: 10 )
            {
                Text( self.fileName )
                    .font( .headline )
                    .lineLimit( 2 )
                    .truncationMode( .middle )
                    // The file name is selectable/copyable; the status line below
                    // is transient UI, so it is left unselectable.
                    .textSelection( .enabled )

                self.status
            }

            Spacer( minLength: 0 )
        }
    }

    /// A small preview of the image being solved, or a placeholder.
    private var preview: some View
    {
        Group
        {
            if let image = self.previewImage
            {
                Image( decorative: image, scale: 1.0 )
                    .resizable()
                    .interpolation( .medium )
                    .aspectRatio( contentMode: .fit )
            }
            else
            {
                Image( systemName: "photo" )
                    .font( .system( size: 22 ) )
                    .foregroundStyle( .secondary )
            }
        }
        .frame( width: Self.previewSize, height: Self.previewSize )
        .background( .black )
        .clipShape( RoundedRectangle( cornerRadius: 6 ) )
        .overlay( RoundedRectangle( cornerRadius: 6 ).stroke( .white.opacity( 0.12 ) ) )
    }

    /// The status line: a spinner while solving, or a coloured outcome label.
    @ViewBuilder     private var status: some View
    {
        switch self.phase
        {
            case .loggingIn,
                 .uploading,
                 .solving:

                HStack( spacing: 6 )
                {
                    ProgressView()
                        .controlSize( .small )

                    Text( self.statusLabel )
                        .foregroundStyle( .secondary )
                        .accessibilityIdentifier( AccessibilityIdentifier.PlateSolveWindowView.status )
                }

            case .succeeded:

                Label( "Solved", systemImage: "checkmark.circle.fill" )
                    .foregroundStyle( .green )
                    .accessibilityIdentifier( AccessibilityIdentifier.PlateSolveWindowView.status )

            case .failed:

                Label( "Failed", systemImage: "exclamationmark.triangle.fill" )
                    .foregroundStyle( .orange )
                    .accessibilityIdentifier( AccessibilityIdentifier.PlateSolveWindowView.status )

            case .cancelled:

                Label( "Cancelled", systemImage: "xmark.circle" )
                    .foregroundStyle( .secondary )
                    .accessibilityIdentifier( AccessibilityIdentifier.PlateSolveWindowView.status )
        }
    }

    /// The label for the current in-progress phase.
    private var statusLabel: String
    {
        switch self.phase
        {
            case .loggingIn: return "Authenticating\u{2026}"
            case .uploading: return "Uploading image\u{2026}"
            case .solving:   return "Solving\u{2026}"
            default:         return ""
        }
    }
}

#Preview
{
    PlateSolveHeaderView( previewImage: nil, fileName: "M51.fits", phase: .solving )
        .padding()
        .frame( width: 430 )
}
