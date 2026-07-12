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
import Testing

/// Tests for ``FilesSidebarView``: the open-file count shown next to the "FILES"
/// header.
@Suite( "FilesSidebarView" )
struct FilesSidebarViewTests
{
    /// No files open shows no count badge, so an empty sidebar stays clean rather
    /// than reading "0".
    @Test
    func hidesTheCountWhenNoFilesAreOpen()
    {
        #expect( FilesSidebarView.fileCountLabel( for: 0 ) == nil )
    }

    /// A single open file shows "1".
    @Test
    func showsTheCountForASingleFile()
    {
        #expect( FilesSidebarView.fileCountLabel( for: 1 ) == "1" )
    }

    /// Several open files show the exact count.
    @Test
    func showsTheCountForSeveralFiles()
    {
        #expect( FilesSidebarView.fileCountLabel( for: 5 )  == "5" )
        #expect( FilesSidebarView.fileCountLabel( for: 42 ) == "42" )
    }
}
