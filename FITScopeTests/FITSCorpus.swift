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
/// real load → parse → render path produces, so the corpus suite acts as a
/// running scoreboard: a milestone that fixes a defect flips the affected
/// entries from `.fails(...)` to `.renders` with a one-line edit.
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

    /// Why a corpus file fails to render today.
    ///
    /// Each case also carries the substring its thrown error message contains
    /// at present, so the baseline asserts the *actual* current behaviour while
    /// keeping the semantic intent distinct (different reasons are fixed by
    /// different milestones).
    enum FailureReason: Sendable, CustomStringConvertible
    {
        /// C-1: the padded data unit is larger than the exact pixel-data size.
        case sizeMismatch

        /// M-2: a non-2-D geometry (3-D cube / multi-plane) is not supported.
        case unsupportedGeometry

        /// M-1: the image lives in an extension HDU but the primary header
        /// (`NAXIS=0`) is consulted instead, so it is never reached.
        case extensionImageUnreached

        /// The substring the thrown error message currently contains.
        var currentMessageSubstring: String
        {
            switch self
            {
                case .sizeMismatch:            return "does not match expected size"
                case .unsupportedGeometry:     return "Unsupported NAXIS value"
                case .extensionImageUnreached: return "Unsupported NAXIS value"
            }
        }

        var description: String
        {
            switch self
            {
                case .sizeMismatch:            return "sizeMismatch"
                case .unsupportedGeometry:     return "unsupportedGeometry"
                case .extensionImageUnreached: return "extensionImageUnreached"
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

    /// The 12-file corpus and its baseline expectations on the current `main`.
    ///
    /// Only the M42 (`G252`) file renders today; every other entry fails with
    /// its documented reason. Milestones flip individual entries to `.renders`.
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
        File( relativePath: "NASA/EUVEngc4151imgx.fits",                                        label: "EUVE (ext image)",     expectation: .fails( .extensionImageUnreached ) ),
        File( relativePath: "NASA/IUElwp25637mxlo.fits",                                        label: "IUE (ext image)",      expectation: .fails( .extensionImageUnreached ) ),
        File( relativePath: "NASA/NICMOSn4hk12010_mos.fits",                                    label: "NICMOS (ext image)",   expectation: .fails( .extensionImageUnreached ) ),
    ]
}
