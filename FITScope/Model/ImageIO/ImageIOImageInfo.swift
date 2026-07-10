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
import ImageIO

/// A `Sendable` snapshot of one photographic image's metadata, mirroring
/// ``XISFImageInfo`` / ``FITSImageInfo``: it groups the `CGImageSource` properties
/// (the structural attributes plus the EXIF, TIFF, GPS and similar groups) into the
/// format-neutral metadata model, and extracts the astrometry-adjacent fields
/// (capture date, exposure, and — from GPS — the observing site's geographic
/// coordinate) a photographic file can carry.
///
/// The `CGImageSource` property dictionary is not `Sendable`, so it is parsed into
/// these value fields off the main actor and only the snapshot crosses back.
public struct ImageIOImageInfo: Sendable
{
    /// The URL of the source file.
    public let url: URL

    /// The image's metadata sections, in display order.
    public let sections: [ ImageMetadataSection ]

    /// The image dimensions, e.g. `"6240 × 4160"`.
    public let dimensions: String

    /// The bit depth, e.g. `"8-bit"`.
    public let bitDepth: String

    /// The channel description, e.g. `"3 (RGB)"`.
    public let channels: String

    /// Whether the displayed image is colour, so the inspector offers the
    /// colour-grading controls.
    public let isColor: Bool

    /// When the image was captured (from EXIF `DateTimeOriginal`), or `nil`.
    public let observationDate: Date?

    /// The exposure time in seconds (from EXIF `ExposureTime`), or `nil`.
    public let exposureTime: Double?

    /// The capture location as the observing site's geographic coordinate (from the
    /// GPS group), or `nil`.
    public let coordinate: Coordinate?

    /// The present values for the display summary's fields, derived from EXIF/TIFF.
    public let summaryValues: [ InfoField: String ]

    /// A short label identifying this image among the file's images, or `nil`.
    public let frameTitle: String?

    /// The metadata groups surfaced as their own sections, in display order, keyed
    /// by their `CGImageSource` dictionary key.
    private static let metadataGroups: [ ( key: String, title: String ) ] =
        [
            ( kCGImagePropertyExifDictionary as String,    "EXIF" ),
            ( kCGImagePropertyTIFFDictionary as String,    "TIFF" ),
            ( kCGImagePropertyGPSDictionary as String,     "GPS" ),
            ( kCGImagePropertyExifAuxDictionary as String, "EXIF Aux" ),
            ( kCGImagePropertyIPTCDictionary as String,    "IPTC" ),
            ( kCGImagePropertyPNGDictionary as String,     "PNG" ),
            ( kCGImagePropertyJFIFDictionary as String,    "JFIF" ),
        ]

    /// Builds the snapshot from a `CGImageSource` property dictionary.
    ///
    /// - Parameters:
    ///   - url:        The URL the file was loaded from.
    ///   - properties: The image's `CGImageSource` metadata dictionary.
    ///   - frameTitle: A short label for the image among the file's images, or `nil`.
    public init( url: URL, properties: [ String: Any ], frameTitle: String? )
    {
        let exif = properties[ kCGImagePropertyExifDictionary as String ] as? [ String: Any ]
        let tiff = properties[ kCGImagePropertyTIFFDictionary as String ] as? [ String: Any ]
        let gps  = properties[ kCGImagePropertyGPSDictionary as String ]  as? [ String: Any ]

        let width      = ( properties[ kCGImagePropertyPixelWidth as String ]  as? NSNumber )?.intValue ?? 0
        let height     = ( properties[ kCGImagePropertyPixelHeight as String ] as? NSNumber )?.intValue ?? 0
        let depth      = ( properties[ kCGImagePropertyDepth as String ]       as? NSNumber )?.intValue ?? 8
        let colorModel = properties[ kCGImagePropertyColorModel as String ]    as? String
        let isColor    = colorModel != ( kCGImagePropertyColorModelGray as String )

        self.url        = url
        self.dimensions = "\( width ) × \( height )"
        self.bitDepth   = "\( depth )-bit"
        self.channels   = isColor ? "3 (RGB)" : "1 (Grayscale)"
        self.isColor    = isColor
        self.frameTitle = frameTitle

        // The top-level "Image" section is built from the scalar properties; the
        // nested EXIF/TIFF/GPS groups have no scalar value and are skipped there,
        // then surfaced as their own sections below.
        var raw = [ ImageMetadataSection ]()

        if let image = ImageMetadataSection( index: 0, title: "Image", dictionary: properties )
        {
            raw.append( image )
        }

        raw.append( contentsOf: Self.metadataGroups.compactMap
        {
            group in ( properties[ group.key ] as? [ String: Any ] ).flatMap { ImageMetadataSection( index: 0, title: group.title, dictionary: $0 ) }
        } )

        // Renumber the assembled sections so their indices (and derived ids) are
        // contiguous once absent groups have been dropped.
        self.sections = raw.enumerated().map
        {
            ImageMetadataSection( index: $0.offset, title: $0.element.title, properties: $0.element.properties )
        }

        let dateString   = exif?[ kCGImagePropertyExifDateTimeOriginal as String ] as? String
        let exposureTime = ( exif?[ kCGImagePropertyExifExposureTime as String ] as? NSNumber )?.doubleValue

        self.observationDate = dateString.flatMap { Self.parseExifDate( $0 ) }
        self.exposureTime    = exposureTime
        self.coordinate      = Self.coordinate( from: gps )
        self.summaryValues   = Self.summaryValues( exif: exif, tiff: tiff, dateString: dateString, exposureTime: exposureTime )
    }

