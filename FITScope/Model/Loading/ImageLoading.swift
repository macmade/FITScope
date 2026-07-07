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

/// A format-specific loader that asynchronously parses a file into a
/// ``LoadedImage``, publishing the result or the failure for observers.
///
/// Each conformer owns the parse for one file format; ``ImageLoader``
/// selects the conformer for a given file's type, so ``OpenFile`` is independent
/// of any single format. The protocol is a plain class protocol rather than an
/// `ObservableObject` refinement so it can be held as `any ImageLoading`: the
/// pieces observers need — a change signal and the loaded-image stream — are
/// exposed as the concrete ``objectWillChange`` and ``imagePublisher`` rather
/// than through an `ObservableObject` associated type, which an existential
/// cannot vend.
@MainActor
public protocol ImageLoading: AnyObject
{
    /// The successfully loaded image, or `nil` before loading or after a failure.
    ///
    /// For a multi-frame file this is the primary (first) frame; ``frames`` holds
    /// the full list.
    var image: LoadedImage? { get }

    /// The frames the file decoded into, in display order — one per image the file
    /// holds. Single-image formats vend exactly one; a file that has not loaded (or
    /// failed) vends none. A multi-image format (a FITS cube, XISF, HEIC) overrides
    /// the default to vend one ``LoadedImage`` per contained image.
    var frames: [ LoadedImage ] { get }

    /// The error from the most recent failed load, or `nil` on success.
    var error: ( any Swift.Error )? { get }

    /// Emits the loaded image (or `nil`) whenever it changes, so observers can
    /// react to load completions and reloads without depending on a concrete
    /// `@Published` property.
    var imagePublisher: AnyPublisher< LoadedImage?, Never > { get }

    /// Notifies observers before the loader's published state changes. A conformer
    /// that is an `ObservableObject` satisfies this with its synthesized
    /// `objectWillChange`.
    var objectWillChange: ObservableObjectPublisher { get }

    /// Parses the file and publishes the resulting ``image``, or the ``error`` on
    /// failure. Successful loads are cached; a repeated call once an image exists
    /// is a no-op, while a prior failure still retries.
    func load() async
}

public extension ImageLoading
{
    /// The default single-frame derivation: a loaded image is the file's one and
    /// only frame; no image means no frames. Multi-image loaders override this to
    /// vend a frame per contained image.
    var frames: [ LoadedImage ]
    {
        self.image.map { [ $0 ] } ?? []
    }
}
