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
import SwiftFITS
import SwiftPixel
import SwiftUtilities

/// Renders a FITS file to a display-ready `CGImage`, mirroring the app's on-open
/// rendering: an auto Screen Transfer when the shared per-format previews preference
/// is on (FITS carries no display function), else a linear (min/max) render.
///
/// This is the one place the "open a FITS file and show its default render"
/// logic lives, shared by the app's first render and the QuickLook extensions,
/// so a Finder thumbnail/preview matches what the app shows on open. It has no
/// SwiftUI/AppKit dependencies, so it compiles into the extension targets.
public enum FITSPreviewRenderer
{
    /// Selects the first renderable image HDU and returns its bytes paired with
    /// the owning header's property snapshots — the same selection rule the app's
    /// renderer uses (first `.data` section, paired with the header that precedes
    /// it in file order).
    ///
    /// - Parameter sections: The file's sections, in file order.
    /// - Returns: The image data bytes and owning-header property snapshots.
    /// - Throws: ``RuntimeError`` when the file contains no image data section.
    public static func imageHDU( from sections: [ FITSSection ] ) throws -> ( data: Data, properties: [ FITSPropertySnapshot ] )
    {
        guard let dataIndex = sections.firstIndex( where: { $0.kind == .data } ), dataIndex > 0
        else
        {
            throw RuntimeError( message: "FITS file contains no image HDU" )
        }

        let properties = sections[ dataIndex - 1 ].properties.map { FITSPropertySnapshot( name: $0.name, value: $0.value ) }

        return ( try sections[ dataIndex ].data, properties )
    }

    /// Renders the given FITS file bytes to a `CGImage`.
    ///
    /// - Parameters:
    ///   - data:             The raw FITS file bytes.
    ///   - maxDimension:     The largest dimension the rendered image may take, or
    ///                       `nil` for a full-resolution render (the thumbnail
    ///                       extension passes the requested size).
    ///   - previewsDefaults: The shared App Group store the previews preference is
    ///                       read from; defaults to ``AutoStretchPreference/sharedDefaults``.
    ///                       `nil` (an unopenable suite) renders linear.
    /// - Returns: The rendered, display-ready image.
    /// - Throws: Any error parsing the file or rendering the image.
    public static func render( data: Data, maxDimension: Int? = nil, previewsDefaults: UserDefaults? = AutoStretchPreference.sharedDefaults ) throws -> CGImage
    {
        let file = try FITSFile( data: data, options: .lenient )
        let hdu  = try self.imageHDU( from: file.sections )

        // Decode the raw samples once and share them between the auto-stretch
        // statistics and the render, so a one-shot preview decodes the frame a single
        // time. An RGB colour-plane frame — or anything not directly decodable as a
        // 2-D image — is not covered here and falls back to the byte-based path, which
        // decodes as before.
        guard let decoded = ImageProcessor.decodedImageHDU( data: hdu.data, properties: hdu.properties )
        else
        {
            let settings = Self.previewSettings( hdu: hdu, maxDimension: maxDimension, previewsDefaults: previewsDefaults )

            return try ImageProcessor.render( data: hdu.data, properties: hdu.properties, settings: settings ).image
        }

        let settings = Self.previewSettings( decoded: decoded, properties: hdu.properties, maxDimension: maxDimension, previewsDefaults: previewsDefaults )

        return try ImageProcessor.render( rawSamples: decoded.samples, width: decoded.width, height: decoded.height, bitsPerPixel: decoded.bitsPerPixel, properties: hdu.properties, settings: settings ).image
    }

    /// Reads and renders the FITS file at the given URL.
    ///
    /// - Parameters:
    ///   - url:              The FITS file to read and render.
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

    /// The settings a FITS preview renders with: an auto Screen Transfer when the
    /// shared previews preference for FITS is on and the format has a known integer
    /// full scale (a floating-point frame has none), else a linear (min/max) render.
    /// FITS carries no display function, so there is no display-function branch.
    ///
    /// Exposed (not private) so the priority logic can be unit-tested against an
    /// isolated preferences store.
    ///
    /// - Parameters:
    ///   - hdu:              The image HDU's bytes and header property snapshots.
    ///   - maxDimension:     The largest dimension the rendered image may take, or
    ///                       `nil` for a full-resolution render. When set, the
    ///                       returned settings carry it (so the render downsamples)
    ///                       and the auto-stretch statistics are derived from a
    ///                       decimated colour source.
    ///   - previewsDefaults: The store the previews preference is read from, or `nil`.
    /// - Returns: The render settings.
    static func previewSettings( hdu: ( data: Data, properties: [ FITSPropertySnapshot ] ), maxDimension: Int? = nil, previewsDefaults: UserDefaults? ) -> ImageProcessor.Settings
    {
        var settings = ImageProcessor.Settings()

        // Full-scale domain for an integer format, min/max for a floating-point one, so
        // the preview stretches in the same domain the app opens with.
        if let defaults = previewsDefaults,
           AutoStretchPreference.autoStretchPreviews( .fits, in: defaults ),
           let colorSource = Self.previewColorSource( hdu: hdu, maxDimension: maxDimension )
        {
            let domain = ImageProcessor.fullScale( forImageHDU: hdu.properties ).map { ImageProcessor.AutoStretchDomain.fullScale( $0 ) } ?? .minMax

            if let derived = ImageProcessor.autoStretchSettings( colorSource: colorSource, domain: domain )
            {
                settings = derived
            }
        }

        settings.maxDimension = maxDimension

        return settings
    }