    /// The image's metadata as the format-neutral ``ImageMetadata`` the Info window
    /// consumes, so the ImageIO path feeds the same window as every other format.
    public var imageMetadata: ImageMetadata
    {
        ImageMetadata( url: self.url, sections: self.sections )
    }

    /// Parses an EXIF `DateTimeOriginal` string (`"yyyy:MM:dd HH:mm:ss"`) into a
    /// `Date`, in the POSIX locale so it is locale-independent.
    ///
    /// EXIF `DateTimeOriginal` carries no time zone, so it is interpreted in the
    /// machine's current time zone (the same convention Finder and Photos use); the
    /// resulting absolute instant therefore depends on that zone.
    ///
    /// - Parameter string: The EXIF date string.
    /// - Returns: The parsed date, or `nil` when it does not match the format.
    private static func parseExifDate( _ string: String ) -> Date?
    {
        let formatter = DateFormatter()

        formatter.locale     = Locale( identifier: "en_US_POSIX" )
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"

        return formatter.date( from: string )
    }

    /// Builds the observing site's geographic coordinate from a GPS metadata group,
    /// applying the N/S and E/W reference to sign the latitude and longitude.
    ///
    /// - Parameter gps: The GPS metadata group, or `nil`.
    /// - Returns: The signed coordinate, or `nil` when either component is absent or
    ///   the pair is the all-zero "no fix" sentinel.
    private static func coordinate( from gps: [ String: Any ]? ) -> Coordinate?
    {
        guard let gps,
              let latitude  = ( gps[ kCGImagePropertyGPSLatitude as String ]  as? NSNumber )?.doubleValue,
              let longitude = ( gps[ kCGImagePropertyGPSLongitude as String ] as? NSNumber )?.doubleValue
        else
        {
            return nil
        }

        let latitudeRef  = gps[ kCGImagePropertyGPSLatitudeRef as String ]  as? String
        let longitudeRef = gps[ kCGImagePropertyGPSLongitudeRef as String ] as? String

        return Coordinate.location(
            latitude:  latitudeRef  == "S" ? -latitude  : latitude,
            longitude: longitudeRef == "W" ? -longitude : longitude
        )
    }

    /// Builds the display-summary field values from the EXIF and TIFF groups.
    ///
    /// - Parameters:
    ///   - exif:         The EXIF metadata group, or `nil`.
    ///   - tiff:         The TIFF metadata group, or `nil`.
    ///   - dateString:   The raw EXIF `DateTimeOriginal` string, or `nil`.
    ///   - exposureTime: The exposure time in seconds, or `nil`.
    /// - Returns: The present summary values, keyed by field.
    private static func summaryValues( exif: [ String: Any ]?, tiff: [ String: Any ]?, dateString: String?, exposureTime: Double? ) -> [ InfoField: String ]
    {
        var values = [ InfoField: String ]()

        if let dateString
        {
            values[ .date ] = dateString
        }

        if let exposureTime
        {
            values[ .exposure ] = String( format: "%g s", exposureTime )
        }

        if let iso = ( exif?[ kCGImagePropertyExifISOSpeedRatings as String ] as? [ Any ] )?.compactMap( { ( $0 as? NSNumber )?.intValue } ).first
        {
            values[ .gain ] = "\( iso )"
        }

        if let model = tiff?[ kCGImagePropertyTIFFModel as String ] as? String
        {
            values[ .instrument ] = model
        }

        if let lens = exif?[ kCGImagePropertyExifLensModel as String ] as? String
        {
            values[ .telescope ] = lens
        }

        if let focalLength = ( exif?[ kCGImagePropertyExifFocalLength as String ] as? NSNumber )?.doubleValue
        {
            values[ .focalLength ] = String( format: "%g mm", focalLength )
        }

        return values
    }
}
