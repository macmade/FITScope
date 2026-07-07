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

import CoreGraphics

public extension ImageProcessor
{
    /// The result of a render: the display-ready image plus the 8-bit pixel
    /// bytes the histogram and statistics stages consume, tagged with the pixel
    /// formats it was produced from and to.
    struct RenderResult
    {
        /// How the source samples fed to the pipeline were laid out, which
        /// determines the colour interpretation of the result.
        public enum InputPixelFormat: Sendable, Equatable
        {
            /// A single-channel monochrome source, expanded to RGB — the three
            /// output channels are replicated from one, so the image is shown with
            /// a single mono histogram rather than an R/G/B triple.
            case mono

            /// A single-channel colour-filter-array source, demosaiced to genuine
            /// colour.
            case cfa

            /// An already-interleaved three-channel RGB source.
            case rgb

            /// The number of interleaved channels the source samples carry.
            public var channels: Int
            {
                switch self
                {
                    case .mono: return 1
                    case .cfa:  return 1
                    case .rgb:  return 3
                }
            }
        }

        /// The channel layout of the rendered pixels. The pipeline always emits
        /// interleaved RGB today; modelling it as an enum (rather than a bare
        /// count) leaves room for a layout an alpha-bearing format would add — e.g.
        /// RGBA — without conflating orderings a count cannot distinguish.
        public enum OutputPixelFormat: Sendable, Equatable
        {
            /// Three interleaved channels, in red, green, blue order.
            case rgb

            /// The number of interleaved channels the rendered pixels carry.
            public var channels: Int
            {
                switch self
                {
                    case .rgb: return 3
                }
            }
        }

        /// The rendered, display-ready image.
        public let image: CGImage

        /// The rendered pixels as interleaved 8-bit samples, fed to the histogram
        /// and statistics stages.
        public let bytes: [ UInt8 ]

        /// The layout of the source samples the pipeline consumed.
        public let inputPixelFormat: InputPixelFormat

        /// The layout of the rendered ``bytes``.
        public let outputPixelFormat: OutputPixelFormat

        /// Creates a render result.
        ///
        /// - Parameters:
        ///   - image:             The rendered, display-ready image.
        ///   - bytes:             The rendered interleaved 8-bit samples.
        ///   - inputPixelFormat:  The layout of the source samples.
        ///   - outputPixelFormat: The layout of the rendered ``bytes``.
        public init( image: CGImage, bytes: [ UInt8 ], inputPixelFormat: InputPixelFormat, outputPixelFormat: OutputPixelFormat )
        {
            self.image             = image
            self.bytes             = bytes
            self.inputPixelFormat  = inputPixelFormat
            self.outputPixelFormat = outputPixelFormat
        }
    }
}
