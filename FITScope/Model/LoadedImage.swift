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
import SwiftPixel
import SwiftUI
import SwiftUtilities

/// A loaded image, pairing its format-neutral metadata with the renderer that
/// produces displayable pixels.
///
/// Acts as a façade: it re-publishes the renderer's `objectWillChange` so a view
/// observing the image refreshes when the rendered result changes, without
/// observing the renderer directly.
@MainActor
public class LoadedImage: ObservableObject
{
    /// The source file's URL.
    public let url: URL

    /// The file's metadata as the format-neutral grouped model the Info window
    /// consumes.
    public let metadata: ImageMetadata

    /// The world-coordinate system the astrometric overlays (north, grid) read, or
    /// `nil` when the image carries none.
    public let wcs: WorldCoordinateSystem?

    /// When the image was captured, or `nil` when unknown.
    public let observationDate: Date?

    /// The exposure time in seconds, or `nil` when unknown.
    public let exposureTime: Double?

    /// The observing site's geographic coordinate, or `nil` when unknown.
    public let coordinate: Coordinate?

    /// The imaged target's celestial coordinate — the sky position of the object
    /// being photographed — or `nil` when the image carries none. Distinct from
    /// ``coordinate``, which is the observing site on the ground.
    public let target: EquatorialCoordinate?

    /// The image's plate scale in arc-seconds per pixel, or `nil` when it cannot
    /// be derived.
    public let pixelScale: Double?

    /// Whether the image is a colour-filter-array (Bayer) image, so the inspector
    /// offers the debayer controls.
    public let isColorFilterArray: Bool

    /// A display-ready summary of the image's key metadata, for the sidebar Image
    /// Information panel and the file row, or `nil` when it cannot be built.
    public let information: ImageInformation?

    /// The renderer that turns the image into displayable pixels and histograms.
    @Published public private( set ) var renderer: ImageRenderer

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

    /// The robust sky-background estimate, measured on the same linear detection
    /// image but published independently of ``starField`` (the background is far
    /// cheaper, so it lands first). `nil` until the measurement has run, or when
    /// there is no usable image. Carries the background level and noise (in linear
    /// ADU) and their fractions of the frame's value range, which the Analysis tab
    /// surfaces as a relative sky-quality read-out. ``signalToNoise`` is derived
    /// from its noise, so the two share a single robust estimate.
    @Published public private( set ) var skyBackground: SkyBackground?

    /// Whether star detection is currently running, so the UI can show progress.
    /// `true` only while ``detectStars()`` is detecting stars.
    @Published public private( set ) var isDetectingStars = false

    /// Whether star detection has finished running at least once. Lets the UI tell
    /// "detection hasn't run" from "detection ran and found nothing" — both leave
    /// ``starField`` empty — so the stars overlay can warn about the latter.
    @Published public private( set ) var hasDetectedStars = false

    /// Whether the sky-background measurement has finished running at least once.
    /// Lets the UI tell "not measured yet" from "measured but unavailable" (a
    /// degenerate image) — both leave ``skyBackground`` `nil`. Set independently of
    /// ``hasDetectedStars``, since the two measurements run concurrently.
    @Published public private( set ) var hasMeasuredBackground = false

    /// The image's histogram view options, kept here so each file retains its own
    /// histogram display choices across selection changes.
    public let histogramOptions = HistogramViewOptions()

    /// Forwards the renderer's change notifications to this object's observers.
    private var rendererObserver: AnyCancellable?

    /// Creates a loaded image from its format-neutral metadata and renderer,
    /// wiring up change forwarding from the renderer.
    ///
    /// - Parameters:
    ///   - url:                The source file's URL.
    ///   - metadata:           The grouped, format-neutral metadata for the Info window.
    ///   - wcs:                The WCS metadata for astrometric overlays, or `nil`.
    ///   - observationDate:    When the image was captured, or `nil`.
    ///   - exposureTime:       The exposure time in seconds, or `nil`.
    ///   - coordinate:         The observing site's geographic coordinate, or `nil`.
    ///   - target:             The imaged target's celestial coordinate, or `nil`.
    ///   - pixelScale:         The plate scale in arc-seconds per pixel, or `nil`.
    ///   - isColorFilterArray: Whether the image is a colour-filter-array image.
    ///   - information:        The display-ready metadata summary, or `nil`.
    ///   - renderer:           The renderer for the image.
    public init( url: URL, metadata: ImageMetadata, wcs: WorldCoordinateSystem?, observationDate: Date?, exposureTime: Double?, coordinate: Coordinate?, target: EquatorialCoordinate?, pixelScale: Double?, isColorFilterArray: Bool, information: ImageInformation?, renderer: ImageRenderer )
    {
        self.url                = url
        self.metadata           = metadata
        self.wcs                = wcs
        self.observationDate    = observationDate
        self.exposureTime       = exposureTime
        self.coordinate         = coordinate
        self.target             = target
        self.pixelScale         = pixelScale
        self.isColorFilterArray = isColorFilterArray
        self.information        = information
        self.renderer           = renderer
        self.rendererObserver   = self.renderer.objectWillChange.sink
        {
            [ weak self ] _ in self?.objectWillChange.send()
        }
    }

