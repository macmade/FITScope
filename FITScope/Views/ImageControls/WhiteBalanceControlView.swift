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

import SwiftFITS
import SwiftUI

public struct WhiteBalanceControlView: View
{
    public enum Mode: CaseIterable, CustomStringConvertible
    {
        case none
        case auto
        case manual

        public var description: String
        {
            switch self
            {
                case .none:   return "None"
                case .auto:   return "Auto"
                case .manual: return "Manual"
            }
        }
    }

    @State private var mode           = Mode.none
    @State private var showRGBSliders = false
    @State private var red            = 0.0
    @State private var green          = 0.0
    @State private var blue           = 0.0

    public var body: some View
    {
        Grid( alignment: .leading )
        {
            GridRow
            {
                Text( "Mode" )
                Picker( "Mode", selection: $mode )
                {
                    ForEach( Mode.allCases, id: \.self )
                    {
                        Text( $0.description ).tag( $0 )
                    }
                }
                .labelsHidden()
            }

            if self.showRGBSliders
            {
                SliderGridRowView( value: $red,   minimumValue: 0, maximumValue: 255, label: "Red",   image: "r.circle.fill" )
                SliderGridRowView( value: $green, minimumValue: 0, maximumValue: 255, label: "Green", image: "g.circle.fill" )
                SliderGridRowView( value: $blue,  minimumValue: 0, maximumValue: 255, label: "Blue",  image: "b.circle.fill" )
            }
        }
        .onChange( of: self.mode )
        {
            self.showRGBSliders = self.mode == .manual
        }
    }
}

#Preview
{
    WhiteBalanceControlView()
        .fixedSize( horizontal: false, vertical: true )
        .padding()
}
