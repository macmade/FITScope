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

import CoreGraphics
import Foundation

/// A gnomonic (TAN) world-coordinate projection between sky coordinates and
/// FITScope's source-display pixel space, built from a ``WorldCoordinateSystem``.
///
/// The projection needs the reference sky point, the reference pixel, and a
/// non-degenerate linear transform — all supplied by the ``WorldCoordinateSystem``.
/// It assumes the TAN projection that plate solvers (and most capture software)
/// emit; other projections are approximated by it near the field centre.
///
/// Pixels are reported in FITScope's *source-display* space: 0-based, column → x
/// (right), row → y (down), with data row 0 at the top. This matches the stars
/// and objects overlays — and means that, as with the north overlay, rising
/// declination maps to *increasing* y (the opposite of the conventional bottom-up
/// sky display), since FITScope shows row 0 at the top.
public struct WCSProjection: Sendable, Equatable
{
    /// The reference right ascension, in degrees.
    public let referenceRA: Double

    /// The reference declination, in degrees.
    public let referenceDec: Double

    /// The reference pixel along axis 1, 1-based.
    private let referencePixelX: Double

    /// The reference pixel along axis 2, 1-based.
    private let referencePixelY: Double

    /// The `CD` matrix elements, in degrees per pixel.
    private let cd11: Double
    private let cd12: Double
    private let cd21: Double
    private let cd22: Double

    /// The inverse `CD` matrix elements, in pixels per degree (precomputed).
    private let inverse11: Double
    private let inverse12: Double
    private let inverse21: Double
    private let inverse22: Double

    /// Creates a projection from a world-coordinate system, or returns `nil` when
    /// it lacks a reference point, a reference pixel, or a non-degenerate linear
    /// transform.
    ///
    /// - Parameter wcs: The world-coordinate system.
    public init?( _ wcs: WorldCoordinateSystem )
    {
        guard let referenceRA  = wcs.referenceRA,
              let referenceDec = wcs.referenceDec,
              let crpix1       = wcs.referencePixelX,
              let crpix2       = wcs.referencePixelY,
              let cd           = wcs.cdMatrix
        else
        {
            return nil
        }

        let determinant = cd.determinant

        guard determinant != 0
        else
        {
            return nil
        }

        self.referenceRA     = referenceRA
        self.referenceDec    = referenceDec
        self.referencePixelX = crpix1
        self.referencePixelY = crpix2
        self.cd11            = cd.cd11
        self.cd12            = cd.cd12
        self.cd21            = cd.cd21
        self.cd22            = cd.cd22
        self.inverse11       =  cd.cd22 / determinant
        self.inverse12       = -cd.cd12 / determinant
        self.inverse21       = -cd.cd21 / determinant
        self.inverse22       =  cd.cd11 / determinant
    }

    /// The source-space pixel a sky position projects to, or `nil` when the
    /// position lies on the far hemisphere (which a gnomonic projection cannot
    /// image).
    ///
    /// - Parameters:
    ///   - ra:  The right ascension, in degrees.
    ///   - dec: The declination, in degrees.
    /// - Returns: The 0-based source-display pixel, or `nil`.
    public func sourcePixel( ra: Double, dec: Double ) -> CGPoint?
    {
        let a0 = self.referenceRA  * .pi / 180
        let d0 = self.referenceDec * .pi / 180
        let a  = ra  * .pi / 180
        let d  = dec * .pi / 180

        // The cosine of the angular distance from the field centre; a non-positive
        // value is on or beyond the hemisphere boundary and has no gnomonic image.
        let cosDistance = ( sin( d0 ) * sin( d ) ) + ( cos( d0 ) * cos( d ) * cos( a - a0 ) )

        guard cosDistance > 0
        else
        {
            return nil
        }

        // Standard (intermediate world) coordinates, in degrees: ξ east, η north.
        let xi  = ( ( cos( d ) * sin( a - a0 ) ) / cosDistance ) * 180 / .pi
        let eta = ( ( ( cos( d0 ) * sin( d ) ) - ( sin( d0 ) * cos( d ) * cos( a - a0 ) ) ) / cosDistance ) * 180 / .pi

        // Pixel offset from the reference pixel = CD⁻¹ · (ξ, η).
        let offsetX = ( self.inverse11 * xi ) + ( self.inverse12 * eta )
        let offsetY = ( self.inverse21 * xi ) + ( self.inverse22 * eta )

        // 1-based pixel, shifted to 0-based source-display space.
        return CGPoint( x: self.referencePixelX + offsetX - 1, y: self.referencePixelY + offsetY - 1 )
    }

