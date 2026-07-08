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
import SwiftFITS
import Testing

/// A stub loader that vends a fixed list of already-built frames, so multi-frame
/// selection can be exercised without a real multi-image file format (which no
/// format produces yet). Overriding ``ImageLoading/frames`` is exactly what a
/// future multi-image loader does.
@MainActor
private final class StubMultiFrameLoader: ObservableObject, ImageLoading
{
    /// The fixed frames the loader vends.
    let frames: [ LoadedImage ]

    /// No load error — the frames are supplied ready.
    let error: ( any Swift.Error )? = nil

    /// Creates a loader over the given frames.
    ///
    /// - Parameter frames: The frames to vend.
    init( frames: [ LoadedImage ] )
    {
        self.frames = frames
    }

    /// The primary (first) frame.
    var image: LoadedImage?
    {
        self.frames.first
    }

    /// Emits the primary frame once.
    var imagePublisher: AnyPublisher< LoadedImage?, Never >
    {
        Just( self.frames.first ).eraseToAnyPublisher()
    }

    /// Nothing to parse — the frames are supplied ready.
    func load() async
    {}
}

/// A stub loader that provides only ``image`` (not ``frames``), to verify the
/// protocol's default single-frame derivation.
@MainActor
private final class StubSingleImageLoader: ObservableObject, ImageLoading
{
    /// The single loaded image, if any.
    let image: LoadedImage?

    /// No load error.
    let error: ( any Swift.Error )? = nil

    /// Creates a loader over an optional single image.
    ///
    /// - Parameter image: The image to vend, or `nil`.
    init( image: LoadedImage? )
    {
        self.image = image
    }

    /// Emits the image once.
    var imagePublisher: AnyPublisher< LoadedImage?, Never >
    {
        Just( self.image ).eraseToAnyPublisher()
    }

    /// Nothing to parse.
    func load() async
    {}
}

/// Tests for ``OpenFile``'s multi-frame model: the frame list, the selected
/// frame, and selection driving the displayed image and its render.
@Suite( "OpenFile frames" )
struct OpenFileFramesTests
{
    /// Builds a real, renderable ``LoadedImage`` from the mono fixture. Each call
    /// yields a distinct instance, so a list of them models distinct frames.
    @MainActor
    private static func makeImage() throws -> LoadedImage
    {
        let url      = TestFixtures.monoImage
        let file     = try FITSFile( data: Data( contentsOf: url ), options: .lenient )
        let info     = FITSImageInfo( url: url, file: file )
        let renderer = ImageRenderer( file: file )

        return LoadedImage( info: info, renderer: renderer )
    }

    /// A loader that provides only `image` derives a single-frame list from it.
    @Test
    @MainActor
    func singleImageLoaderDerivesOneFrame() throws
    {
        let image  = try Self.makeImage()
        let loader = StubSingleImageLoader( image: image )

        #expect( loader.frames.count == 1 )
        #expect( loader.frames.first === image )
    }

    /// A loader with no image derives an empty frame list.
    @Test
    @MainActor
    func imagelessLoaderDerivesNoFrames() throws
    {
        let loader = StubSingleImageLoader( image: nil )

        #expect( loader.frames.isEmpty )
    }

    /// A freshly opened multi-frame file shows its first frame.
    @Test
    @MainActor
    func defaultsToFirstFrame() throws
    {
        let frames = [ try Self.makeImage(), try Self.makeImage() ]
        let file   = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )

        #expect( file.frames.count == 2 )
        #expect( file.selectedFrameIndex == 0 )
        #expect( file.image === frames[ 0 ] )
    }

    /// Selecting a frame changes both the index and the displayed image.
    @Test
    @MainActor
    func selectFrameChangesDisplayedImage() throws
    {
        let frames = [ try Self.makeImage(), try Self.makeImage() ]
        let file   = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )

        file.selectFrame( 1 )

        #expect( file.selectedFrameIndex == 1 )
        #expect( file.image === frames[ 1 ] )
    }

    /// Selecting an out-of-range index is ignored, leaving the selection intact.
    @Test
    @MainActor
    func selectFrameIgnoresOutOfRange() throws
    {
        let frames = [ try Self.makeImage(), try Self.makeImage() ]
        let file   = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )

        file.selectFrame( 9 )
        #expect( file.selectedFrameIndex == 0 )

        file.selectFrame( -1 )
        #expect( file.selectedFrameIndex == 0 )
    }

    /// Selecting a frame that has not rendered yet renders it, so the newly shown
    /// frame produces a displayable result.
    @Test
    @MainActor
    func selectFrameRendersTheSelectedFrame() async throws
    {
        let frames = [ try Self.makeImage(), try Self.makeImage() ]
        let file   = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )

        #expect( frames[ 1 ].renderer.result == nil )

        file.selectFrame( 1 )
        await file.frameSelectionTask?.value

        #expect( frames[ 1 ].renderer.result != nil, "selecting a not-yet-rendered frame must render it" )
    }

    /// Preparing a multi-frame file renders every frame in the background, so the
    /// carousel can show a thumbnail preview for each frame — not only the primary or
    /// the frames the user has visited.
    @Test
    @MainActor
    func preparingRendersPreviewsForAllFrames() async throws
    {
        let frames   = [ try Self.makeImage(), try Self.makeImage(), try Self.makeImage() ]
        let file     = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )
        let throttle = RenderThrottle( limit: 2 )

        #expect( frames.allSatisfy { $0.renderer.result == nil } )

        file.prepare( throttle: throttle )

        await file.preparation?.value
        await file.framePreviewsTask?.value

        #expect( frames.allSatisfy { $0.renderer.result != nil }, "every frame must render so the carousel can preview it" )
    }

    /// The file republishes when the selected (non-primary) frame renders, so the
    /// views observing the file — the canvas — refresh once the lazily prepared
    /// frame commits its result. Guards the selected-frame change forwarding.
    @Test
    @MainActor
    func republishesWhenSelectedFrameRenders() async throws
    {
        let frames = [ try Self.makeImage(), try Self.makeImage() ]
        let file   = OpenFile( url: TestFixtures.monoImage, loader: StubMultiFrameLoader( frames: frames ) )

        // Select the frame first (which itself publishes the index change), then
        // start observing, so only the subsequent render commit is measured.
        file.selectFrame( 1 )

        var republished = false
        let observer    = file.objectWillChange.sink { _ in republished = true }

        await file.frameSelectionTask?.value

        observer.cancel()

        #expect( republished, "the file must republish when the selected frame commits its render" )
    }
}
