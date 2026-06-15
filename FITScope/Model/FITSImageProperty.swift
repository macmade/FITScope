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

public struct FITSImageProperty: Codable, Hashable, Identifiable
{
    public let id:      String
    public let index:   Int
    public let name:    String
    public let kind:    String
    public let value:   String
    public let comment: String

    public init( index: Int, property: FITSProperty )
    {
        let value    = Self.stringForPropertyValue( property )
        self.index   = index
        self.name    = property.name
        self.kind    = property.value.kind.description
        self.value   = value ?? ""
        self.comment = property.comment ?? ""
        self.id      = "\( index )-\( property.name )-\( property.value.kind.description )-\( value ?? "<nil>" )-\( property.comment ?? "<nil>" )"
    }

    public static func stringForPropertyValue( _ property: FITSProperty ) -> String?
    {
        switch property.value.kind
        {
            case .logical:    return self.stringForLogicalValue(   property.value )
            case .integer:    return self.stringForIntegerValue(   property.value )
            case .float:      return self.stringForFloatValue(     property.value )
            case .string:     return self.stringForStringValue(    property.value )
            case .undefined:  return self.stringForUndefinedValue( property.value )
            case .unknown:    return self.stringForUnknownValue(   property.value )
            @unknown default: return nil
        }
    }

    public static func stringForLogicalValue( _ value: FITSValue ) -> String?
    {
        guard let value = value.logical
        else
        {
            return nil
        }

        return value ? "T" : "F"
    }

    public static func stringForIntegerValue( _ value: FITSValue ) -> String?
    {
        guard let value = value.integer
        else
        {
            return nil
        }

        return String( format: "%lli", value )
    }

    public static func stringForFloatValue( _ value: FITSValue ) -> String?
    {
        guard let value = value.float
        else
        {
            return nil
        }

        return String( format: "%g", value )
    }

    public static func stringForStringValue( _ value: FITSValue ) -> String?
    {
        value.string
    }

    public static func stringForUndefinedValue( _ value: FITSValue ) -> String?
    {
        nil
    }

    public static func stringForUnknownValue( _ value: FITSValue ) -> String?
    {
        guard case .unknown( let value ) = value
        else
        {
            return nil
        }

        return value
    }
}