    /// The sky position at a source-space pixel (the inverse gnomonic projection).
    ///
    /// - Parameters:
    ///   - x: The 0-based source-display column.
    ///   - y: The 0-based source-display row.
    /// - Returns: The right ascension and declination, in degrees (RA normalised
    ///            to `0..<360`).
    public func sky( forSourceX x: Double, y: Double ) -> ( ra: Double, dec: Double )
    {
        // Back to a 1-based pixel offset, then to standard coordinates via CD.
        let offsetX = ( x + 1 ) - self.referencePixelX
        let offsetY = ( y + 1 ) - self.referencePixelY

        let xi  = ( ( self.cd11 * offsetX ) + ( self.cd12 * offsetY ) ) * .pi / 180
        let eta = ( ( self.cd21 * offsetX ) + ( self.cd22 * offsetY ) ) * .pi / 180

        let a0 = self.referenceRA  * .pi / 180
        let d0 = self.referenceDec * .pi / 180

        let radius = ( ( xi * xi ) + ( eta * eta ) ).squareRoot()

        guard radius > 0
        else
        {
            return ( self.referenceRA, self.referenceDec )
        }

        let c   = atan( radius )
        let dec = asin( ( cos( c ) * sin( d0 ) ) + ( ( eta * sin( c ) * cos( d0 ) ) / radius ) )
        let ra  = a0 + atan2( xi * sin( c ), ( radius * cos( d0 ) * cos( c ) ) - ( eta * sin( d0 ) * sin( c ) ) )

        return ( Self.normalizedRA( ra * 180 / .pi ), dec * 180 / .pi )
    }

    /// The source-space directions of north and east, as unit vectors in pixel
    /// space (y down), independent of the reference point — the inverse `CD`
    /// columns, which are the pixel directions of rising declination and right
    /// ascension at the field centre.
    ///
    /// - Returns: The north and east unit directions, or `nil` when either is
    ///            degenerate.
    public func sourceDirections() -> ( north: CGVector, east: CGVector )?
    {
        guard let north = Self.normalized( CGVector( dx: self.inverse12, dy: self.inverse22 ) ),
              let east  = Self.normalized( CGVector( dx: self.inverse11, dy: self.inverse21 ) )
        else
        {
            return nil
        }

        return ( north, east )
    }

    /// `degrees` wrapped into the `0..<360` range.
    ///
    /// - Parameter degrees: The angle, in degrees.
    /// - Returns: The wrapped angle.
    private static func normalizedRA( _ degrees: Double ) -> Double
    {
        let wrapped = degrees.truncatingRemainder( dividingBy: 360 )

        return wrapped < 0 ? wrapped + 360 : wrapped
    }

    /// The unit vector in the direction of `vector`, or `nil` when it has no
    /// length.
    ///
    /// - Parameter vector: The vector to normalise.
    /// - Returns: The unit vector, or `nil`.
    private static func normalized( _ vector: CGVector ) -> CGVector?
    {
        let length = ( ( vector.dx * vector.dx ) + ( vector.dy * vector.dy ) ).squareRoot()

        guard length > 0
        else
        {
            return nil
        }

        return CGVector( dx: vector.dx / length, dy: vector.dy / length )
    }
}
