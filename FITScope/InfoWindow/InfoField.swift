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

import Cocoa
import SwiftFITS

@objc
public class InfoField: NSObject
{
    @objc public dynamic var index:   Int
    @objc public dynamic var name:    String
    @objc public dynamic var kind:    String
    @objc public dynamic var value:   String?
    @objc public dynamic var comment: String?

    public init( index: Int, property: FITSProperty )
    {
        self.index   = index
        self.name    = property.name
        self.kind    = property.kind.description
        self.value   = InfoField.stringForPropertyValue( property )
        self.comment = property.comment
    }

    public class func fields( from properties: [ FITSProperty ] ) -> [ InfoField ]
    {
        properties.enumerated().map
        {
            InfoField( index: $0.offset, property: $0.element )
        }
    }

    public class func stringForPropertyValue( _ property: FITSProperty ) -> String?
    {
        switch property.kind
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

    public class func stringForLogicalValue( _ value: Any? ) -> String?
    {
        guard let value = value as? Bool
        else
        {
            return nil
        }

        return value ? "T" : "F"
    }

    public class func stringForIntegerValue( _ value: Any? ) -> String?
    {
        guard let value = value as? Int64
        else
        {
            return nil
        }

        return String( format: "%lli", value )
    }

    public class func stringForFloatValue( _ value: Any? ) -> String?
    {
        guard let value = value as? Double
        else
        {
            return nil
        }

        return String( format: "%.4f", value )
    }

    public class func stringForStringValue( _ value: Any? ) -> String?
    {
        value as? String
    }

    public class func stringForUndefinedValue( _ value: Any? ) -> String?
    {
        nil
    }

    public class func stringForUnknownValue( _ value: Any? ) -> String?
    {
        guard let value = value
        else
        {
            return nil
        }

        return "\( value )"
    }
}
