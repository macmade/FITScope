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
@testable import FITScope
import Foundation
import SwiftAstro
import SwiftFITS
import SwiftPixel
import Testing

/// A star detector that blocks until released, so a test can hold ``LoadedImage``
/// in its running stage for as long as it needs.
///
/// The real detector finishes in milliseconds, which leaves the running stage too
/// brief to act on from outside — a test that tries to catch it is racing, and loses
/// often enough to be worthless. Substituting this one removes the race rather than
/// trying to win it: the stage persists until ``release()`` is called.
///
/// Blocking a cooperative-pool thread is safe here: only one is ever blocked, the
/// main actor is a separate executor and only ever suspends, and nothing the release
/// depends on runs on the pool — so the wait cannot starve what would end it.
private final class BlockingStarDetector: StarDetecting
{
    /// Signalled by ``release()`` to let a blocked detection finish.
    private let canFinish = DispatchSemaphore( value: 0 )

    /// Blocks until ``release()`` is called, then reports an empty star field.
    ///
    /// - Parameter image: The image to detect stars in, unused — this detector
    ///                    exists to control timing, not to detect anything.
    /// - Returns: An empty star field.
    func detectStars( in image: PixelBuffer ) throws -> StarField
    {
        self.canFinish.wait()

        return StarField( stars: [] )
    }

    /// Lets a blocked detection finish.
    func release()
    {
        self.canFinish.signal()
    }
}

/// Tests for ``LoadedImage``'s star-detection state: the in-progress flag covers
/// the whole wait — queued as well as running — while the has-run flag records
/// only a detection that actually completed.
@Suite( "LoadedImage" )
struct LoadedImageTests
{
    /// Builds a real, renderable ``LoadedImage`` from the mono fixture. Detection
    /// reads the renderer's source snapshot, which is available from construction,
    /// so no render is needed first.
    @MainActor
    private static func makeImage() throws -> LoadedImage
    {
        let url      = TestFixtures.monoImage
        let file     = try FITSFile( data: Data( contentsOf: url ), options: .lenient )
        let info     = FITSImageInfo( url: url, file: file )
        let renderer = ImageRenderer( file: file )

        return LoadedImage( info: info, renderer: renderer )
    }

    // MARK: - Star detection state

    /// Queueing detection reports it as in progress straight away, so the wait
    /// before it starts is not indistinguishable from idleness — without claiming a
    /// detection has run, which would let the stars overlay report that it ran and
    /// found nothing.
    @Test
    @MainActor
    func queueingDetectionReportsItInProgressWithoutRecordingARun() throws
    {
        let image = try Self.makeImage()

        #expect( image.markStarDetectionQueued(), "an idle image enters the queued stage" )

        #expect( image.isDetectingStars,                 "a queued detection reports as in progress" )
        #expect( image.hasDetectedStars == false,        "queueing must not claim detection has run" )
        #expect( image.markStarDetectionQueued() == false, "an image already queued does not queue again" )
    }

    /// Abandoning queued detection stops reporting it, and still records no run — so
    /// work that was dropped stays distinguishable from work that ran and found
    /// nothing.
    @Test
    @MainActor
    func abandoningQueuedDetectionStopsReportingItWithoutRecordingARun() throws
    {
        let image = try Self.makeImage()

        image.markStarDetectionQueued()

        // Pin the scenario: abandoning proves nothing unless something was queued.
        #expect( image.isDetectingStars, "the detection must be queued before it can be abandoned" )

        image.markStarDetectionAbandoned()

        #expect( image.isDetectingStars == false, "abandoned work is no longer in progress" )
        #expect( image.hasDetectedStars == false, "abandoned work must not claim detection has run" )
    }

    /// A detection that runs to completion stops reporting and records the run.
    @Test
    @MainActor
    func completedDetectionStopsReportingAndRecordsTheRun() async throws
    {
        let image = try Self.makeImage()

        await image.detectStars()

        #expect( image.isDetectingStars == false, "a finished detection is no longer in progress" )
        #expect( image.hasDetectedStars,          "a finished detection records that it ran" )
    }

    /// The queued → running → finished sequence: the flag stays set across the
    /// hand-off from queued to running rather than dropping in between, and the
    /// completed run is recorded.
    @Test
    @MainActor
    func detectionStaysInProgressFromQueueingUntilItFinishes() async throws
    {
        let image = try Self.makeImage()

        image.markStarDetectionQueued()

        #expect( image.isDetectingStars, "a queued detection reports as in progress" )

        await image.detectStars()

        #expect( image.isDetectingStars == false, "the flag clears once detection finishes" )
        #expect( image.hasDetectedStars,          "the completed detection is recorded" )
    }

