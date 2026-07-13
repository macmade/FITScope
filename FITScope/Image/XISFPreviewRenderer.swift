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
    ///   - maxDimension:     The largest dimension the rendered image may take, or
    ///                       `nil` for a full-resolution render (the thumbnail
    ///                       extension passes the requested size).
    ///   - previewsDefaults: The shared App Group store the previews preference is
    ///                       read from; defaults to ``AutoStretchPreference/sharedDefaults``.
    ///                       `nil` (an unopenable suite) renders linear.
    /// - Returns: The rendered, display-ready image.
    /// - Throws: ``RuntimeError`` when the file contains no image, or any error
    ///   parsing the file or rendering the image.
    public static func render( data: Data, maxDimension: Int? = nil, previewsDefaults: UserDefaults? = AutoStretchPreference.sharedDefaults ) throws -> CGImage
    {
        let file = try XISFFile( data: data, options: .lenient )

        guard let image = file.images.first
        else
        {
            throw RuntimeError( message: "XISF file contains no image" )
        }

        let properties = XISFImageProperties( image: image )
        let bytes      = try image.data

        // Decode the channel planes once and share them between the auto-stretch
        // statistics and the render, so a one-shot preview decodes the image a single
        // time (every XISF layout decodes to planes, so there is no fallback path).
        let planes   = try ImageProcessor.xisfPlaneSamples( data: bytes, properties: properties )
        let frame    = XISFDecodedRenderSource( planes: planes, properties: properties )
        let settings = Self.previewSettings( frame: frame, maxDimension: maxDimension, previewsDefaults: previewsDefaults )

        return try frame.makeResult( settings: settings ).image
    }

    /// Reads and renders the XISF file at the given URL.
    ///
    /// - Parameters:
    ///   - url:              The XISF file to read and render.
    ///   - maxDimension:     The largest dimension the rendered image may take, or
    ///                       `nil` for a full-resolution render.
    ///   - previewsDefaults: The shared App Group store the previews preference is
    ///                       read from; defaults to ``AutoStretchPreference/sharedDefaults``.
    /// - Returns: The rendered, display-ready image.
    /// - Throws: Any error reading, parsing, or rendering the file.
    public static func render( contentsOf url: URL, maxDimension: Int? = nil, previewsDefaults: UserDefaults? = AutoStretchPreference.sharedDefaults ) throws -> CGImage
    {
        try self.render( data: try Data( contentsOf: url ), maxDimension: maxDimension, previewsDefaults: previewsDefaults )
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
    ///   - maxDimension:     The largest dimension the rendered image may take, or
    ///                       `nil` for a full-resolution render. When set, the
    ///                       returned settings carry it (so the render downsamples)
    ///                       and the auto-stretch statistics are derived from a
    ///                       decimated colour source.
    ///   - previewsDefaults: The store the previews preference is read from, or `nil`.
    /// - Returns: The render settings.
    static func previewSettings( data: Data, properties: XISFImageProperties, maxDimension: Int? = nil, previewsDefaults: UserDefaults? ) -> ImageProcessor.Settings
    {
        var settings = ImageProcessor.Settings()

        // A stored display function is the image "as authored"; it always applies,
        // regardless of the previews preference (matching the app on open).
        if let displayFunction = properties.displayFunction,
           let stf             = Processors.Stretch.STFParameters( displayFunction: displayFunction, colorSpace: properties.colorSpace )
        {
            settings = ImageProcessor.Settings( normalize: .identity, stretch: stf )
        }

        // Otherwise auto-stretch only when the shared previews preference is on (an
        // unopenable suite falls back to a linear render). A colour frame derives a
        // per-channel (unlinked) STF — a colour-filter-array frame's mosaic is split per
        // channel by deinterleaving (no demosaic dependency), an RGB frame by its planes
        // — so the preview matches the app on open; any other frame uses its plain
        // channel luminance for a uniform stretch. It is derived over the format's own
        // domain: full-scale for an integer sample format, min/max for a floating-point
        // one.
        else if let defaults = previewsDefaults,
                AutoStretchPreference.autoStretchPreviews( .xisf, in: defaults ),
                let colorSource = Self.previewColorSource( data: data, properties: properties, maxDimension: maxDimension )
        {
            let domain = ImageProcessor.xisfFullScale( properties.sampleFormat ).map { ImageProcessor.AutoStretchDomain.fullScale( $0 ) } ?? .minMax

            if let derived = ImageProcessor.autoStretchSettings( colorSource: colorSource, domain: domain )
            {
                settings = derived
            }
        }

        settings.maxDimension = maxDimension

        return settings
    }

    /// The settings an XISF preview renders with, derived from a decode-once
    /// ``XISFDecodedRenderSource`` — the decode-once counterpart of
    /// ``previewSettings(data:properties:maxDimension:previewsDefaults:)`` used when the
    /// caller has decoded the frame to render from, so the auto-stretch statistics reuse
    /// that decode through the frame's own
    /// ``XISFDecodedRenderSource/autoStretchColorSource(maxDimension:)``.
    ///
    /// - Parameters:
    ///   - frame:            The decode-once render source (carrying any display function).
    ///   - maxDimension:     The largest dimension the rendered image may take, or `nil`.
    ///   - previewsDefaults: The store the previews preference is read from, or `nil`.
    /// - Returns: The render settings.
    static func previewSettings( frame: XISFDecodedRenderSource, maxDimension: Int? = nil, previewsDefaults: UserDefaults? ) -> ImageProcessor.Settings
    {
        let properties = frame.properties
        var settings   = ImageProcessor.Settings()

        if let displayFunction = properties.displayFunction,
           let stf             = Processors.Stretch.STFParameters( displayFunction: displayFunction, colorSpace: properties.colorSpace )
        {
            settings = ImageProcessor.Settings( normalize: .identity, stretch: stf )
        }
        else if let defaults = previewsDefaults,
                AutoStretchPreference.autoStretchPreviews( .xisf, in: defaults ),
                let colorSource = frame.autoStretchColorSource( maxDimension: maxDimension )
        {
            let domain = ImageProcessor.xisfFullScale( properties.sampleFormat ).map { ImageProcessor.AutoStretchDomain.fullScale( $0 ) } ?? .minMax

            if let derived = ImageProcessor.autoStretchSettings( colorSource: colorSource, domain: domain )
            {
                settings = derived
            }
        }

        settings.maxDimension = maxDimension

        return settings
    }

    /// The colour input the preview's auto Screen Transfer derives from, so the
    /// preview matches the app on open: a colour-filter-array or RGB frame yields a
    /// per-channel input (via ``ImageProcessor/xisfAutoStretchColorSource(data:properties:)``),
    /// and any other frame falls back to its single-channel luminance for a uniform
    /// stretch.
    ///
    /// - Parameters:
    ///   - data:         The image's decoded pixel bytes.
    ///   - properties:   The image's pixel layout.
    ///   - maxDimension: The largest dimension the derivation's colour source may
    ///                   take, or `nil` to derive from the full-resolution source.
    /// - Returns: The colour input, or `nil` when it cannot be built (the caller then
    ///   renders linear).
    private static func previewColorSource( data: Data, properties: XISFImageProperties, maxDimension: Int? ) -> ImageProcessor.AutoStretchColorSource?
    {
        if let colour = ImageProcessor.xisfAutoStretchColorSource( data: data, properties: properties )
        {
            return colour.subsampled( maxDimension: maxDimension )
        }

        guard let luminance = ImageProcessor.xisfLinearLuminance( data: data, properties: properties ),
              let buffer    = try? PixelBuffer( width: luminance.width, height: luminance.height, channels: 1, pixels: luminance.samples, isNormalized: false )
        else
        {
            return nil
        }

        return ImageProcessor.AutoStretchColorSource.mono( buffer ).subsampled( maxDimension: maxDimension )
    }
}
