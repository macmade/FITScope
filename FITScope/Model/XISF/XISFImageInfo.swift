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

import Foundation
import SwiftFITS
import SwiftXISF

/// A `Sendable` snapshot of one XISF image's metadata, mirroring ``FITSImageInfo``:
/// it groups the image's structural attributes, properties and embedded FITS
/// keywords into the format-neutral metadata model, and derives the astrometry
/// fields from the embedded keywords through the same ``FITSMetadata`` accessors
/// the FITS path uses.
public struct XISFImageInfo: Sendable
{
    /// The URL of the source file.
    public let url: URL

    /// The image's metadata sections, in display order.
    public let sections: [ ImageMetadataSection ]

    /// The image's pixel layout, used to render and summarize it.
    public let imageProperties: XISFImageProperties

    /// A short label identifying this image among the file's images (its `id` or
    /// image type), or `nil` when it carries neither.
    public let frameTitle: String?

    /// Builds the snapshot from a parsed XISF file and one of its images.
    ///
    /// File-level properties and keywords are included alongside the image's own, so
    /// each frame's Info window shows the file-wide metadata too.
    ///
    /// - Parameters:
    ///   - url:   The URL the file was loaded from.
    ///   - file:  The parsed XISF file.
    ///   - image: The image to snapshot.
    public init( url: URL, file: XISFFile, image: XISFImage )
    {
        var raw = [ ImageMetadataSection.geometry( index: 0, image: image ) ]

        if let keywords = ImageMetadataSection( index: 0, title: "FITS Keywords", keywords: file.keywords + image.keywords )
        {
            raw.append( keywords )
        }

        if let imageProperties = ImageMetadataSection( index: 0, title: "Image Properties", xisfProperties: image.properties )
        {
            raw.append( imageProperties )
        }

        if let fileProperties = ImageMetadataSection( index: 0, title: "File Properties", xisfProperties: file.properties )
        {
            raw.append( fileProperties )
        }

        // Renumber the assembled sections so their indices (and derived ids) are
        // contiguous once the absent optional groups have been dropped.
        self.url             = url
        self.imageProperties = XISFImageProperties( image: image )
        self.frameTitle      = Self.frameTitle( for: image )
        self.sections        = raw.enumerated().map
        {
            ImageMetadataSection( index: $0.offset, title: $0.element.title, properties: $0.element.properties )
        }
    }

    /// The image's metadata as the format-neutral ``ImageMetadata`` the Info window
    /// consumes, so the XISF path feeds the same window as every other format.
    public var imageMetadata: ImageMetadata
    {
        ImageMetadata( url: self.url, sections: self.sections )
    }

    /// Whether the image is a colour-filter-array (CFA) image, so the inspector
    /// offers the debayer controls.
    public var isColorFilterArray: Bool
    {
        self.imageProperties.colorFilterArrayPattern != nil
    }

    /// Whether the displayed image is colour — an RGB image or a CFA image (which
    /// debayers to colour) — so the inspector offers the colour-grading controls.
    public var isColor: Bool
    {
        self.imageProperties.colorSpace == .rgb || self.isColorFilterArray
    }

    /// The image's embedded FITS keywords as a queryable ``FITSMetadata``, built from
    /// the metadata sections' properties (so the "FITS Keywords" section's entries
    /// drive the astrometry accessors). The values are carried as strings;
    /// ``FITSMetadata``'s accessors parse them on demand — the same path as
    /// ``FITSImageInfo/metadata``.
    public var metadata: FITSMetadata
    {
        let properties = self.sections.flatMap { $0.properties }.map
        {
            FITSPropertySnapshot( name: $0.name, value: .string( $0.value ) )
        }

        return FITSMetadata( properties: properties )
    }

    /// The image's plate scale, in arc-seconds per pixel, or `nil` when it cannot be
    /// derived. Reuses ``FITSMetadata``'s unit-aware derivation over the embedded
    /// keywords.
    public var pixelScale: Double?
    {
        self.metadata.pixelScale
    }

    /// A short label for an image, preferring its `id`, then its image type.
    ///
    /// - Parameter image: The image to label.
    /// - Returns: The label, or `nil` when the image carries neither.
    private static func frameTitle( for image: XISFImage ) -> String?
    {
        if let id = image.id, id.isEmpty == false
        {
            return id
        }

        if let imageType = image.imageType, imageType.isEmpty == false
        {
            return imageType
        }

        return nil
    }
}
