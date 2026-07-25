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
/// Most fixtures live in the app's `Test Files` — shared with the UI-test suite —
/// and are resolved by path rather than bundled, so tests open real files exactly
/// as the app does. They are deliberately part of this repository rather than
/// borrowed from the SwiftFITS submodule's sample files, whose contents can change
/// and silently break these tests. The full-frame ``cameraRAW`` capture is the
/// exception: it lives in the bundled `SwiftAstro` submodule's own `Test Files`,
/// alongside the frames the library validates against.
enum TestFixtures
{
    /// The `Test Files` directory at the repository root, resolved relative to this
    /// source file so the suite works regardless of bundle layout or working
    /// directory.
    static var testFilesDirectory: URL
    {
        URL( fileURLWithPath: #filePath )
            .deletingLastPathComponent() // FITScopeTests/
            .deletingLastPathComponent() // repo root
            .appendingPathComponent( "Test Files" )
    }

    /// The `Test Files` directory in the bundled `SwiftAstro` submodule, holding
    /// the full-frame captures. The heavy captures moved there so the library's
    /// real-frame validation can consume them; only their location changed.
    static var capturesDirectory: URL
    {
        URL( fileURLWithPath: #filePath )
            .deletingLastPathComponent() // FITScopeTests/
            .deletingLastPathComponent() // repo root
            .appendingPathComponent( "Submodules/SwiftAstro/Test Files" )
    }

    /// Resolves a fixture by its file name within the `Test Files` directory.
    ///
    /// - Parameter name: e.g. `MonoImage.fits`.
    /// - Returns: The absolute URL of the fixture on disk.
    static func url( _ name: String ) -> URL
    {
        self.testFilesDirectory.appendingPathComponent( name )
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

    /// A real RGB colour-planes image (`NAXIS = 3`, third axis = 3, `BITPIX = 16`)
    /// with `CTYPE1`/`CTYPE2` and a TAN WCS: three band-sequential planes combined
    /// into a single colour image, so it renders as colour (non-monochrome) without
    /// being a colour-filter array.
    static var rgbImage: URL
    {
        self.url( "RGBImage.fits" )
    }

    /// A real one-dimensional (`NAXIS = 1`) synthetic spectrum: a `BITPIX = -32`
    /// flux array of 512 samples with a `WAVE` world-coordinate axis
    /// (`CRVAL1`/`CRPIX1`/`CDELT1`/`CUNIT1`) and a `BUNIT`, so it loads as a graph
    /// rather than a raster image.
    static var spectrum1D: URL
    {
        self.url( "Spectrum1D.fits" )
    }

    /// A real multi-image `NAXIS = 3` cube (`BITPIX = 16`) whose third axis holds
    /// four distinct 2-D image planes — not RGB colour planes — so it loads as four
    /// separate frames surfaced in the carousel.
    static var multiImageCube: URL
    {
        self.url( "MultiImage3D.fits" )
    }

    /// A real two-dimensional stacked-spectra fixture (`NAXIS = 2`, `BITPIX = -32`):
    /// three distinct 1024-sample spectra as rows, with a spectral `WAVE`
    /// world-coordinate axis (`CRVAL1`/`CRPIX1`/`CDELT1`/`CUNIT1`) and a `BUNIT`, so
    /// it loads as a multi-line graph rather than a raster image.
    static var stackedSpectra: URL
    {
        self.url( "StackedSpectra.fits" )
    }

    /// A real RGB XISF image (`8 × 8`, three planar `UInt16` planes) carrying
    /// embedded FITS keywords — an object name, exposure, capture date and a TAN
    /// WCS — so it loads as a colour image whose astrometry fields come through the
    /// shared metadata path.
    static var xisfImage: URL
    {
        self.url( "RGBImage.xisf" )
    }

    /// A real multi-image XISF file: three distinct `6 × 4` grayscale `UInt16`
    /// images in one file, each with its own `id`, `OBJECT` and `DATE-OBS`, so it
    /// loads as three carousel frames.
    static var xisfMultiImage: URL
    {
        self.url( "MultiImage.xisf" )
    }

    /// A one-dimensional (`NAXIS = 1`) file with an unsupported `BITPIX = 64`: it
    /// parses (so its header metadata is available) but its samples cannot be
    /// decoded, exercising the graceful-degradation path — the file loads with its
    /// metadata and surfaces the error at render, like a malformed 2-D file.
    static var invalidSpectrum1D: URL
    {
        self.url( "InvalidSpectrum1D.fits" )
    }

    /// A real 8-bit RGB PNG (`4 × 3`) with a deterministic, lossless pattern: the
    /// top-left pixel is `(10, 20, 100)` and the values step across (red) and down
    /// (green), so tests can assert exact decoded samples and detect a vertical flip.
    static var photoRGB: URL
    {
        self.url( "PhotoRGB.png" )
    }

    /// A real 16-bit grayscale TIFF (`4 × 3`) with a deterministic, lossless
    /// gradient, so tests can assert a 16-bit decode and the read-out fraction.
    static var photoGray16: URL
    {
        self.url( "PhotoGray16.tiff" )
    }

    /// A real JPEG (`8 × 8`, RGB) carrying EXIF, TIFF and GPS metadata — a capture
    /// date, exposure, ISO, camera model, lens and a southern/eastern-hemisphere GPS
    /// location — so tests can assert the metadata mapping (and the GPS reference
    /// signing) end to end.
    static var photoExif: URL
    {
        self.url( "PhotoExif.jpeg" )
    }

    /// A real Canon camera RAW file (`.cr3`): a linear, undemosaiced colour-filter-array
    /// sensor mosaic decoded through SwiftRAW (LibRAW), so tests can assert the RAW load,
    /// the debayered colour render, and the camera/exposure metadata end to end.
    ///
    /// It lives in the bundled `SwiftAstro` submodule's `Test Files` directory,
    /// alongside the other full-frame captures the library validates against — not
    /// in the app's own `Test Files`, which now holds only the synthetic fixtures.
    static var cameraRAW: URL
    {
        self.capturesDirectory.appendingPathComponent( "C6-R7-M42-Light.cr3" )
    }

    /// A real single-image HEIC (`8 × 8`, RGB) carrying an EXIF capture date, so tests
    /// can assert the HEIC load and metadata mapping through the shared ImageIO path.
    static var photoHEIC: URL
    {
        self.url( "PhotoHEIC.heic" )
    }

    /// A real multi-image HEIC: three distinct `6 × 4` images in one container, so tests
    /// can assert that the contained images surface as separate carousel frames.
    static var multiImageHEIC: URL
    {
        self.url( "MultiImageHEIC.heic" )
    }

    /// A real lossless TIFF stored `4 × 2` with an EXIF orientation of `6` (rotate 90°
    /// clockwise for display) and its stored top-left pixel white, so tests can assert
    /// that the decode applies the orientation: it uprights to `2 × 4` with the white
    /// pixel at the top-right.
    static var orientedPhoto: URL
    {
        self.url( "OrientedPhoto.tiff" )
    }
}
