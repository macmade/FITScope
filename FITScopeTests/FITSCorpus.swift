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

/// Locator and expectation matrix for the bundled FITS test corpus.
///
/// The corpus is the set of sample files shipped under
/// `Submodules/SwiftFITS/Test Files`. Each file is paired with the outcome the
/// real load → parse → render path produces, so a single parameterised test
/// covers the whole corpus and each entry's expected result is stated in one
/// place.
enum FITSCorpus
{
    /// The expected outcome of rendering a corpus file through the app's path.
    enum Expectation: Sendable, CustomStringConvertible
    {
        /// The file renders to an image.
        case renders

        /// The file fails to render with a known, documented reason.
        case fails( FailureReason )

        var description: String
        {
            switch self
            {
                case .renders:             return "renders"
                case .fails( let reason ): return "fails(\( reason ))"
            }
        }
    }

    /// Why a corpus file fails to render.
    ///
    /// Each case carries the substring its thrown error message contains, so a
    /// failure assertion checks the actual reason rather than merely that some
    /// error occurred. The cases are kept semantically distinct so each entry
    /// documents precisely why it does not render.
    enum FailureReason: Sendable, CustomStringConvertible
    {
        /// The padded data unit is larger than the exact pixel-data size.
        case sizeMismatch

        /// A non-2-D geometry (3-D cube / multi-plane) is not supported.
        case unsupportedGeometry

        /// The substring the thrown error message currently contains.
        var currentMessageSubstring: String
        {
            switch self
            {
                case .sizeMismatch:        return "does not match expected size"
                case .unsupportedGeometry: return "only 2-dimensional images are supported"
            }
        }

        var description: String
        {
            switch self
            {
                case .sizeMismatch:        return "sizeMismatch"
                case .unsupportedGeometry: return "unsupportedGeometry"
            }
        }
    }

    /// A single corpus entry: a file plus the outcome it should produce.
    struct File: Sendable, CustomStringConvertible
    {
        /// Path relative to the `Test Files` directory.
        let relativePath: String

        /// Short, human-readable label used in test output.
        let label: String

        /// The expected render outcome on the current `main`.
        let expectation: Expectation

        /// Absolute URL of the file on disk.
        var url: URL
        {
            FITSCorpus.directory.appendingPathComponent( self.relativePath )
        }

        var description: String
        {
            "\( self.label ) [\( self.expectation )]"
        }
    }

    /// The `Test Files` directory, resolved relative to this source file so the
    /// suite works regardless of bundle layout.
    static var directory: URL
    {
        URL( fileURLWithPath: #filePath )
            .deletingLastPathComponent() // FITScopeTests/
            .deletingLastPathComponent() // repo root
            .appendingPathComponent( "Submodules/SwiftFITS/Test Files" )
    }

    /// Resolves a corpus file by its path relative to the `Test Files` directory.
    static func url( _ relativePath: String ) -> URL
    {
        self.directory.appendingPathComponent( relativePath )
    }

    /// The 12-file corpus and the outcome each file is expected to produce.
    static let files: [ File ] =
    [
        File( relativePath: "2025-03-02_21-20-31_G252_B1x1_O7_T-9.80_F_10.00s_0000_H3.69.fits", label: "M42 (G252)",           expectation: .renders ),
        File( relativePath: "NASA/FOSy19g0309t_c2f.fits",                                       label: "HST FOS preview",      expectation: .renders ),
        File( relativePath: "NASA/FOCx38i0101t_c0f.fits",                                       label: "HST FOC",              expectation: .renders ),
        File( relativePath: "NASA/FGSf64y0106m_a1f.fits",                                       label: "HST FGS",              expectation: .renders ),
        File( relativePath: "NASA/HRSz0yd020fm_c2f.fits",                                       label: "HST HRS",              expectation: .renders ),
        File( relativePath: "NASA/UITfuv2582gc.fits",                                           label: "UIT",                  expectation: .renders ),
        File( relativePath: "NASA/WFPC2ASSNu5780205bx.fits",                                    label: "WFPC2 ASSN",           expectation: .renders ),
        File( relativePath: "NASA/WFPC2u5780205r_c0fx.fits",                                    label: "WFPC2 (NAXIS=3)",      expectation: .fails( .unsupportedGeometry ) ),
        File( relativePath: "NASA/DDTSUVDATA.fits",                                             label: "DDTSUVDATA (NAXIS=6)", expectation: .fails( .unsupportedGeometry ) ),
        File( relativePath: "NASA/EUVEngc4151imgx.fits",                                        label: "EUVE (ext image)",     expectation: .renders ),
        File( relativePath: "NASA/IUElwp25637mxlo.fits",                                        label: "IUE (ext image)",      expectation: .renders ),
        File( relativePath: "NASA/NICMOSn4hk12010_mos.fits",                                    label: "NICMOS (ext image)",   expectation: .renders ),
    ]
}
