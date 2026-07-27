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
import SwiftPixel
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
    /// failure. For a multi-image cube this is the primary (first) frame; ``frames``
    /// holds the full list.
    @Published public private( set ) var image: LoadedImage?

    /// The frames the file decoded into, in display order — one per image it holds.
    /// A single-image file (a 2-D image, an RGB colour cube) vends exactly one; a
    /// multi-image `NAXIS=3` cube vends one per plane, surfaced in the carousel.
    /// Empty before loading or after a failure. Overrides the ``ImageLoading``
    /// single-frame default with the real, decoded frame list.
    @Published public private( set ) var frames: [ LoadedImage ] = []

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

    /// Whether each image frame opens with an auto Screen Transfer applied on open —
    /// as an editable adjustment over the unstretched baseline (the per-format
    /// "auto-stretch on open" preference for FITS).
    private let autoStretch: Bool

    /// Creates a loader for the file at the given URL.
    ///
    /// - Parameters:
    ///   - url:         The URL the file is (or will be) read from.
    ///   - data:        The file's raw bytes when already in memory; when `nil` (the
    ///                 default) the loader reads them from `url` on load.
    ///   - autoStretch: Whether to open each image frame with an auto Screen Transfer
    ///                 applied as an editable adjustment over the unstretched
    ///                 baseline. Defaults to `false`.
    public init( url: URL, data: Data? = nil, autoStretch: Bool = false )
    {
        self.url          = url
        self.providedData = data
        self.autoStretch  = autoStretch
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

                        // A NAXIS=1 HDU is one-dimensional data, decoded here (while
                        // the non-Sendable file is in scope) into a Sendable series
                        // shown as a graph; `nil` for a normal image. The decode is
                        // best-effort: a genuine but undecodable 1-D HDU (bad BITPIX,
                        // truncated) yields `nil` and falls through to the raster path,
                        // so the file still loads with its metadata and surfaces the
                        // error at render — matching how a malformed 2-D file degrades.
                        let graph       = Self.decodeGraph( from: file.sections )

                        // The image HDU (bytes + header), selected the same way as the
                        // renderer; `nil` when the file carries no image data section.
                        // Whether it is an RGB colour-planes image tells the model to
                        // offer the colour controls even though it is not a CFA image.
                        // Frame enumeration and the detection image both go through the
                        // shared `FITSImageDecoder`: a multi-image NAXIS=3 cube yields one
                        // 2-D frame per plane (each a carousel frame), an RGB cube or a
                        // 2-D image yields one, and a graph's frame is rendered but
                        // carries no detection image. Whether the primary frame is an RGB
                        // colour image tells the model to offer the colour controls.
                        let imageFrames = ( try? FITSImageDecoder.frames( in: file ) ) ?? []
                        let isRGBImage  = imageFrames.first.map { FITSImageDecoder.channelCount( from: $0.properties ) == 3 } ?? false

                        // Each frame becomes a render source paired with the state it opens
                        // in (an auto Screen Transfer when the preference is on, else `nil`
                        // = unstretched linear).
                        let frames: [ ( source: Swift.Result< any ImageRenderSource, any Swift.Error >, opened: ImageProcessor.Settings? ) ]

                        if imageFrames.isEmpty
                        {
                            // No image data section (and not a graph); surface the failure
                            // at render time rather than failing the load.
                            let source = Swift.Result< any ImageRenderSource, any Swift.Error >
                            {
                                throw RuntimeError( message: "FITS file contains no image HDU" )
                            }

                            frames = [ ( source: source, opened: nil ) ]
                        }
                        else
                        {
                            frames = imageFrames.map
                            {
                                frame in

                                // Detection is best-effort — a decode failure must not fail
                                // the load — and only for a rendered image (a graph is never
                                // rendered and has no detection image).
                                let detectionImage = graph == nil ? ( try? FITSImageDecoder.detectionImage( of: frame ) ) : nil
                                let source         = FITSRenderSource( data: frame.data, properties: frame.properties, detectionImage: detectionImage )
                                let opened         = graph == nil ? Self.openedSettings( colorSource: source.autoStretchColorSource, fullScale: FITSImageDecoder.fullScale( from: frame.properties ), autoStretch: self.autoStretch ) : nil

                                return ( source: Swift.Result< any ImageRenderSource, any Swift.Error >.success( source ), opened: opened )
                            }
                        }

                        continuation.resume( returning: ( info: info, frames: frames, graph: graph, isRGBImage: isRGBImage ) )
                    }
                    catch
                    {
                        continuation.resume( throwing: error )
                    }
                }
            }

            await MainActor.run
            {
                // Each frame is an independent LoadedImage over its own render source;
                // they share the file's metadata (a cube has one header). The primary
                // frame is the first, and the loader forwards only its changes — the
                // owning OpenFile observes the selected frame separately.
                let frames = result.frames.map
                {
                    frame -> LoadedImage in

                    let renderer = ImageRenderer( source: frame.source, opened: frame.opened )

                    return LoadedImage( info: result.info, graph: result.graph, isRGBImage: result.isRGBImage, renderer: renderer )
                }

                let primary        = frames.first
                self.frames        = frames
                self.image         = primary
                self.error         = nil
                self.imageObserver = primary?.objectWillChange.sink
                {
                    [ weak self ] _ in self?.objectWillChange.send()
                }
            }
        }
        catch
        {
            self.image         = nil
            self.frames        = []
            self.error         = error
            self.imageObserver = nil
        }
    }

    /// The state an image frame opens in, layered over its unstretched baseline, or
    /// `nil` when it opens unstretched.
    ///
    /// When the auto-stretch-on-open preference is on, an auto Screen Transfer is
    /// derived — a per-channel one for a colour frame, a uniform one for a mono frame —
    /// so the frame opens stretched with the parameters pre-filled and editable in the
    /// inspector, while still resetting to the unstretched linear view. It is derived in
    /// the format's own domain: the native full-scale `[0, 1]` domain for an integer
    /// `BITPIX`, or the min/max domain for a floating-point one (which has no fixed full
    /// scale). Returns `nil` (opens linear) when the preference is off or the derivation
    /// fails.
    ///
    /// - Parameters:
    ///   - colorSource: The frame's per-channel colour input (a colour frame derives
    ///                  a per-channel STF, a mono frame a uniform one).
    ///   - fullScale:   The format's full-scale maximum, or `nil` for a floating-point
    ///                  format, which is derived over the min/max domain instead.
    ///   - autoStretch: Whether auto-stretch on open is enabled.
    /// - Returns: The opened settings, or `nil` to open on the unstretched baseline.
    private nonisolated static func openedSettings( colorSource: ImageProcessor.AutoStretchColorSource?, fullScale: Double?, autoStretch: Bool ) -> ImageProcessor.Settings?
    {
        guard autoStretch
        else
        {
            return nil
        }

        let domain = fullScale.map { ImageProcessor.AutoStretchDomain.fullScale( $0 ) } ?? .minMax

        return ImageProcessor.autoStretchSettings( colorSource: colorSource, domain: domain )
    }

    /// Decodes an image HDU into a graph series when it is graph data rather than a
    /// raster image, matching the HDU-selection rule of
    /// ``SwiftAstro/FITSImageDecoder/imageHDU(in:)`` (the first data section and its
    /// owning header). The graph path keeps its own two-line section selection
    /// because it needs the raw `FITSSection` to build a ``GraphSeries``, which the
    /// decoder's snapshot-based surface does not vend. A one-dimensional HDU
    /// (`NAXIS=1`) is always a graph; a two-dimensional
    /// HDU (`NAXIS=2`) is a graph only when it is a genuine stack of spectra (see
    /// ``GraphSeries/isSpectraStack(header:)``) — a normal 2-D image returns `nil` and
    /// the caller falls through to the raster path.
    ///
    /// The decode is best-effort: a genuine graph HDU that cannot be decoded (an
    /// unsupported `BITPIX`, truncated data) returns `nil` rather than throwing, so
    /// the caller falls through to the raster path — the file then loads with its
    /// metadata and surfaces the error at render time, matching a malformed 2-D file.
    ///
    /// - Parameter sections: The file's sections, in file order.
    /// - Returns: The decoded series for a decodable graph HDU, or `nil` otherwise.
    private nonisolated static func decodeGraph( from sections: [ FITSSection ] ) -> GraphSeries?
    {
        guard let dataIndex = sections.firstIndex( where: { $0.kind == .data } ), dataIndex > 0
        else
        {
            return nil
        }

        let header = sections[ dataIndex - 1 ]

        guard let data = try? sections[ dataIndex ].data
        else
        {
            return nil
        }

        guard let nAxis = header.naxis
        else
        {
            return nil
        }

        switch nAxis
        {
            case 1:

                return try? GraphSeries( oneDimensionalHeader: header, data: data )

            case 2 where GraphSeries.isSpectraStack( header: header ):

                return try? GraphSeries( stackedSpectraHeader: header, data: data )

            default:

                return nil
        }
    }
}
