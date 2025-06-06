/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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

public struct FITSImageSection: Codable, Hashable, Identifiable
{
    public let id:         String
    public let index:      Int
    public let title:      String
    public let properties: [ FITSImageProperty ]

    public init?( index: Int, section: FITSSection )
    {
        guard section.kind == .header || section.kind == .xtension
        else
        {
            return nil
        }

        let title       = Self.title( for: section )
        self.id         = "\( index )-\( title )"
        self.index      = index
        self.title      = title
        self.properties = section.properties.enumerated().map
        {
            FITSImageProperty( index: $0.offset, property: $0.element )
        }
    }

    public static func title( for section: FITSSection ) -> String
    {
        switch section.kind
        {
            case .header:

                return "Primary Header"

            case .xtension:

                if let property = section.properties.first, property.name == "XTENSION", let value = property.value as? String, value.trimmingCharacters( in: .whitespaces ).isEmpty == false
                {
                    return "Extension: \( value )"
                }

                return "Extension"

            case .data:

                return "Data"

            @unknown default:

                return "Unknown"
        }
    }
}
