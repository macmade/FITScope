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
import SwiftUtilities

/// Assembles the third-party project credits shown in the Credits window.
///
/// FITScope is built on a set of open-source libraries; each is credited here
/// with its author, description, website and full license text. The license
/// texts ship as bundled `.txt` resources and are loaded at runtime, so this
/// type only names the resource file for each project rather than embedding the
/// text inline.
enum AppCredits
{
    /// The author of the project's own libraries, credited by default.
    private static let defaultAuthor = "Jean-David Gadina"

    /// Every credited project.
    ///
    /// The projects are listed in no particular order — the Credits window sorts
    /// them alphabetically for display.
    static var all: [ Credit ]
    {
        [
            self.credit(
                name:        "SwiftAstro",
                description: "Astrophotography support library for Swift.",
                website:     "https://github.com/macmade/SwiftAstro",
                licenseName: "MIT",
                licenseFile: "License-SwiftAstro"
            ),
            self.credit(
                name:        "SwiftFITS",
                description: "FITS image library for Swift.",
                website:     "https://github.com/macmade/SwiftFITS",
                licenseName: "MIT",
                licenseFile: "License-SwiftFITS"
            ),
            self.credit(
                name:        "SwiftPixel",
                description: "Pixel processing library for Swift.",
                website:     "https://github.com/macmade/SwiftPixel",
                licenseName: "MIT",
                licenseFile: "License-SwiftPixel"
            ),
            self.credit(
                name:        "SwiftRAW",
                description: "RAW image library for Swift.",
                website:     "https://github.com/macmade/SwiftRAW",
                licenseName: "MIT",
                licenseFile: "License-SwiftRAW"
            ),
            self.credit(
                name:        "SwiftUtilities",
                description: "Miscellaneous Swift utilities for macOS apps.",
                website:     "https://github.com/macmade/SwiftUtilities",
                licenseName: "MIT",
                licenseFile: "License-SwiftUtilities"
            ),
            self.credit(
                name:        "SwiftXISF",
                description: "XISF image library for Swift.",
                website:     "https://github.com/macmade/SwiftXISF",
                licenseName: "MIT",
                licenseFile: "License-SwiftXISF"
            ),
            self.credit(
                name:        "LibRAW",
                author:      "LibRAW LLC",
                description: "Library for reading RAW files from digital cameras.",
                website:     "https://www.libraw.org",
                licenseName: "CDDL-1.0",
                licenseFile: "License-LibRAW"
            ),
        ]
    }

    /// Builds a single credit, loading its license text from the bundled resource.
    ///
    /// - Parameters:
    ///   - name:        The project's name.
    ///   - author:      The project's author. Defaults to ``defaultAuthor``.
    ///   - description: A human-readable description of the project.
    ///   - website:     The project's website, as a string to parse into a URL.
    ///   - licenseName: The name of the license, shown as a pill.
    ///   - licenseFile: The base name of the bundled license resource, without
    ///                  its `.txt` extension.
    /// - Returns: The assembled credit.
    private static func credit( name: String, author: String = AppCredits.defaultAuthor, description: String, website: String, licenseName: String, licenseFile: String ) -> Credit
    {
        Credit(
            name:        name,
            author:      author,
            description: description,
            website:     URL( string: website ),
            licenseName: licenseName,
            licenseText: self.licenseText( named: licenseFile )
        )
    }

    /// Loads the full text of a bundled license resource.
    ///
    /// - Parameter name: The base name of the resource, without its `.txt`
    ///                   extension.
    /// - Returns: The license text, or an empty string when the resource is
    ///            missing or unreadable.
    private static func licenseText( named name: String ) -> String
    {
        guard let url  = Bundle.main.url( forResource: name, withExtension: "txt" ),
              let text = try? String( contentsOf: url, encoding: .utf8 )
        else
        {
            return ""
        }

        return text
    }
}
