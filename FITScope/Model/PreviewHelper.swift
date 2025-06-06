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

public enum PreviewHelper
{
    public enum TestFile
    {
        case M42
        case HST_FOS
    }

    public static func url( file: TestFile ) -> URL?
    {
        switch file
        {
            case .M42:     return Bundle.main.url( forResource: "2025-03-02_21-20-31_G252_B1x1_O7_T-9.80_F_10.00s_0000_H3.69", withExtension: "fits" )
            case .HST_FOS: return Bundle.main.url( forResource: "FOSy19g0309t_c2f", withExtension: "fits" )
        }
    }

    public static func data( file: TestFile ) -> Data?
    {
        guard let url = PreviewHelper.url( file: file )
        else
        {
            return nil
        }

        do
        {
            return try Data( contentsOf: url )
        }
        catch
        {
            return nil
        }
    }

    public static func file( file: TestFile ) -> FITSFile?
    {
        guard let url = PreviewHelper.url( file: file )
        else
        {
            return nil
        }

        do
        {
            return try FITSFile( url: url )
        }
        catch
        {
            return nil
        }
    }

    public static func info( file: TestFile ) -> FITSImageInfo?
    {
        guard let url  = self.url( file: file ),
              let file = self.file( file: file )
        else
        {
            return nil
        }

        return FITSImageInfo( url: url, file: file )
    }

    public static func section( file: TestFile ) -> FITSImageSection?
    {
        self.info( file: file )?.sections.first
    }

    public static func properties( file: TestFile ) -> [ FITSImageProperty ]?
    {
        self.section( file: file )?.properties
    }

    public static func property( file: TestFile ) -> FITSImageProperty?
    {
        self.properties( file: file )?.first
    }
}
