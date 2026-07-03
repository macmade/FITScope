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

import SwiftUI

/// The catalogue objects identified in the solved field, shown as inline,
/// wrapping pills — or a placeholder when none were found.
struct PlateSolveObjectsView: View
{
    /// The identified object names.
    private let objects: [ String ]

    /// Creates the objects section.
    ///
    /// - Parameter objects: The identified object names.
    init( objects: [ String ] )
    {
        self.objects = objects
    }

    /// The view's content.
    var body: some View
    {
        VStack( alignment: .leading, spacing: 8 )
        {
            Text( "Objects in Field" )
                .font( .headline )

            if self.objects.isEmpty
            {
                Text( "No objects were identified in this field." )
                    .font( .callout )
                    .foregroundStyle( .secondary )
            }
            else
            {
                FlowLayout( horizontalSpacing: 6, verticalSpacing: 6 )
                {
                    ForEach( self.objects, id: \.self )
                    {
                        Pill( $0 )
                    }
                }
                // The identified object names are selectable/copyable; the
                // "Objects in Field" heading is left as a plain heading.
                .textSelection( .enabled )
            }
        }
    }
}

#Preview
{
    PlateSolveObjectsView( objects: [ "NGC 3628", "M 66", "NGC 3627" ] )
        .padding()
        .frame( width: 430 )
}
