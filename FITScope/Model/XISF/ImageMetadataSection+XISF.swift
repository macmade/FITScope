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
import SwiftXISF

/// XISF adapter for ``ImageMetadataSection``: builds format-neutral metadata
/// sections from an XISF image's structural attributes, its properties, and its
/// embedded FITS keywords.
public extension ImageMetadataSection
{
    /// Builds the structural section describing the image's geometry and sample
    /// layout, always present so the Info window shows the image's shape.
    ///
    /// - Parameters:
    ///   - index: The section's position within the file.
    ///   - image: The parsed XISF image.
    /// - Returns: The geometry section.
    static func geometry( index: Int, image: XISFImage ) -> ImageMetadataSection
    {
        let dimensions = ( image.geometry.dimensions + [ image.geometry.channelCount ] ).map { String( $0 ) }.joined( separator: " × " )

        var rows: [ ( name: String, value: String ) ] =
            [
                ( "Geometry", dimensions ),
                ( "Sample Format", image.sampleFormat.rawValue ),
                ( "Color Space", image.colorSpace.rawValue ),
                ( "Pixel Storage", image.pixelStorage.rawValue ),
                ( "Byte Order", image.byteOrder.rawValue ),
            ]

        if let bounds = image.bounds
        {
            rows.append( ( "Bounds", "\( bounds.lowerBound ) … \( bounds.upperBound )" ) )
        }

        if let pattern = image.colorFilterArray?.pattern
        {
            rows.append( ( "CFA Pattern", pattern ) )
        }

        if let imageType = image.imageType, imageType.isEmpty == false
        {
            rows.append( ( "Image Type", imageType ) )
        }

        if let id = image.id, id.isEmpty == false
        {
            rows.append( ( "Identifier", id ) )
        }

        let properties = rows.enumerated().map
        {
            ImageMetadataProperty( index: $0.offset, name: $0.element.name, kind: "String", value: $0.element.value, comment: "" )
        }

        return ImageMetadataSection( index: index, title: "Image", properties: properties )
    }

    /// Builds a section from a list of XISF properties, or `nil` when the list is
    /// empty (so an absent group is not shown as an empty section).
    ///
    /// Uses a distinct `xisfProperties:` label so it does not overload the neutral
    /// `init(index:title:properties:)` (which an empty `[]` literal could not
    /// disambiguate).
    ///
    /// - Parameters:
    ///   - index:          The section's position within the file.
    ///   - title:          The display title.
    ///   - xisfProperties: The XISF properties.
    /// - Returns: The section, or `nil` when `xisfProperties` is empty.
    init?( index: Int, title: String, xisfProperties: [ XISFProperty ] )
    {
        guard xisfProperties.isEmpty == false
        else
        {
            return nil
        }

        let rows = xisfProperties.enumerated().map
        {
            ImageMetadataProperty( index: $0.offset, property: $0.element )
        }

        self.init( index: index, title: title, properties: rows )
    }

    /// Builds a section from a list of embedded XISF FITS keywords, or `nil` when
    /// the list is empty.
    ///
    /// - Parameters:
    ///   - index:    The section's position within the file.
    ///   - title:    The display title.
    ///   - keywords: The embedded FITS keywords.
    /// - Returns: The section, or `nil` when `keywords` is empty.
    init?( index: Int, title: String, keywords: [ XISFFITSKeyword ] )
    {
        guard keywords.isEmpty == false
        else
        {
            return nil
        }

        let rows = keywords.enumerated().map
        {
            ImageMetadataProperty( index: $0.offset, keyword: $0.element )
        }

        self.init( index: index, title: title, properties: rows )
    }
}
