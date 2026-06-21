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

import SwiftFITS
import SwiftPixel
import SwiftUI
import SwiftUtilities

/// Renders a FITS image HDU into a displayable image with histograms, applying
/// the user's ``ImageAdjustments`` and re-rendering on demand.
///
/// Rendering runs off the main actor and is generation-guarded so that rapid
/// re-renders (e.g. during a slider drag) cannot commit stale results. A failed
/// render keeps the last good image so controls stay usable while the user
/// adjusts away from a bad parameter.
@MainActor
public class FITSImageRenderer: ObservableObject
{
    /// The output of a successful render: the image plus its histograms and
    /// statistics.
    public struct Result
    {
        /// The rendered, display-ready image.
        public let image:      CGImage

        /// The RGB and luminance histograms of the rendered pixels.
        public let histogram:  Histogram

        /// Per-channel statistics derived from the histograms.
        public let statistics: HistogramStatistics
    }

    /// The histograms computed from a rendered image.
    ///
    /// Equality is by a per-instance identity, **not** by the bin contents. The
    /// bin arrays are large, and a value-based `==` makes SwiftUI's view-graph
    /// diffing deep-compare them on the main thread on every update — the cause
    /// of a beachball when switching between already-rendered images. Because the
    /// wrapper itself is `Equatable`, SwiftUI uses this cheap `==` and never
    /// recurses into the `SwiftPixel.Histogram` bins. Each render produces a new
    /// histogram with a new identity, so a genuinely new result still compares
    /// unequal and refreshes the views.
    public struct Histogram: Equatable
    {
        /// A per-instance identity used for cheap equality.
        public let id = UUID()

        /// The per-channel (red, green, blue) histogram.
        public let rgb:       SwiftPixel.Histogram

        /// The single-channel luminance histogram.
        public let luminance: SwiftPixel.Histogram

        public static func == ( lhs: Histogram, rhs: Histogram ) -> Bool
        {
            lhs.id == rhs.id
        }
    }

    /// Summary statistics for each histogram channel.
    public struct HistogramStatistics
    {
        /// Statistics for the red channel.
        public let red:       SwiftPixel.HistogramStatistics

        /// Statistics for the green channel.
        public let green:     SwiftPixel.HistogramStatistics

        /// Statistics for the blue channel.
        public let blue:      SwiftPixel.HistogramStatistics

        /// Statistics for the luminance channel.
        public let luminance: SwiftPixel.HistogramStatistics
    }

    /// A histogram paired with its statistics, used to retain the original,
    /// unprocessed image's distribution alongside the live processed result.
    public struct HistogramSet
    {
        /// The RGB and luminance histograms.
        public let histogram:  Histogram

        /// Per-channel statistics derived from the histograms.
        public let statistics: HistogramStatistics
    }

    /// The image HDU's bytes and header properties to render.
    ///
    /// A `Sendable` value type so it can cross the render concurrency boundary
    /// without sharing the non-`Sendable` `FITSFile`.
    public struct RenderInput: Sendable
    {
        /// The image HDU's raw pixel bytes.
        public let data:       Data

        /// The owning header's property snapshots, used to interpret the bytes.
        public let properties: [ FITSPropertySnapshot ]

        /// Creates a render input.
        ///
        /// - Parameters:
        ///   - data:       The image HDU's raw pixel bytes.
        ///   - properties: The owning header's property snapshots.
        public init( data: Data, properties: [ FITSPropertySnapshot ] )
        {
            self.data       = data
            self.properties = properties
        }
    }

    /// The most recent successful render, or `nil` before the first render.
    /// Retained across a subsequent failure.
    @Published public private( set ) var result: Result?

    /// The histogram of the original image — the file as captured, debayered if
    /// necessary, with no stretch, gamma or white balance — computed once on the
    /// first render and cached for the file's lifetime, or `nil` before then.
    @Published public private( set ) var original: HistogramSet?

    /// The error from the most recent failed render, or `nil` on success.
    @Published public private( set ) var error:  Error?

    /// Whether a render is currently in flight — set when a render claims its
    /// generation and cleared when the latest generation commits. Stays set
    /// across a re-render even though the previous result is retained, so the UI
    /// can show a processing state (sidebar spinner, status pill, disabled
    /// controls, canvas overlay) for every render, not just the first.
    @Published public private( set ) var isRendering = false