    /// Runs star detection and the sky-background measurement on the image's linear
    /// data and publishes the results.
    ///
    /// The two run as concurrent off-main-actor passes and publish independently,
    /// so the cheaper background estimate appears as soon as it is ready rather than
    /// waiting for star detection to finish. Both read the same linear detection
    /// image. Does nothing when the render input is unavailable; awaits both before
    /// returning.
    public func detectStars() async
    {
        guard let input = try? self.renderer.renderSourceSnapshot()
        else
        {
            return
        }

        let detectionImage = input.detectionImage

        async let stars:      Void = self.detectStarField( in: detectionImage )
        async let background: Void = self.measureBackground( in: detectionImage )

        _ = await( stars, background )
    }

    /// Detects the stars on the linear image and publishes ``starField``,
    /// off the main actor, toggling ``isDetectingStars``/``hasDetectedStars``
    /// around the work.
    ///
    /// - Parameter image: The linear detection image.
    private func detectStarField( in image: PixelBuffer? ) async
    {
        self.isDetectingStars = true

        defer
        {
            self.isDetectingStars = false
            self.hasDetectedStars = true
        }

        self.starField = await Task.detached { StarDetection.detectStars( in: image ) }.value
    }

    /// Measures the sky background on the linear image and publishes it, off the
    /// main actor and independently of star detection, marking
    /// ``hasMeasuredBackground`` when done.
    ///
    /// ``signalToNoise`` is derived from the background's noise — the same robust
    /// estimate — rather than measured separately; a flat frame (zero noise) has no
    /// meaningful signal-to-noise, matching ``SignalToNoise/estimate(in:)``.
    ///
    /// - Parameter image: The linear detection image.
    private func measureBackground( in image: PixelBuffer? ) async
    {
        defer
        {
            self.hasMeasuredBackground = true
        }

        let background = await Task.detached { SkyBackground.estimate( in: image ) }.value

        self.skyBackground = background
        self.signalToNoise = background.flatMap { $0.noise > 0 ? SignalToNoise( noise: $0.noise ) : nil }
    }

    /// Resets every image adjustment to its default and re-renders.
    ///
    /// Shared by the inspector's Reset View button and the *Image* menu, so both
    /// use the one ``ImageAdjustments/reset()`` rather than each duplicating it.
    /// The inspector controls observe the adjustments, so they follow the reset on
    /// their own — no reseed signal needed.
    public func resetAdjustments()
    {
        self.renderer.adjustments.reset()

        self.renderer.scheduleReRender()
    }

    /// Toggles the photographic-negative inversion and re-renders.
    ///
    /// The inspector's Invert control observes the adjustments, so it follows a
    /// menu-driven toggle on its own — no reseed signal needed.
    public func toggleInvert()
    {
        self.renderer.adjustments.invert.toggle()

        self.renderer.scheduleReRender()
    }

    /// Rotates the image 90° counter-clockwise and re-renders.
    public func rotateLeft()
    {
        self.applyOrientation { $0.rotatedCounterClockwise() }
    }

    /// Rotates the image 90° clockwise and re-renders.
    public func rotateRight()
    {
        self.applyOrientation { $0.rotatedClockwise() }
    }

    /// Flips the image horizontally and re-renders.
    public func flipHorizontal()
    {
        self.applyOrientation { $0.flippedHorizontally() }
    }

    /// Flips the image vertically and re-renders.
    public func flipVertical()
    {
        self.applyOrientation { $0.flippedVertically() }
    }

    /// Composes a screen-relative transform onto the current orientation and
    /// re-renders. The orientation control holds no state of its own, so it needs
    /// no re-sync when the orientation is changed from the menu.
    ///
    /// - Parameter transform: The orientation transform to compose on.
    private func applyOrientation( _ transform: ( Processors.Orient.Orientation ) -> Processors.Orient.Orientation )
    {
        self.renderer.adjustments.orientation = transform( self.renderer.adjustments.orientation )

        self.renderer.scheduleReRender()
    }
}
