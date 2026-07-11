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
import Foundation
import SwiftPixel
import SwiftUtilities
import SwiftXISF

/// Renders an XISF file to a display-ready `CGImage` — the XISF counterpart of
/// ``FITSPreviewRenderer``.
///
/// Shared by the app and the QuickLook extensions so a Finder thumbnail/preview
/// matches what the app shows on open. It has no SwiftUI/AppKit dependencies, so it
/// compiles into the extension targets. A multi-image file previews its first image.
///
/// It mirrors the app's on-open rendering: a stored display function is applied when
/// present, else an auto Screen Transfer when the shared per-format previews
/// preference is on, else a linear (min/max) render.
public enum XISFPreviewRenderer
{
    /// Renders the given XISF file bytes to a `CGImage`.
    ///
    /// - Parameters:
    ///   - data:             The raw XISF file bytes.
    ///   - previewsDefaults: The shared App Group store the previews preference is
    ///                       read from; defaults to ``AutoStretchPreference/sharedDefaults``.
    ///                       `nil` (an unopenable suite) renders linear.
    /// - Returns: The rendered, display-ready image.
    /// - Throws: ``RuntimeError`` when the file contains no image, or any error
    ///   parsing the file or rendering the image.
    public static func render( data: Data, previewsDefaults: UserDefaults? = AutoStretchPreference.sharedDefaults ) throws -> CGImage
    {
        let file = try XISFFile( data: data, options: .lenient )

        guard let image = file.images.first
        else
        {
            throw RuntimeError( message: "XISF file contains no image" )
        }

        let properties = XISFImageProperties( image: image )
        let bytes      = try image.data
        let settings   = Self.previewSettings( data: bytes, properties: properties, previewsDefaults: previewsDefaults )

        return try ImageProcessor.render( data: bytes, xisf: properties, settings: settings ).image
    }

    /// Reads and renders the XISF file at the given URL.
    ///
    /// - Parameters:
    ///   - url:              The XISF file to read and render.
    ///   - previewsDefaults: The shared App Group store the previews preference is
    ///                       read from; defaults to ``AutoStretchPreference/sharedDefaults``.
    /// - Returns: The rendered, display-ready image.
    /// - Throws: Any error reading, parsing, or rendering the file.
    public static func render( contentsOf url: URL, previewsDefaults: UserDefaults? = AutoStretchPreference.sharedDefaults ) throws -> CGImage
    {
        try self.render( data: try Data( contentsOf: url ), previewsDefaults: previewsDefaults )
    }

    /// The settings an XISF preview renders with, using the same priority as the app
    /// on open: the stored display function first (the image "as authored", always
    /// applied), else an auto Screen Transfer when the shared previews preference for
    /// XISF is on and the format has a known integer full scale, else linear.
    ///
    /// Exposed (not private) so the priority logic can be unit-tested against an
    /// isolated preferences store.
    ///
    /// - Parameters:
    ///   - data:             The image's decoded pixel bytes.
    ///   - properties:       The image's pixel layout (carrying any display function).
    ///   - previewsDefaults: The store the previews preference is read from, or `nil`.
    /// - Returns: The render settings.
    static func previewSettings( data: Data, properties: XISFImageProperties, previewsDefaults: UserDefaults? ) -> ImageProcessor.Settings
    {
        // A stored display function is the image "as authored"; it always applies,
        // regardless of the previews preference (matching the app on open).
        if let displayFunction = properties.displayFunction,
           let stf             = Processors.Stretch.STFParameters( displayFunction: displayFunction, colorSpace: properties.colorSpace )
        {
            return ImageProcessor.Settings( normalize: .identity, stretch: stf )
        }

        // Otherwise auto-stretch only when the shared previews preference is on and a
        // full scale is known (integer formats); a float format, or an unopenable
        // suite, falls back to a linear render. The derivation uses the plain channel
        // luminance — a colour-filter-array frame's raw mosaic is used as-is (its
        // median/MAD are enough to pick a preview stretch), rather than demosaicing to
        // grayscale as the app does on open, so the extension stays free of the
        // demosaic dependency; the resulting preview stretch can differ slightly from
        // the app's for an OSC frame.
        guard let defaults = previewsDefaults,
              AutoStretchPreference.autoStretchPreviews( .xisf, in: defaults ),
              let fullScale = ImageProcessor.xisfFullScale( properties.sampleFormat ),
              let luminance = ImageProcessor.xisfLinearLuminance( data: data, properties: properties ),
              let buffer    = try? PixelBuffer( width: luminance.width, height: luminance.height, channels: 1, pixels: luminance.samples, isNormalized: false ),
              let settings  = ImageProcessor.autoStretchSettings( detectionImage: buffer, fullScale: fullScale )
        else
        {
            return ImageProcessor.Settings()
        }

        return settings
    }
}
