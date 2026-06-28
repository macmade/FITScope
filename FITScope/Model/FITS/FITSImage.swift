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
import SwiftUI
import SwiftUtilities

/// A loaded FITS image, pairing its header metadata with the renderer that
/// produces displayable pixels.
///
/// Acts as a façade: it re-publishes the renderer's `objectWillChange` so a view
/// observing the image refreshes when the rendered result changes, without
/// observing the renderer directly.
@MainActor
public class FITSImage: ObservableObject
{
    /// The file's header metadata, grouped into sections.
    @Published public private( set ) var info: FITSImageInfo

    /// The renderer that turns the image HDU into displayable pixels and
    /// histograms.
    @Published public private( set ) var renderer: FITSImageRenderer

    /// The detected stars and their aggregate metrics, populated asynchronously
    /// after the image loads. `nil` until detection has run, or when detection
    /// found nothing usable. Independent of the display pipeline, since detection
    /// uses the linear sensor values rather than the rendered image.
    @Published public private( set ) var starField: StarField?

    /// The image-wide signal-to-noise estimate, populated asynchronously alongside
    /// ``starField`` from the same linear detection image. `nil` until detection
    /// has run, or for a flat frame with no measurable noise. Feeds the per-image
    /// weight's `SNRWeight` term.
    @Published public private( set ) var signalToNoise: SignalToNoise?

    /// Whether star detection is currently running, so the UI can show progress.
    /// `true` only while ``detectStars()`` is in flight.
    @Published public private( set ) var isDetectingStars = false

    /// The image's histogram view options, kept here so each file retains its own
    /// histogram display choices across selection changes.
    public let histogramOptions = HistogramViewOptions()

    /// Forwards the renderer's change notifications to this object's observers.
    private var rendererObserver: AnyCancellable?

    /// Creates an image from its metadata and renderer, wiring up change
    /// forwarding.
    ///
    /// - Parameters:
    ///   - info:     The file's header metadata.
    ///   - renderer: The renderer for the image HDU.
    public init( info: FITSImageInfo, renderer: FITSImageRenderer )
    {
        self.info             = info
        self.renderer         = renderer
        self.rendererObserver = self.renderer.objectWillChange.sink
        {
            [ weak self ] _ in self?.objectWillChange.send()
        }
    }

    /// Runs star detection and noise estimation on the image's linear data and
    /// publishes the results.
    ///
    /// Both measurements derive from the same linear detection image, so they run
    /// together in one off-main-actor pass; only the published assignments happen
    /// here. Does nothing when the render input is unavailable.
    public func detectStars() async
    {
        guard let input = try? self.renderer.renderInputSnapshot()
        else
        {
            return
        }

        self.isDetectingStars = true

        defer
        {
            self.isDetectingStars = false
        }

        let detectionImage = input.detectionImage
        let analysis       = await Task.detached
        {
            (
                starField:     StarDetection.detectStars( in: detectionImage ),
                signalToNoise: SignalToNoise.estimate( in: detectionImage )
            )
        }
        .value

        self.starField     = analysis.starField
        self.signalToNoise = analysis.signalToNoise
    }
}
