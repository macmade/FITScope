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

import Combine
import Foundation
import SwiftUtilities

/// The loader ``ImageLoader/loader(for:)`` returns for a file whose type no
/// registered format can decode.
///
/// It produces no image and, on ``load()``, surfaces a clear "unsupported format"
/// error — so an unsupported file is still opened as an entry and reports the
/// reason per file (via ``OpenFile/warning``), matching the app's behaviour for a
/// file that cannot be parsed, rather than the factory returning `nil` or throwing.
@MainActor
public final class UnsupportedImageLoader: ObservableObject, ImageLoading
{
    /// Always `nil` — an unsupported file produces no image.
    @Published public private( set ) var image: LoadedImage?

    /// The unsupported-format error, set once ``load()`` runs.
    @Published public private( set ) var error: ( any Swift.Error )?

    /// Emits the (always `nil`) image, bridging the `@Published` ``image``
    /// projection to the ``ImageLoading`` protocol.
    public var imagePublisher: AnyPublisher< LoadedImage?, Never >
    {
        self.$image.eraseToAnyPublisher()
    }

    /// The URL of the unsupported file, used to describe the error.
    private let url: URL

    /// Creates a loader for an unsupported file.
    ///
    /// - Parameter url: The URL of the file that cannot be decoded.
    public init( url: URL )
    {
        self.url = url
    }

    /// Surfaces the unsupported-format error; there is nothing to parse.
    public func load() async
    {
        let ext    = self.url.pathExtension
        let detail = ext.isEmpty ? "" : " (.\( ext ))"

        self.error = RuntimeError( message: "Unsupported file format\( detail )." )
    }
}
