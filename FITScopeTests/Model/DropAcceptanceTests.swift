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
import Testing
@testable import FITScope

/// Tests for `DropAcceptance.acceptable(_:)`: regular files are accepted
/// regardless of extension; directories are rejected.
@Suite( "DropAcceptance" )
struct DropAcceptanceTests
{
    @Test
    func acceptsAnyRegularFileRegardlessOfExtension() throws
    {
        let dir  = URL( fileURLWithPath: NSTemporaryDirectory() )
        let fits = dir.appendingPathComponent( "a.fits" )
        let odd  = dir.appendingPathComponent( "b.bin" )

        try Data( [ 0 ] ).write( to: fits )
        try Data( [ 0 ] ).write( to: odd )

        defer
        {
            try? FileManager.default.removeItem( at: fits )
            try? FileManager.default.removeItem( at: odd )
        }

        #expect( DropAcceptance.acceptable( fits ) )
        #expect( DropAcceptance.acceptable( odd ), "invalid/odd files are accepted so the loader can surface an error" )
    }

    @Test
    func rejectsDirectories() throws
    {
        #expect( DropAcceptance.acceptable( URL( fileURLWithPath: NSTemporaryDirectory() ) ) == false )
    }
}
