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

/// Builds small, valid in-memory monolithic XISF files for the unit tests,
/// mirroring the layout SwiftXISF's own test helper produces: the 16-byte binary
/// preamble (signature, little-endian header-length, reserved) followed by the
/// UTF-8 XML header. Pixel data is carried inline via an embedded `<Data>` block,
/// so no attachment offsets are needed.
enum XISFTestData
{
    /// A single embedded `<Image>` element to place in a file.
    struct Image
    {
        var geometry: String
        var sampleFormat: String
        var colorSpace: String
        var pixelStorage: String
        var byteOrder: String
        var bounds: String?
        var cfaPattern: String?
        var displayFunction: ( m: String, s: String, h: String, l: String, r: String )?
        var keywords: [ ( name: String, value: String, comment: String? ) ]
        var properties: [ ( id: String, type: String, value: String ) ]
        var hexData: String

        init( geometry: String, sampleFormat: String, colorSpace: String, pixelStorage: String = "Planar", byteOrder: String = "little", bounds: String? = nil, cfaPattern: String? = nil, displayFunction: ( m: String, s: String, h: String, l: String, r: String )? = nil, keywords: [ ( name: String, value: String, comment: String? ) ] = [], properties: [ ( id: String, type: String, value: String ) ] = [], hexData: String )
        {
            self.geometry        = geometry
            self.sampleFormat    = sampleFormat
            self.colorSpace      = colorSpace
            self.pixelStorage    = pixelStorage
            self.byteOrder       = byteOrder
            self.bounds          = bounds
            self.cfaPattern      = cfaPattern
            self.displayFunction = displayFunction
            self.keywords        = keywords
            self.properties      = properties
            self.hexData         = hexData
        }
    }

    /// Assembles the monolithic file bytes for a header XML string.
    static func monolithic( xml: String ) -> Data
    {
        let xmlData = Data( xml.utf8 )
        var data    = Data()

        data.append( contentsOf: Array( "XISF0100".utf8 ) )
        withUnsafeBytes( of: UInt32( xmlData.count ).littleEndian ) { data.append( contentsOf: $0 ) }
        withUnsafeBytes( of: UInt32( 0 ).littleEndian )             { data.append( contentsOf: $0 ) }
        data.append( xmlData )

        return data
    }

    /// A monolithic file whose root wraps the given images.
    static func file( images: [ Image ] ) -> Data
    {
        let body = images.map( Self.imageXML ).joined()
        let xml  = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><xisf version=\"1.0\" xmlns=\"http://www.pixinsight.com/xisf\">\( body )</xisf>"

        return Self.monolithic( xml: xml )
    }

    /// The `<Image>` element XML for one image.
    static func imageXML( _ image: Image ) -> String
    {
        var attributes = "geometry=\"\( image.geometry )\" sampleFormat=\"\( image.sampleFormat )\" colorSpace=\"\( image.colorSpace )\" pixelStorage=\"\( image.pixelStorage )\" byteOrder=\"\( image.byteOrder )\""

        if let bounds = image.bounds
        {
            attributes += " bounds=\"\( bounds )\""
        }

        var children = "<Data encoding=\"hex\">\( image.hexData )</Data>"

        if let pattern = image.cfaPattern
        {
            children += "<ColorFilterArray pattern=\"\( pattern )\" width=\"2\" height=\"2\"/>"
        }

        if let df = image.displayFunction
        {
            children += "<DisplayFunction m=\"\( df.m )\" s=\"\( df.s )\" h=\"\( df.h )\" l=\"\( df.l )\" r=\"\( df.r )\"/>"
        }

        image.keywords.forEach
        {
            let comment = $0.comment.map { " comment=\"\( $0 )\"" } ?? ""

            children += "<FITSKeyword name=\"\( $0.name )\" value=\"\( $0.value )\"\( comment )/>"
        }

        image.properties.forEach
        {
            children += "<Property id=\"\( $0.id )\" type=\"\( $0.type )\" value=\"\( $0.value )\"/>"
        }

        return "<Image \( attributes ) location=\"embedded\">\( children )</Image>"
    }

    // MARK: - Sample encoding

    /// Hex-encodes bytes for an embedded `<Data encoding="hex">` block.
    static func hex( _ bytes: [ UInt8 ] ) -> String
    {
        bytes.map { String( format: "%02x", $0 ) }.joined()
    }

    /// Little-endian `UInt16` bytes for a list of sample values.
    static func uInt16LE( _ values: [ Int ] ) -> [ UInt8 ]
    {
        values.flatMap
        {
            value -> [ UInt8 ] in

            let sample = UInt16( value ).littleEndian

            return withUnsafeBytes( of: sample ) { Array( $0 ) }
        }
    }

    /// `UInt8` bytes for a list of sample values.
    static func uInt8( _ values: [ Int ] ) -> [ UInt8 ]
    {
        values.map { UInt8( $0 ) }
    }

    /// Little-endian `Float32` bytes for a list of sample values.
    static func float32LE( _ values: [ Double ] ) -> [ UInt8 ]
    {
        values.flatMap
        {
            value -> [ UInt8 ] in

            let sample = Float( value ).bitPattern.littleEndian

            return withUnsafeBytes( of: sample ) { Array( $0 ) }
        }
    }
}
