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

/// FITS adapters for the neutral ``WCSProjection``: building it — and its `CD`
/// matrix — from parsed FITS header metadata, keeping the FITS-keyword knowledge
/// out of the projection itself.
public extension WCSProjection
{
    /// Creates a projection from parsed FITS header metadata, or returns `nil`
    /// when it lacks a reference point, a reference pixel, or a non-degenerate
    /// linear transform. A convenience over ``init(_:)`` for the FITS path.
    ///
    /// - Parameter metadata: The parsed FITS header metadata.
    init?( metadata: FITSMetadata )
    {
        guard let wcs = metadata.worldCoordinateSystem
        else
        {
            return nil
        }

        self.init( wcs )
    }

    /// The WCS linear transform from FITS header keywords: the `CD` matrix when all
    /// four elements are present, otherwise the standard AIPS `CDELT` + `CROTA2`
    /// synthesis. Returns `nil` when neither form is available.
    ///
    /// - Parameter metadata: The parsed FITS header metadata.
    /// - Returns: The transform, or `nil`.
    static func cdMatrix( metadata: FITSMetadata ) -> CDMatrix?
    {
        if let cd11 = metadata.cd1_1, let cd12 = metadata.cd1_2, let cd21 = metadata.cd2_1, let cd22 = metadata.cd2_2
        {
            return CDMatrix( cd11: cd11, cd12: cd12, cd21: cd21, cd22: cd22 )
        }

        guard let cdelt1 = metadata.cdelt1, let cdelt2 = metadata.cdelt2
        else
        {
            return nil
        }

        // CROTA2 is the rotation of the second axis; absent, the axes are aligned.
        let rotation = ( metadata.crota2 ?? 0 ) * .pi / 180

        return CDMatrix(
            cd11:  cdelt1 * cos( rotation ),
            cd12: -cdelt2 * sin( rotation ),
            cd21:  cdelt1 * sin( rotation ),
            cd22:  cdelt2 * cos( rotation )
        )
    }
}