    /// The user-tunable adjustments driving the render. Bind controls to these
    /// and call ``scheduleReRender()`` to apply changes.
    public let adjustments = ImageAdjustments()

    /// How long to coalesce rapid re-render requests before rendering.
    private static let reRenderDebounce = Duration.milliseconds( 150 )

    /// The render input, or the error captured while extracting it from the
    /// file. Stored as a `Result` so an extraction failure surfaces at render
    /// time rather than at construction.
    private let input: Swift.Result< RenderInput, any Error >

    /// The in-flight debounced re-render, cancelled when a newer one is
    /// scheduled.
    private( set ) var pendingRender: Task< Void, Never >?

    /// Monotonic render counter. Each ``render()`` claims the next value at
    /// start; only the most recently claimed render may commit its outcome.
    private var currentRenderGeneration = 0

    /// Creates a renderer from a render input or the error captured while
    /// extracting it.
    ///
    /// - Parameter input: The render input, or the extraction failure.
    public init( input: Swift.Result< RenderInput, any Error > )
    {
        self.input = input
    }

    /// Creates a renderer from an already-extracted render input.
    ///
    /// - Parameter input: The image HDU's bytes and header properties.
    public convenience init( input: RenderInput )
    {
        self.init( input: .success( input ) )
    }

    /// Creates a renderer from a parsed file, extracting the first renderable
    /// image HDU. Any extraction failure is captured and surfaces at render
    /// time.
    ///
    /// - Parameter file: The parsed FITS file.
    public convenience init( file: FITSFile )
    {
        self.init( input: Swift.Result { try FITSImageRenderer.renderInput( from: file.sections ) } )
    }

    /// Selects the first renderable image HDU and snapshots it into a Sendable
    /// ``RenderInput``.
    ///
    /// FITS files may place the image in an extension following an empty
    /// primary header, and a header-only file has no data section at all.
    /// Rather than indexing a fixed position — which mis-pairs extension data
    /// with the primary header and traps on single-section files — find the
    /// first `.data` section and pair it with the header that owns it (the
    /// section immediately preceding it in file order).
    ///
    /// - Parameter sections: The file's sections, in file order.
    /// - Returns: The data bytes and owning-header property snapshots.
    /// - Throws: ``RuntimeError`` when the file contains no image data section.
    nonisolated static func renderInput( from sections: [ FITSSection ] ) throws -> RenderInput
    {
        guard let dataIndex = sections.firstIndex( where: { $0.kind == .data } ), dataIndex > 0
        else
        {
            throw RuntimeError( message: "FITS file contains no image HDU" )
        }

        let properties = sections[ dataIndex - 1 ].properties.map { FITSPropertySnapshot( name: $0.name, value: $0.value ) }

        return RenderInput( data: sections[ dataIndex ].data, properties: properties )
    }

    /// Renders the image with the current adjustments and commits the result.
    ///
    /// The pixel work and histogram/statistics computation run on a background
    /// queue; the outcome is committed through ``commit(_:generation:)`` so a
    /// render superseded by a newer one cannot overwrite it.
    public func render() async
    {
        let generation = self.nextRenderGeneration()

        do
        {
            let input         = try self.input.get()
            let settings      = self.adjustments.settings
            let needsOriginal = self.original == nil

            let outcome = try await withCheckedThrowingContinuation
            {
                ( continuation: CheckedContinuation< ( result: Result, original: Result? ), any Error > ) in

                DispatchQueue.global( qos: .userInitiated ).async
                {
                    do
                    {
                        // The original is the file as captured: a render with the
                        // default settings (linear normalization and debayer
                        // only). It does not depend on the user's adjustments, so
                        // it is computed once and reused thereafter.
                        let result   = try Self.makeResult( input: input, settings: settings )
                        let original = needsOriginal ? try Self.makeResult( input: input, settings: ImageProcessor.Settings() ) : nil

                        continuation.resume( returning: ( result, original ) )
                    }
                    catch
                    {
                        continuation.resume( throwing: error )
                    }
                }
            }

            if let original = outcome.original
            {
                self.original = HistogramSet( histogram: original.histogram, statistics: original.statistics )
            }

            self.commit( .success( outcome.result ), generation: generation )
        }
        catch
        {
            self.commit( .failure( error ), generation: generation )
        }
    }