    /// The settings a FITS preview renders with, derived from the frame's
    /// already-decoded raw samples — the decode-once counterpart of
    /// ``previewSettings(hdu:maxDimension:previewsDefaults:)`` used when the caller
    /// has decoded the samples to render from, so the statistics reuse that decode.
    ///
    /// - Parameters:
    ///   - decoded:          The decoded raw samples with their geometry and format.
    ///   - properties:       The image HDU's header property snapshots.
    ///   - maxDimension:     The largest dimension the rendered image may take, or
    ///                       `nil`. Carried into the settings, and the auto-stretch
    ///                       statistics are derived from a decimated colour source.
    ///   - previewsDefaults: The store the previews preference is read from, or `nil`.
    /// - Returns: The render settings.
    static func previewSettings( decoded: ( samples: [ Double ], width: Int, height: Int, bitsPerPixel: BitsPerPixel ), properties: [ FITSPropertySnapshot ], maxDimension: Int? = nil, previewsDefaults: UserDefaults? ) -> ImageProcessor.Settings
    {
        var settings = ImageProcessor.Settings()

        if let defaults = previewsDefaults,
           AutoStretchPreference.autoStretchPreviews( .fits, in: defaults ),
           let colorSource = ImageProcessor.autoStretchColorSource( fromSamples: decoded.samples, width: decoded.width, height: decoded.height, properties: properties )?.subsampled( maxDimension: maxDimension )
        {
            let domain = ImageProcessor.fullScale( forImageHDU: properties ).map { ImageProcessor.AutoStretchDomain.fullScale( $0 ) } ?? .minMax

            if let derived = ImageProcessor.autoStretchSettings( colorSource: colorSource, domain: domain )
            {
                settings = derived
            }
        }

        settings.maxDimension = maxDimension

        return settings
    }

    /// The colour input the preview's auto Screen Transfer derives from, so the
    /// preview matches the app on open: an RGB or colour-filter-array frame yields a
    /// per-channel input (via ``ImageProcessor/autoStretchColorSource(forImageHDU:properties:)``),
    /// and any other frame falls back to its single-channel luminance for a uniform
    /// stretch.
    ///
    /// - Parameters:
    ///   - hdu:          The image HDU's bytes and header property snapshots.
    ///   - maxDimension: The largest dimension the derivation's colour source may
    ///                   take, or `nil` to derive from the full-resolution source.
    /// - Returns: The colour input, or `nil` when it cannot be built (the caller then
    ///   renders linear).
    private static func previewColorSource( hdu: ( data: Data, properties: [ FITSPropertySnapshot ] ), maxDimension: Int? ) -> ImageProcessor.AutoStretchColorSource?
    {
        if let colour = ImageProcessor.autoStretchColorSource( forImageHDU: hdu.data, properties: hdu.properties )
        {
            return colour.subsampled( maxDimension: maxDimension )
        }

        guard let luminance = Self.previewLuminance( hdu: hdu ),
              let buffer    = try? PixelBuffer( width: luminance.width, height: luminance.height, channels: 1, pixels: luminance.samples, isNormalized: false )
        else
        {
            return nil
        }

        return ImageProcessor.AutoStretchColorSource.mono( buffer ).subsampled( maxDimension: maxDimension )
    }

    /// The single-channel scaled-linear luminance the auto-stretch derivation reads:
    /// an RGB colour cube combines its three planes, any other image uses its
    /// scaled-linear samples (a 2-D mono frame, or a colour-filter-array mosaic used
    /// as-is — its median/MAD statistics are enough to derive the preview stretch).
    ///
    /// - Parameter hdu: The image HDU's bytes and header property snapshots.
    /// - Returns: The luminance dimensions and samples, or `nil` when they cannot be
    ///   decoded (the caller then renders linear).
    private static func previewLuminance( hdu: ( data: Data, properties: [ FITSPropertySnapshot ] ) ) -> ( width: Int, height: Int, samples: [ Double ] )?
    {
        if ImageProcessor.isRGBPlanes( properties: hdu.properties )
        {
            return ImageProcessor.rgbLinearLuminance( data: hdu.data, properties: hdu.properties )
        }

        return ImageProcessor.linearImage( data: hdu.data, properties: hdu.properties )
    }
}
