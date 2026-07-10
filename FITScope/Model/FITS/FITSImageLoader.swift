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
                        let hdu         = try? FITSPreviewRenderer.imageHDU( from: file.sections )
                        let isRGBImage  = hdu.map { ImageProcessor.isRGBPlanes( properties: $0.properties ) } ?? false

                        // One render source per frame. A multi-image NAXIS=3 cube
                        // decodes into one 2-D source per plane (each becoming a
                        // carousel frame); everything else — a 2-D image, an RGB cube,
                        // a graph, or an unsupported geometry — is a single source.
                        let frameSources: [ Swift.Result< any ImageRenderSource, any Swift.Error > ]

                        if graph == nil, let hdu, let planeSources = Self.multiImageFrameSources( forImageHDU: hdu )
                        {
                            frameSources = planeSources.map { .success( $0 ) }
                        }
                        else
                        {
                            frameSources =
                                [
                                    Swift.Result
                                    {
                                        () -> any ImageRenderSource in

                                        guard let hdu
                                        else
                                        {
                                            throw RuntimeError( message: "FITS file contains no image HDU" )
                                        }

                                        // Build the detection-ready buffer here, while
                                        // the non-Sendable file is still in scope; only
                                        // the Sendable PixelBuffer crosses back. A decode
                                        // failure must not fail the load, so detection is
                                        // best-effort. A graph is never rendered and has
                                        // no detection image.
                                        let detectionImage = graph == nil ? Self.detectionImage( forImageHDU: hdu, file: file ) : nil

                                        return FITSRenderSource( data: hdu.data, properties: hdu.properties, detectionImage: detectionImage )
                                    },
                                ]
                        }

                        continuation.resume( returning: ( info: info, frameSources: frameSources, graph: graph, isRGBImage: isRGBImage ) )
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
                let frames = result.frameSources.map
                {
                    sourceResult -> LoadedImage in

                    let renderer = ImageRenderer( source: sourceResult )

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

    /// Decodes an image HDU into a graph series when it is graph data rather than a
    /// raster image, matching the HDU-selection rule of
    /// ``FITSPreviewRenderer/imageHDU(from:)`` (the first data section and its owning
    /// header). A one-dimensional HDU (`NAXIS=1`) is always a graph; a two-dimensional
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
        let data   = sections[ dataIndex ].data

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

    /// Builds the detection-ready single-channel linear image for the image HDU.
    ///
    /// An RGB `NAXIS=3` colour image combines its three planes into a single
    /// luminance channel (their per-pixel mean, in scaled-linear ADU) so star
    /// detection and the sky-background measurement run on the whole colour image
    /// rather than one plane; any other image goes through SwiftAstro's decoder
    /// (a monochrome frame as-is, a colour-filter array demosaiced to luminance).
    ///
    /// The decode is best-effort: any failure returns `nil` so the load still
    /// succeeds and detection is simply skipped.
    ///
    /// - Parameters:
    ///   - hdu:  The image HDU's bytes and header properties.
    ///   - file: The parsed FITS file, for the non-RGB decode path.
    /// - Returns: The detection image, or `nil` when it cannot be built.
    private nonisolated static func detectionImage( forImageHDU hdu: ( data: Data, properties: [ FITSPropertySnapshot ] ), file: FITSFile ) -> PixelBuffer?
    {
        // An RGB image must combine its planes into luminance; it never falls back
        // to SwiftAstro's decoder, which would read a NAXIS=3 file as if 2-D and
        // build the detection image from the first (red) plane alone. When the
        // luminance decode fails (truncated/invalid data), detection is skipped.
        if ImageProcessor.isRGBPlanes( properties: hdu.properties )
        {
            return ImageProcessor.rgbLinearLuminance( data: hdu.data, properties: hdu.properties ).flatMap
            {
                try? PixelBuffer( width: $0.width, height: $0.height, channels: 1, pixels: $0.samples, isNormalized: false )
            }
        }

        return try? FITSImageDecoder.detectionImage( from: file )
    }

    /// Builds one render source per plane for a multi-image `NAXIS=3` cube, or `nil`
    /// when the HDU is not such a cube (so the caller uses the single-source path).
    ///
    /// Each plane becomes a two-dimensional ``FITSRenderSource`` over its own byte
    /// slice, carrying a detection image built from that plane's scaled-linear
    /// samples (the whole-file decoder cannot address a single plane). The decode is
    /// best-effort: a plane whose detection image cannot be built simply has none, so
    /// star detection is skipped for that frame rather than failing the load.
    ///
    /// - Parameter hdu: The cube HDU's bytes and header properties.
    /// - Returns: One render source per plane, or `nil` when the HDU is not a
    ///   multi-image cube or no whole plane is present.
    private nonisolated static func multiImageFrameSources( forImageHDU hdu: ( data: Data, properties: [ FITSPropertySnapshot ] ) ) -> [ FITSRenderSource ]?
    {
        guard ImageProcessor.isMultiImageCube( properties: hdu.properties )
        else
        {
            return nil
        }

        let sources = ImageProcessor.cubePlanes( data: hdu.data, properties: hdu.properties ).map
        {
            plane -> FITSRenderSource in

            let detectionImage = ImageProcessor.linearImage( data: plane.data, properties: plane.properties ).flatMap
            {
                try? PixelBuffer( width: $0.width, height: $0.height, channels: 1, pixels: $0.samples, isNormalized: false )
            }

            return FITSRenderSource( data: plane.data, properties: plane.properties, detectionImage: detectionImage )
        }

        return sources.isEmpty ? nil : sources
    }
}
