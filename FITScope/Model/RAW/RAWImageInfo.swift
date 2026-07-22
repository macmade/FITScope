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
import SwiftAstro
import SwiftRAW

/// A `Sendable` snapshot of a camera RAW file's metadata, mirroring
/// ``XISFImageInfo`` / ``ImageIOImageInfo``: it groups SwiftRAW's structured
/// metadata (camera, exposure, lens, GPS, colour calibration) into the
/// format-neutral metadata model and derives the summary and capture fields.
///
/// This app-level type shadows `SwiftRAW.RAWImageInfo` (the wrapper's camera
/// identification struct) within the app module; the wrapper's struct is only ever
/// referenced through inferred types here, never by name.
///
/// A RAW file carries no world-coordinate system, so the astrometric fields (WCS,
/// target, plate scale) are absent and the astronomy overlays self-hide; the
/// capture date and exposure come from the shot info, and the observing-site
/// coordinate from the GPS info.
public struct RAWImageInfo: Sendable
{
    /// The URL of the source file.
    public let url: URL

    /// The image's metadata sections, in display order.
    public let sections: [ ImageMetadataSection ]

    /// The cropped mosaic's pixel layout, used to render and summarize the image.
    public let imageProperties: RAWImageProperties

    /// Whether the sensor is a colour-filter array (so the inspector offers the
    /// debayer controls and the image debayers to colour).
    public let isColorFilterArray: Bool

    /// The capture timestamp, or `nil` when the file records none.
    public let observationDate: Date?

    /// The exposure time in seconds, or `nil` when the file records none.
    public let exposureTime: Double?

    /// The capture location as the observing site's geographic coordinate (from the
    /// GPS info), or `nil` when absent.
    public let coordinate: Coordinate?

    /// The structural dimensions summary (e.g. `6960 × 4640`).
    public let dimensions: String

    /// The bit-depth summary (RAW is always 16-bit here).
    public let bitDepth: String

    /// The channel summary (`1 (CFA)` or `1 (Monochrome)`).
    public let channels: String

    /// The extra summary fields (camera, lens, ISO, focal length, capture date,
    /// exposure) for the information panel.
    public let summaryValues: [ InfoField: String ]

    /// Whether the displayed image is colour — a CFA sensor debayers to colour; a
    /// monochrome sensor does not.
    public var isColor: Bool
    {
        self.isColorFilterArray
    }

    /// A short label identifying this image; RAW files hold a single image, so this
    /// is always `nil`.
    public let frameTitle: String? = nil

    /// The image's metadata as the format-neutral ``ImageMetadata`` the Info window
    /// consumes, so the RAW path feeds the same window as every other format.
    public var imageMetadata: ImageMetadata
    {
        ImageMetadata( url: self.url, sections: self.sections )
    }

    /// Builds the snapshot from an opened SwiftRAW file.
    ///
    /// - Parameters:
    ///   - url:  The URL the file was loaded from.
    ///   - file: The opened, unpacked RAW file.
    public init( url: URL, file: RAWFile )
    {
        let sizes  = file.imageSizes
        let cfa    = file.cfaPattern
        let info   = file.imageInfo
        let shot   = file.shotInfo
        let lens   = file.lensInfo
        let color  = file.colorData
        let gps    = file.gpsInfo

        let pattern = Self.cfaPatternString( cfa: cfa, leftMargin: sizes.leftMargin, topMargin: sizes.topMargin )
        let camera  = "\( info.make ) \( info.model )".trimmingCharacters( in: .whitespaces )

        self.url                = url
        self.isColorFilterArray = pattern != nil
        self.imageProperties    = RAWImageProperties(
            width:                   sizes.width,
            height:                  sizes.height,
            colorFilterArrayPattern: pattern,
            whiteLevel:              color.maximum > 0 ? Double( color.maximum ) : nil
        )

        // An all-zero GPS pair is the "no fix" sentinel, not a real observing site,
        // so it yields no location and its GPS metadata section is dropped.
        let location = gps.flatMap { Coordinate.location( latitude: $0.latitude, longitude: $0.longitude ) }

        self.observationDate = shot.timestamp
        self.exposureTime    = shot.shutterSpeed > 0 ? Double( shot.shutterSpeed ) : nil
        self.coordinate      = location

        self.dimensions = "\( sizes.width ) × \( sizes.height )"
        self.bitDepth   = "16-bit"
        self.channels   = pattern != nil ? "1 (CFA)" : "1 (Monochrome)"

        self.sections = Self.sections( info: info, sizes: sizes, cfa: cfa, pattern: pattern, shot: shot, lens: lens, color: color, gps: location != nil ? gps : nil )

        self.summaryValues = Self.summaryValues( camera: camera, pattern: pattern, shot: shot, lens: lens )
    }

    /// Derives the cropped mosaic's colour-filter-array pattern (e.g. `"RGGB"`) from
    /// the sensor's CFA and the visible-area origin, so its Bayer phase is correct
    /// after the optical-black margins are removed.
    ///
    /// - Parameters:
    ///   - cfa:        The sensor's colour-filter array.
    ///   - leftMargin: The left margin of the visible area, in pixels.
    ///   - topMargin:  The top margin of the visible area, in pixels.
    /// - Returns: The four-letter pattern of the visible mosaic's top-left 2×2 block,
    ///   or `nil` for a non-Bayer sensor (monochrome, Foveon, or X-Trans — which the
    ///   2×2 debayer cannot describe and which the loader rejects at render).
    static func cfaPatternString( cfa: RAWCFAPattern, leftMargin: Int, topMargin: Int ) -> String?
    {
        guard cfa.kind == .bayer
        else
        {
            return nil
        }

        let positions = [ ( 0, 0 ), ( 0, 1 ), ( 1, 0 ), ( 1, 1 ) ]
        let letters    = positions.compactMap
        {
            cfa.channel( atRow: topMargin + $0.0, column: leftMargin + $0.1 )
        }

        guard letters.count == positions.count
        else
        {
            return nil
        }

        return String( letters ).uppercased()
    }

