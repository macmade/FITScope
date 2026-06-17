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
import SwiftFITS
import SwiftUI
import SwiftUtilities

/// Asynchronously parses a ``FITSDocument`` into a ``FITSImage``, publishing the
/// result or the failure for a view to observe.
///
/// Parsing happens off the main actor; only the `Sendable` metadata and render
/// input cross back, so the non-`Sendable` `FITSFile` never escapes the
/// background work.
@MainActor
public class FITSImageLoader: ObservableObject
{
    /// The successfully loaded image, or `nil` before loading or after a
    /// failure.
    @Published public private( set ) var image: FITSImage?

    /// The error from the most recent failed load, or `nil` on success.
    @Published public private( set ) var error: Error?

    /// The URL the document was loaded from, retained for metadata.
    private let url:           URL

    /// The document whose bytes are parsed, when the loader was created from a
    /// pre-read document. `nil` when the loader reads the URL itself.
    private let document:      FITSDocument?

    /// Forwards the loaded image's change notifications to this object's
    /// observers.
    private var imageObserver: AnyCancellable?

    /// Creates a loader for the given document.
    ///
    /// - Parameters:
    ///   - url:      The URL the document was loaded from.
    ///   - document: The document holding the raw FITS bytes.
    public init( url: URL, document: FITSDocument )
    {
        self.url      = url
        self.document = document
        self.image    = nil
    }

    /// Creates a loader that reads its own bytes from the given URL when loaded.
    ///
    /// - Parameter url: The URL to read and parse.
    public init( url: URL )
    {
        self.url      = url
        self.document = nil
        self.image    = nil
    }

    /// Parses the document and publishes the resulting image, or the error on
    /// failure.
    ///
    /// Successful loads are cached: a repeated call (e.g. a re-triggered
    /// `.task`) once an image exists is a no-op, while a prior failure still
    /// retries.
    public func load() async
    {
        // Parsing the file is expensive and its result is immutable, so once an
        // image has loaded successfully a repeated call (e.g. a re-triggered
        // `.task`) is a no-op. A prior failure leaves `image` nil and still
        // retries.
        if self.image != nil, self.error == nil
        {
            return
        }

        do
        {
            let result = try await withCheckedThrowingContinuation
            {
                continuation in DispatchQueue.global( qos: .userInitiated ).async
                {
                    do
                    {
                        // Build and consume the FITSFile entirely here: only the
                        // Sendable info and render input cross back to the main
                        // actor, so the non-Sendable file is released when this
                        // closure returns rather than living for the window.
                        let data: Data

                        if let document = self.document
                        {
                            data = document.data
                        }
                        else
                        {
                            let didAccess = self.url.startAccessingSecurityScopedResource()

                            defer
                            {
                                if didAccess
                                {
                                    self.url.stopAccessingSecurityScopedResource()
                                }
                            }

                            data = try Data( contentsOf: self.url )
                        }

                        let file        = try FITSFile( data: data, options: .lenient )
                        let info        = FITSImageInfo( url: self.url, file: file )
                        let renderInput = Swift.Result { try FITSImageRenderer.renderInput( from: file.sections ) }

                        continuation.resume( returning: ( info: info, renderInput: renderInput ) )
                    }
                    catch
                    {
                        continuation.resume( throwing: error )
                    }
                }
            }

            await MainActor.run
            {
                let renderer       = FITSImageRenderer( input: result.renderInput )
                let image          = FITSImage( info: result.info, renderer: renderer )
                self.image         = image
                self.error         = nil
                self.imageObserver = image.objectWillChange.sink
                {
                    [ weak self ] _ in self?.objectWillChange.send()
                }
            }
        }
        catch
        {
            self.image         = nil
            self.error         = error
            self.imageObserver = nil
        }
    }
}
