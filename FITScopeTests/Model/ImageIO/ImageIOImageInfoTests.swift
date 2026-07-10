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

@testable import FITScope
import Foundation
import ImageIO
import Testing

/// Tests that `ImageIOImageInfo` maps a `CGImageSource` property dictionary — the
/// structural attributes and the EXIF/TIFF/GPS groups — into the format-neutral
/// metadata model and extracts the capture date, exposure and observing-site
/// coordinate.
@Suite( "ImageIOImageInfo" )
struct ImageIOImageInfoTests
{
    private let url = URL( fileURLWithPath: "/tmp/photo.jpeg" )

    /// A full property dictionary maps the geometry, the metadata groups, and the
    /// extracted date/exposure/coordinate and summary fields.
    @Test
    func mapsFullPropertyDictionary() throws
    {
        let properties: [ String: Any ] =
            [
                kCGImagePropertyPixelWidth as String:  4000,
                kCGImagePropertyPixelHeight as String: 3000,
                kCGImagePropertyDepth as String:       8,
                kCGImagePropertyColorModel as String:  kCGImagePropertyColorModelRGB as String,
                kCGImagePropertyExifDictionary as String:
                    [
                        kCGImagePropertyExifDateTimeOriginal as String: "2026:07:09 21:30:00",
                        kCGImagePropertyExifExposureTime as String:     0.5,
                        kCGImagePropertyExifISOSpeedRatings as String:  [ 800 ],
                        kCGImagePropertyExifFocalLength as String:      135.0,
                        kCGImagePropertyExifLensModel as String:        "FITScope 135mm f/2",
                    ],
                kCGImagePropertyTIFFDictionary as String:
                    [
                        kCGImagePropertyTIFFModel as String: "TestCam 1",
                    ],
                kCGImagePropertyGPSDictionary as String:
                    [
                        kCGImagePropertyGPSLatitude as String:     33.8593,
                        kCGImagePropertyGPSLatitudeRef as String:  "S",
                        kCGImagePropertyGPSLongitude as String:    151.2044,
                        kCGImagePropertyGPSLongitudeRef as String: "E",
                    ],
            ]

        let info = ImageIOImageInfo( url: self.url, properties: properties, frameTitle: nil )

        #expect( info.dimensions == "4000 × 3000" )
        #expect( info.bitDepth == "8-bit" )
        #expect( info.channels == "3 (RGB)" )
        #expect( info.isColor )

        // The metadata groups become named sections.
        let titles = info.sections.map { $0.title }

        #expect( titles.contains( "Image" ) )
        #expect( titles.contains( "EXIF" ) )
        #expect( titles.contains( "TIFF" ) )
        #expect( titles.contains( "GPS" ) )

        // Section indices are contiguous.
        #expect( info.sections.map { $0.index } == Array( 0 ..< info.sections.count ) )

        // The capture date, exposure and coordinate are extracted; the S/E references
        // sign the latitude (negative) and leave the longitude positive.
        let date = try #require( info.observationDate )

        var components = DateComponents()

        components.year   = 2026
        components.month  = 7
        components.day    = 9
        components.hour   = 21
        components.minute = 30
        components.second = 0

        #expect( Calendar.current.dateComponents( [ .year, .month, .day, .hour, .minute, .second ], from: date ) == components )
        #expect( info.exposureTime == 0.5 )

        let coordinate = try #require( info.coordinate )

        #expect( coordinate.latitude == -33.8593 )
        #expect( coordinate.longitude == 151.2044 )

        // The summary fields come through for the Info panel.
        #expect( info.summaryValues[ .exposure ] == "0.5 s" )
        #expect( info.summaryValues[ .gain ] == "800" )
        #expect( info.summaryValues[ .instrument ] == "TestCam 1" )
        #expect( info.summaryValues[ .telescope ] == "FITScope 135mm f/2" )
        #expect( info.summaryValues[ .focalLength ] == "135 mm" )
    }

    /// An all-zero GPS pair is the "no fix" sentinel and yields no coordinate.
    @Test
    func zeroGPSCoordinateIsNoLocation()
    {
        let properties: [ String: Any ] =
            [
                kCGImagePropertyPixelWidth as String:  10,
                kCGImagePropertyPixelHeight as String: 10,
                kCGImagePropertyColorModel as String:  kCGImagePropertyColorModelRGB as String,
                kCGImagePropertyGPSDictionary as String:
                    [
                        kCGImagePropertyGPSLatitude as String:     0.0,
                        kCGImagePropertyGPSLatitudeRef as String:  "N",
                        kCGImagePropertyGPSLongitude as String:    0.0,
                        kCGImagePropertyGPSLongitudeRef as String: "E",
                    ],
            ]

        let info = ImageIOImageInfo( url: self.url, properties: properties, frameTitle: nil )

        #expect( info.coordinate == nil )
    }

    /// A grayscale colour model reports a single channel and non-colour.
    @Test
    func mapsGrayscaleColorModel()
    {
        let properties: [ String: Any ] =
            [
                kCGImagePropertyPixelWidth as String:  10,
                kCGImagePropertyPixelHeight as String: 10,
                kCGImagePropertyDepth as String:       16,
                kCGImagePropertyColorModel as String:  kCGImagePropertyColorModelGray as String,
            ]

        let info = ImageIOImageInfo( url: self.url, properties: properties, frameTitle: nil )

        #expect( info.channels == "1 (Grayscale)" )
        #expect( info.bitDepth == "16-bit" )
        #expect( info.isColor == false )
    }

    /// Absent metadata groups are not shown as empty sections, and a file with no
    /// EXIF/GPS has no extracted date, exposure or coordinate.
    @Test
    func absentGroupsAndFieldsAreOmitted()
    {
        let properties: [ String: Any ] =
            [
                kCGImagePropertyPixelWidth as String:  10,
                kCGImagePropertyPixelHeight as String: 10,
                kCGImagePropertyColorModel as String:  kCGImagePropertyColorModelRGB as String,
            ]

        let info   = ImageIOImageInfo( url: self.url, properties: properties, frameTitle: nil )
        let titles = info.sections.map { $0.title }

        #expect( titles.contains( "EXIF" ) == false )
        #expect( titles.contains( "GPS" ) == false )
        #expect( info.observationDate == nil )
        #expect( info.exposureTime == nil )
        #expect( info.coordinate == nil )
    }

    /// The neutral `ImageInformation` summary carries the geometry and the
    /// EXIF/TIFF-derived fields.
    @Test
    func buildsImageInformationSummary()
    {
        let properties: [ String: Any ] =
            [
                kCGImagePropertyPixelWidth as String:  4000,
                kCGImagePropertyPixelHeight as String: 3000,
                kCGImagePropertyDepth as String:       8,
                kCGImagePropertyColorModel as String:  kCGImagePropertyColorModelRGB as String,
                kCGImagePropertyExifDictionary as String:
                    [
                        kCGImagePropertyExifExposureTime as String:    2.0,
                        kCGImagePropertyExifISOSpeedRatings as String: [ 1600 ],
                    ],
            ]

        let info        = ImageIOImageInfo( url: self.url, properties: properties, frameTitle: nil )
        let information = ImageInformation( imageIOInfo: info )
        let rows        = information.rows

        #expect( information.dimensions == "4000 × 3000" )
        #expect( rows.contains { $0.field == .exposure && $0.value == "2 s" } )
        #expect( rows.contains { $0.field == .gain && $0.value == "1600" } )
    }
}