    /// Assembles the metadata sections from SwiftRAW's structured metadata, omitting
    /// empty groups and empty fields.
    private static func sections( info: SwiftRAW.RAWImageInfo, sizes: RAWImageSizes, cfa: RAWCFAPattern, pattern: String?, shot: RAWShotInfo, lens: RAWLensInfo, color: RAWColorData, gps: RAWGPSInfo? ) -> [ ImageMetadataSection ]
    {
        var groups: [ ( String, [ ( String, String ) ] ) ] = []

        groups.append( ( "Camera", [
            ( "Make",             info.make ),
            ( "Model",            info.model ),
            ( "Software",         info.software ),
            ( "Colors",           info.colors > 0 ? "\( info.colors )" : "" ),
            ( "Color Filter",     cfa.kind == .none ? "" : cfa.colorDescription ),
            ( "Bayer Pattern",    pattern ?? "" ),
            ( "DNG Version",      info.dngVersion > 0 ? "\( info.dngVersion )" : "" ),
            ( "Body Serial",      shot.bodySerial ),
        ] ) )

        groups.append( ( "Geometry", [
            ( "Visible Size",     "\( sizes.width ) × \( sizes.height )" ),
            ( "Sensor Size",      "\( sizes.rawWidth ) × \( sizes.rawHeight )" ),
            ( "Left Margin",      "\( sizes.leftMargin )" ),
            ( "Top Margin",       "\( sizes.topMargin )" ),
        ] ) )

        groups.append( ( "Exposure", [
            ( "ISO",              shot.isoSpeed     > 0 ? Self.number( shot.isoSpeed )    : "" ),
            ( "Shutter Speed",    shot.shutterSpeed > 0 ? "\( Self.number( shot.shutterSpeed ) ) s" : "" ),
            ( "Aperture",         shot.aperture     > 0 ? "f/\( Self.number( shot.aperture ) )"     : "" ),
            ( "Focal Length",     shot.focalLength  > 0 ? "\( Self.number( shot.focalLength ) ) mm"  : "" ),
            ( "Date",             shot.timestamp.map { Self.dateFormatter.string( from: $0 ) } ?? "" ),
            ( "Description",      shot.imageDescription ),
            ( "Artist",           shot.artist ),
        ] ) )

        groups.append( ( "Lens", [
            ( "Model",            lens.lensModel ),
            ( "Make",             lens.lensMake ),
            ( "Serial",           lens.lensSerial ),
            ( "35mm Equivalent",  lens.focalLengthIn35mmFormat > 0 ? "\( lens.focalLengthIn35mmFormat ) mm" : "" ),
        ] ) )

        groups.append( ( "Color", [
            ( "Black Level",      "\( color.blackLevel )" ),
            ( "Saturation",       "\( color.maximum )" ),
            ( "ICC Profile",      color.hasEmbeddedColorProfile ? "Yes" : "" ),
        ] ) )

        if let gps
        {
            groups.append( ( "GPS", [
                ( "Latitude",     Self.number( gps.latitude ) ),
                ( "Longitude",    Self.number( gps.longitude ) ),
                ( "Altitude",     "\( Self.number( gps.altitude ) ) m" ),
            ] ) )
        }

        let nonEmpty = groups.map { ( $0.0, $0.1.filter { $0.1.trimmingCharacters( in: .whitespaces ).isEmpty == false } ) }.filter { $0.1.isEmpty == false }

        return nonEmpty.enumerated().map
        {
            sectionIndex, group in

            let properties = group.1.enumerated().map
            {
                ImageMetadataProperty( index: $0.offset, name: $0.element.0, kind: "String", value: $0.element.1, comment: "" )
            }

            return ImageMetadataSection( index: sectionIndex, title: group.0, properties: properties )
        }
    }

    /// Builds the extra information-panel summary fields.
    private static func summaryValues( camera: String, pattern: String?, shot: RAWShotInfo, lens: RAWLensInfo ) -> [ InfoField: String ]
    {
        var values: [ InfoField: String ] = [ : ]

        if let pattern
        {
            values[ .bayer ] = pattern
        }

        if camera.isEmpty == false
        {
            values[ .instrument ] = camera
        }

        if lens.lensModel.isEmpty == false
        {
            values[ .telescope ] = lens.lensModel
        }

        if shot.isoSpeed > 0
        {
            values[ .gain ] = "ISO \( Self.number( shot.isoSpeed ) )"
        }

        if shot.focalLength > 0
        {
            values[ .focalLength ] = "\( Self.number( shot.focalLength ) ) mm"
        }

        if let timestamp = shot.timestamp
        {
            values[ .date ] = Self.dateFormatter.string( from: timestamp )
        }

        if shot.shutterSpeed > 0
        {
            values[ .exposure ] = "\( Self.number( shot.shutterSpeed ) ) s"
        }

        return values
    }

    /// Formats a floating-point metadata value compactly, dropping a trailing `.0`.
    ///
    /// - Parameter value: The value to format.
    /// - Returns: The compact string.
    private static func number( _ value: some BinaryFloatingPoint ) -> String
    {
        let double = Double( value )

        if double == double.rounded()
        {
            return String( Int( double ) )
        }

        return String( format: "%g", double )
    }

    /// A fixed-format formatter for capture timestamps, in the machine's time zone.
    private static let dateFormatter: DateFormatter =
    {
        let formatter = DateFormatter()

        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return formatter
    }()
}
