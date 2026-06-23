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

/// The user's image-export choices, bound to the save panel's accessory view.
///
/// The picker selects a ``Kind`` (a plain, `Picker`-friendly enum); ``format``
/// projects it — together with ``jpegQuality`` — into the
/// ``ImageExporter/Format`` the encoder consumes.
@MainActor
public final class ImageExportOptions: ObservableObject
{
    /// A selectable output format. Distinct from ``ImageExporter/Format`` because
    /// that type carries JPEG's quality as an associated value, which a `Picker`
    /// tag cannot represent.
    public enum Kind: String, CaseIterable, Identifiable
    {
        case tiff
        case png
        case jpeg

        /// The stable identity for `ForEach`/`Picker`.
        public var id: String { self.rawValue }

        /// The label shown in the picker.
        public var title: String
        {
            switch self
            {
                case .tiff: return "TIFF"
                case .png:  return "PNG"
                case .jpeg: return "JPEG"
            }
        }

        /// The uniform type, used to drive the save panel's file extension.
        public var utType: UTType
        {
            switch self
            {
                case .tiff: return .tiff
                case .png:  return .png
                case .jpeg: return .jpeg
            }
        }
    }

    /// The selected output format.
    @Published public var kind: Kind = .tiff

    /// The JPEG quality in `0...1`, applied only when ``kind`` is ``Kind/jpeg``.
    @Published public var jpegQuality: Double = 0.9

    /// Creates the default options (PNG).
    public init()
    {}

    /// The format passed to ``ImageExporter``, folding in the JPEG quality.
    public var format: ImageExporter.Format
    {
        switch self.kind
        {
            case .tiff: return .tiff
            case .png:  return .png
            case .jpeg: return .jpeg( quality: self.jpegQuality )
        }
    }
}

/// The accessory view shown in the export save panel: a format dropdown and,
/// for JPEG only, a quality slider.
///
/// The quality slider is shown only when JPEG is selected; the hosting view is
/// configured to track its intrinsic content size so the save panel resizes as
/// the slider appears and disappears.
public struct ImageExportOptionsView: View
{
    /// The export choices this view edits.
    @ObservedObject private var options: ImageExportOptions

    /// Called when the format changes, so the host can update the save panel's
    /// allowed content type (and thus the file extension).
    private let onFormatChange: ( ImageExportOptions.Kind ) -> Void

    /// Creates the accessory view.
    ///
    /// - Parameters:
    ///   - options:        The export choices to edit.
    ///   - onFormatChange: Called with the new format when the picker changes.
    public init( options: ImageExportOptions, onFormatChange: @escaping ( ImageExportOptions.Kind ) -> Void )
    {
        self.options        = options
        self.onFormatChange = onFormatChange
    }

    /// The view's content.
    public var body: some View
    {
        VStack( alignment: .leading, spacing: 10 )
        {
            Picker( "Format:", selection: self.$options.kind )
            {
                ForEach( ImageExportOptions.Kind.allCases )
                {
                    Text( $0.title ).tag( $0 )
                }
            }
            .pickerStyle( .menu )

            if self.options.kind == .jpeg
            {
                HStack
                {
                    Text( "Quality:" )

                    Slider( value: self.$options.jpegQuality, minimumValue: 0, maximumValue: 1 )

                    Text( self.options.jpegQuality, format: .percent.precision( .fractionLength( 0 ) ) )
                        .monospacedDigit()
                        .frame( width: 42, alignment: .trailing )
                }
            }
        }
        .padding()
        .frame( width: 320 )
        .onChange( of: self.options.kind )
        {
            _, kind in self.onFormatChange( kind )
        }
    }
}
