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
import SwiftAstro
import SwiftFITS
import SwiftUI
import SwiftUtilities

/// Asynchronously parses a FITS file's bytes into a ``LoadedImage``, publishing
/// the result or the failure for a view to observe.
///
/// Parsing happens off the main actor; only the `Sendable` metadata and render
/// input cross back, so the non-`Sendable` `FITSFile` never escapes the
/// background work.
@MainActor
public class FITSImageLoader: ObservableObject, ImageLoading
{
    /// The successfully loaded image, or `nil` before loading or after a
    /// failure.
    @Published public private( set ) var image: LoadedImage?

    /// The error from the most recent failed load, or `nil` on success.
    @Published public private( set ) var error: ( any Swift.Error )?

    /// Emits the loaded image on every change, bridging the `@Published` ``image``
    /// projection to the ``ImageLoading`` protocol so it can be observed through
    /// `any ImageLoading`.
    public var imagePublisher: AnyPublisher< LoadedImage?, Never >
    {
        self.$image.eraseToAnyPublisher()
    }

    /// The URL the file is (or will be) read from, retained for metadata.
    private let url: URL

    /// The file's raw bytes when supplied already in memory (e.g. by tests). `nil`
    /// when the loader reads them from ``url`` itself.
    private let providedData: Data?

    /// Forwards the loaded image's change notifications to this object's
    /// observers.
    private var imageObserver: AnyCancellable?

    /// Creates a loader for the file at the given URL.
    ///
    /// - Parameters:
    ///   - url:  The URL the file is (or will be) read from.
    ///   - data: The file's raw bytes when already in memory; when `nil` (the
    ///          default) the loader reads them from `url` on load.
    public init( url: URL, data: Data? = nil )
    {
        self.url          = url
        self.providedData = data
        self.image        = nil
    }

    /// Parses the file's bytes and publishes the resulting image, or the error on
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

                        if let providedData = self.providedData
                        {
                            data = providedData
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
                        let renderInput = Swift.Result
                        {
                            () -> any ImageRenderSource in

                            // Build the detection-ready buffer here, while the
                            // non-Sendable file is still in scope; only the
                            // Sendable PixelBuffer crosses back. A decode failure
                            // must not fail the load, so detection is best-effort.
                            let detectionImage = try? FITSImageDecoder.detectionImage( from: file )

                            return try FITSRenderSource( sections: file.sections, detectionImage: detectionImage )
                        }

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
                let renderer       = ImageRenderer( source: result.renderInput )
                let image          = LoadedImage( info: result.info, renderer: renderer )
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
