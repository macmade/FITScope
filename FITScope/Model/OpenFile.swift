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
import CoreGraphics
import Foundation
import SwiftUI

/// A single file open in a window: its identity, source URL, and the loader
/// that parses it into a ``FITSImage``.
///
/// Each instance is a distinct entry — opening the same URL twice yields two
/// independent ``OpenFile`` objects, each with its own renderer and adjustment
/// state. Change notifications from the underlying loader are re-published so a
/// view observing the open file refreshes as it loads and renders.
@MainActor
public final class OpenFile: ObservableObject, Identifiable
{
    /// A stable, per-instance identity, independent of the URL.
    public let id = UUID()

    /// The source URL of the file.
    public let url: URL

    /// The loader that parses the file into a ``FITSImage``.
    @Published public private( set ) var loader: FITSImageLoader

    /// A small, downscaled preview of the rendered image for the sidebar, or
    /// `nil` before one has been generated.
    @Published public private( set ) var thumbnail: CGImage?

    /// Forwards the loader's change notifications to this object's observers.
    private var loaderObserver: AnyCancellable?

    /// Creates an open file for the given URL.
    ///
    /// - Parameter url: The source URL of the file.
    public init( url: URL )
    {
        self.url            = url
        self.loader         = FITSImageLoader( url: url )
        self.loaderObserver = self.loader.objectWillChange.sink
        {
            [ weak self ] _ in self?.objectWillChange.send()
        }
    }

    /// The file name shown in the sidebar and window title.
    public var displayName: String
    {
        self.url.lastPathComponent
    }

    /// The loaded image, or `nil` before loading or after a failure.
    public var image: FITSImage?
    {
        self.loader.image
    }

    /// The error from the most recent failed load, or `nil` on success.
    public var error: Error?
    {
        self.loader.error
    }

    /// Loads (parses) the file, if not already loaded.
    public func load() async
    {
        await self.loader.load()
    }

    /// Generates a thumbnail from the current rendered image, downscaled so its
    /// longest side is at most `maxDimension` pixels. A no-op when nothing has
    /// rendered yet.
    ///
    /// - Parameter maxDimension: The maximum width or height of the thumbnail.
    public func makeThumbnail( maxDimension: Int ) async
    {
        guard let source = self.image?.renderer.result?.image
        else
        {
            return
        }

        let longest = max( source.width, source.height )
        let scale   = longest > maxDimension ? Double( maxDimension ) / Double( longest ) : 1.0
        let width   = max( 1, Int( Double( source.width  ) * scale ) )
        let height  = max( 1, Int( Double( source.height ) * scale ) )

        let thumbnail = await withCheckedContinuation
        {
            ( continuation: CheckedContinuation< CGImage?, Never > ) in

            DispatchQueue.global( qos: .utility ).async
            {
                continuation.resume( returning: Self.resize( source, width: width, height: height ) )
            }
        }

        self.thumbnail = thumbnail
    }

    /// Redraws a `CGImage` at the given pixel size, preserving its color space.
    private nonisolated static func resize( _ image: CGImage, width: Int, height: Int ) -> CGImage?
    {
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data:             nil,
            width:            width,
            height:           height,
            bitsPerComponent: 8,
            bytesPerRow:      0,
            space:            colorSpace,
            bitmapInfo:       CGImageAlphaInfo.premultipliedLast.rawValue
        )
        else
        {
            return nil
        }

        context.interpolationQuality = .low
        context.draw( image, in: CGRect( x: 0, y: 0, width: width, height: height ) )

        return context.makeImage()
    }
}
