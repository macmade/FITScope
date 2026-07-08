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

/// Locates the FITS fixtures checked into this repository.
///
/// The fixtures live in `FITScopeUITests/Fixtures` — shared with the UI-test
/// suite — and are resolved by path rather than bundled, so tests open real
/// files exactly as the app does. They are deliberately part of this repository
/// rather than borrowed from the SwiftFITS submodule's sample files, whose
/// contents can change and silently break these tests.
enum TestFixtures
{
    /// The `Fixtures` directory, resolved relative to this source file so the
    /// suite works regardless of bundle layout or working directory.
    static var directory: URL
    {
        URL( fileURLWithPath: #filePath )
            .deletingLastPathComponent() // FITScopeTests/
            .deletingLastPathComponent() // repo root
            .appendingPathComponent( "FITScopeUITests/Fixtures" )
    }

    /// Resolves a fixture by its file name within the `Fixtures` directory.
    ///
    /// - Parameter name: e.g. `MonoImage.fits`.
    /// - Returns: The absolute URL of the fixture on disk.
    static func url( _ name: String ) -> URL
    {
        self.directory.appendingPathComponent( name )
    }

    /// A real, monochrome NAXIS = 2 image fixture that loads and renders
    /// successfully.
    static var monoImage: URL
    {
        self.url( "MonoImage.fits" )
    }

    /// A synthetic RGGB Bayer mosaic that the default `.auto` debayer demosaics
    /// to true RGB, so it renders as a colour (non-monochrome) image.
    static var colorImage: URL
    {
        self.url( "ColorImage.fits" )
    }

    /// A deliberately malformed fixture whose mandatory `SIMPLE` keyword is
    /// absent, so parsing always fails — exercising the load-failure path.
    static var invalidImage: URL
    {
        self.url( "InvalidImage.fits" )
    }

    /// A real one-dimensional (`NAXIS = 1`) synthetic spectrum: a `BITPIX = -32`
    /// flux array of 512 samples with a `WAVE` world-coordinate axis
    /// (`CRVAL1`/`CRPIX1`/`CDELT1`/`CUNIT1`) and a `BUNIT`, so it loads as a graph
    /// rather than a raster image.
    static var spectrum1D: URL
    {
        self.url( "Spectrum1D.fits" )
    }

    /// A one-dimensional (`NAXIS = 1`) file with an unsupported `BITPIX = 64`: it
    /// parses (so its header metadata is available) but its samples cannot be
    /// decoded, exercising the graceful-degradation path — the file loads with its
    /// metadata and surfaces the error at render, like a malformed 2-D file.
    static var invalidSpectrum1D: URL
    {
        self.url( "InvalidSpectrum1D.fits" )
    }
}
