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

    /// Creates a file row.
    ///
    /// - Parameter file: The open file to display.
    public init( file: OpenFile )
    {
        self.file = file
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
                        .overlay
                        {
                            if self.file.image == nil
                            {
                                ProgressView().controlSize( .small )
                            }
                        }
                }
            }
            .frame( width: 42, height: 30 )
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
        }
        .padding( .vertical, 2 )
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