    /// A late abandon, after detection has already finished, leaves the recorded run
    /// intact rather than erasing it.
    @Test
    @MainActor
    func abandoningAfterDetectionFinishedLeavesTheRecordedRunIntact() async throws
    {
        let image = try Self.makeImage()

        await image.detectStars()

        #expect( image.hasDetectedStars, "the detection must have run before a late abandon means anything" )

        image.markStarDetectionAbandoned()

        #expect( image.hasDetectedStars,          "a late abandon must not erase a completed detection" )
        #expect( image.isDetectingStars == false, "a late abandon leaves the flag clear" )
    }

    /// Detection passes through the running stage on its way to finished, so an
    /// image detecting without having been queued first still reports in progress
    /// while it works. Observed through the published phase rather than by racing the
    /// work, so there is nothing to win or lose.
    @Test
    @MainActor
    func detectionPassesThroughRunningOnItsWayToFinished() async throws
    {
        let image = try Self.makeImage()

        var phases: [ LoadedImage.StarDetectionPhase ] = []

        let observer = image.$starDetectionPhase.sink { phases.append( $0 ) }

        defer { observer.cancel() }

        await image.detectStars()

        #expect( phases.contains( .running ),  "detection reports in progress while it runs" )
        #expect( phases.contains( .finished ), "detection records its completion" )
        #expect( phases.last == .finished,     "the phase settles on finished" )
    }

    /// Queueing is ignored once detection has finished, so a repeat cannot erase the
    /// record of the run — which would put the spinner back and drop the overlay's
    /// warning on an image that has already been analysed.
    @Test
    @MainActor
    func queueingIsIgnoredOnceDetectionHasFinished() async throws
    {
        let image = try Self.makeImage()

        await image.detectStars()

        #expect( image.hasDetectedStars, "the detection must have run before a repeat means anything" )

        #expect( image.markStarDetectionQueued() == false, "a finished image does not re-enter the queue" )

        #expect( image.hasDetectedStars,          "queueing again must not erase the completed run" )
        #expect( image.isDetectingStars == false, "queueing again must not report work that will not happen" )
    }

    /// An image with no usable render input detects nothing — and must not be left
    /// reporting a detection that will never run, which would pulse and disable the
    /// toolbar's Stars button and spin the Analysis tab for the life of the image.
    @Test
    @MainActor
    func anImageThatCannotBeDetectedDoesNotStayQueued() async throws
    {
        let renderer = ImageRenderer( source: .failure( CocoaError( .fileReadUnknown ) ) )
        let url      = TestFixtures.monoImage
        let file     = try FITSFile( data: Data( contentsOf: url ), options: .lenient )
        let image    = LoadedImage( info: FITSImageInfo( url: url, file: file ), renderer: renderer )

        image.markStarDetectionQueued()

        #expect( image.isDetectingStars, "the detection must be queued before this proves anything" )

        await image.detectStars()

        #expect( image.isDetectingStars == false, "an image that cannot be detected must not stay queued" )
        #expect( image.hasDetectedStars == false, "nothing ran, so nothing is recorded as having run" )
    }

    /// Abandoning a detection that has already started is ignored, so a caller that
    /// cancels without knowing which stage the work reached cannot report a detection
    /// still in flight as idle — which would stop the toolbar's Stars button pulsing
    /// while it is genuinely working.
    ///
    /// The substituted detector holds the running stage open until released, so this
    /// waits for a state that persists rather than pouncing on one that flashes past.
    @Test
    @MainActor
    func abandoningDetectionThatIsAlreadyRunningIsIgnored() async throws
    {
        let image    = try Self.makeImage()
        let detector = BlockingStarDetector()

        image.starDetector = detector

        let detection = Task { await image.detectStars() }

        defer { detector.release() }

        var attempts = 0

        while image.starDetectionPhase != .running, attempts < 10_000
        {
            attempts += 1

            await Task.yield()
        }

        #expect( image.starDetectionPhase == .running, "the substituted detector must hold the running stage open" )

        // Queueing is refused for the same reason abandoning is: the work has started.
        #expect( image.markStarDetectionQueued() == false, "a running detection does not re-enter the queue" )
        #expect( image.starDetectionPhase == .running,     "a refused queueing leaves the running stage alone" )

        image.markStarDetectionAbandoned()

        #expect( image.starDetectionPhase == .running, "abandoning a running detection is ignored" )
        #expect( image.isDetectingStars,               "the image still reports the detection in flight" )

        detector.release()

        await detection.value

        #expect( image.hasDetectedStars, "the detection completes despite the abandon" )
    }

    /// Abandoning when nothing was queued is a no-op rather than an error.
    @Test
    @MainActor
    func abandoningWhenNothingIsQueuedIsANoOp() throws
    {
        let image = try Self.makeImage()

        image.markStarDetectionAbandoned()

        #expect( image.isDetectingStars == false, "nothing was queued, so nothing is in progress" )
        #expect( image.hasDetectedStars == false, "nothing was queued, so nothing has run" )
    }
}