    /// Renders the image with the given settings and computes its histograms and
    /// statistics. Pure and `nonisolated` so it can run off the main actor.
    ///
    /// - Parameters:
    ///   - input:    The image HDU bytes and header properties.
    ///   - settings: The render settings to apply.
    /// - Returns: The rendered image with its histograms and statistics.
    /// - Throws: Any error thrown by the pixel pipeline.
    private nonisolated static func makeResult( input: RenderInput, settings: ImageProcessor.Settings ) throws -> Result
    {
        let render             = try ImageProcessor.render( data: input.data, properties: input.properties, settings: settings )
        let rgbHistogram       = Benchmark.run( label: "Histogram (RGB)", output: Benchmarking.log ) { SwiftPixel.Histogram( bytes: render.bytes, channels: render.channels, mode: .rgb ) }
        let luminanceHistogram = Benchmark.run( label: "Histogram (L)",   output: Benchmarking.log ) { SwiftPixel.Histogram( bytes: render.bytes, channels: render.channels, mode: .luminance ) }
        let histogram          = Histogram( rgb: rgbHistogram, luminance: luminanceHistogram )
        let statistics         = HistogramStatistics(
            red:       Benchmark.run( label: "Statistics (R)", output: Benchmarking.log ) { SwiftPixel.HistogramStatistics( data: rgbHistogram.data[ 0 ] ) },
            green:     Benchmark.run( label: "Statistics (G)", output: Benchmarking.log ) { SwiftPixel.HistogramStatistics( data: rgbHistogram.data[ 1 ] ) },
            blue:      Benchmark.run( label: "Statistics (B)", output: Benchmarking.log ) { SwiftPixel.HistogramStatistics( data: rgbHistogram.data[ 2 ] ) },
            luminance: Benchmark.run( label: "Statistics (L)", output: Benchmarking.log ) { SwiftPixel.HistogramStatistics( data: luminanceHistogram.data[ 0 ] ) }
        )

        return Result( image: render.image, histogram: histogram, statistics: statistics )
    }

    /// Claims and returns the next render generation. Only the most recently
    /// claimed generation may ``commit(_:generation:)`` its outcome; earlier
    /// in-flight renders are superseded.
    ///
    /// Claiming a generation marks the renderer as in flight (``isRendering``);
    /// the matching ``commit(_:generation:)`` clears it.
    func nextRenderGeneration() -> Int
    {
        self.currentRenderGeneration += 1
        self.isRendering              = true

        return self.currentRenderGeneration
    }

    /// Commits a render outcome, but only while its generation is still the
    /// latest, so a superseded render — success or failure — cannot overwrite a
    /// newer result or resurrect a cleared error.
    ///
    /// On success the result is set and the error cleared; on failure the error
    /// is set and the last good result retained, so the image and its controls
    /// survive a bad parameter while the user adjusts away from it.
    func commit( _ outcome: Swift.Result< Result, any Error >, generation: Int )
    {
        guard generation == self.currentRenderGeneration
        else
        {
            return
        }

        switch outcome
        {
            case .success( let result ):
                self.result = result
                self.error  = nil

            case .failure( let error ):
                self.error = error
        }

        // The latest render has committed, so nothing is in flight. A superseded
        // generation returns above without clearing the flag, so a newer render
        // still in progress keeps the processing state shown.
        self.isRendering = false
    }

    /// Re-renders the image with the current adjustments, debounced to coalesce
    /// rapid changes such as a slider drag. Any pending re-render is cancelled
    /// first, so only the latest settings are applied.
    public func scheduleReRender()
    {
        self.pendingRender?.cancel()
        self.pendingRender = Task
        {
            [ weak self ] in

            try? await Task.sleep( for: Self.reRenderDebounce )

            guard Task.isCancelled == false
            else
            {
                return
            }

            await self?.render()
        }
    }

    /// Returns the render input (HDU bytes and header snapshots) for read-only
    /// uses such as decoding the raw value under the cursor.
    ///
    /// - Returns: The render input.
    /// - Throws: The extraction error captured at construction, if any.
    public func renderInputSnapshot() throws -> RenderInput
    {
        try self.input.get()
    }
}
