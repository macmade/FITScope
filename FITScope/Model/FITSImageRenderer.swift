/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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

@MainActor
public class FITSImageRenderer: ObservableObject
{
    public struct Result
    {
        public let image:      CGImage
        public let histogram:  Histogram
        public let statistics: HistogramStatistics
    }

    public struct Histogram
    {
        public let rgb:       SwiftPixel.Histogram
        public let luminance: SwiftPixel.Histogram
    }

    public struct HistogramStatistics
    {
        public let red:       SwiftPixel.HistogramStatistics
        public let green:     SwiftPixel.HistogramStatistics
        public let blue:      SwiftPixel.HistogramStatistics
        public let luminance: SwiftPixel.HistogramStatistics
    }

    /// The image HDU's bytes and header properties to render.
    ///
    /// A `Sendable` value type so it can cross the render concurrency boundary
    /// without sharing the non-`Sendable` `FITSFile`.
    public struct RenderInput: Sendable
    {
        public let data:       Data
        public let properties: [ FITSPropertySnapshot ]

        public init( data: Data, properties: [ FITSPropertySnapshot ] )
        {
            self.data       = data
            self.properties = properties
        }
    }

    @Published public private( set ) var result: Result?
    @Published public private( set ) var error:  Error?

    /// The user-tunable adjustments driving the render. Bind controls to these
    /// and call ``scheduleReRender()`` to apply changes.
    public let adjustments = ImageAdjustments()

    /// How long to coalesce rapid re-render requests before rendering.
    private static let reRenderDebounce = Duration.milliseconds( 150 )

    private let input: Swift.Result< RenderInput, any Error >

    private( set ) var pendingRender: Task< Void, Never >?

    /// Monotonic render counter. Each ``render()`` claims the next value at
    /// start; only the most recently claimed render may commit its outcome.
    private var currentRenderGeneration = 0

    public init( input: Swift.Result< RenderInput, any Error > )
    {
        self.input = input
    }

    public convenience init( input: RenderInput )
    {
        self.init( input: .success( input ) )
    }

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

    public func render() async
    {
        let generation = self.nextRenderGeneration()

        do
        {
            let input    = try self.input.get()
            let settings = self.adjustments.settings
            let result   = try await withCheckedThrowingContinuation
            {
                continuation in DispatchQueue.global( qos: .userInitiated ).async
                {
                    do
                    {
                        let render              = try ImageProcessor.render( data: input.data, properties: input.properties, settings: settings )
                        let rgbHistogram        = Benchmark.run( label: "Histogram (RGB)", output: Benchmarking.log ) { SwiftPixel.Histogram( bytes: render.bytes, channels: 3, mode: .rgb ) }
                        let luminanceHistogram  = Benchmark.run( label: "Histogram (L)",   output: Benchmarking.log ) { SwiftPixel.Histogram( bytes: render.bytes, channels: 3, mode: .luminance ) }
                        let redStatistics       = Benchmark.run( label: "Statistics (R)",  output: Benchmarking.log ) { SwiftPixel.HistogramStatistics( data: rgbHistogram.data[ 0 ] ) }
                        let greenStatistics     = Benchmark.run( label: "Statistics (G)",  output: Benchmarking.log ) { SwiftPixel.HistogramStatistics( data: rgbHistogram.data[ 1 ] ) }
                        let blueStatistics      = Benchmark.run( label: "Statistics (B)",  output: Benchmarking.log ) { SwiftPixel.HistogramStatistics( data: rgbHistogram.data[ 2 ] ) }
                        let luminanceStatistics = Benchmark.run( label: "Statistics (L)",  output: Benchmarking.log ) { SwiftPixel.HistogramStatistics( data: luminanceHistogram.data[ 0 ] ) }
                        let histogram           = Histogram( rgb: rgbHistogram, luminance: luminanceHistogram )
                        let statistics          = HistogramStatistics(
                            red:       redStatistics,
                            green:     greenStatistics,
                            blue:      blueStatistics,
                            luminance: luminanceStatistics
                        )

                        let result = Result(
                            image: render.image,
                            histogram: histogram,
                            statistics: statistics
                        )

                        continuation.resume( returning: result )
                    }
                    catch
                    {
                        continuation.resume( throwing: error )
                    }
                }
            }

            self.commit( .success( result ), generation: generation )
        }
        catch
        {
            self.commit( .failure( error ), generation: generation )
        }
    }

    /// Claims and returns the next render generation. Only the most recently
    /// claimed generation may ``commit(_:generation:)`` its outcome; earlier
    /// in-flight renders are superseded.
    func nextRenderGeneration() -> Int
    {
        self.currentRenderGeneration += 1

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
}
