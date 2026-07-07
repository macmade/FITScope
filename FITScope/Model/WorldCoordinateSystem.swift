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

/// The world-coordinate system attached to an image: the parameters that map its
/// pixels to sky positions. Format-neutral — any format (or a plate-solve result)
/// that carries astrometry supplies one, however it stores those parameters.
///
/// Both the reference point and the linear transform are optional, so this can
/// describe a full astrometric solution (reference point + transform, which
/// ``WCSProjection`` needs) or an orientation-only WCS (a transform alone, from
/// which north/east directions can still be derived without a sky position).
public struct WorldCoordinateSystem: Sendable, Equatable
{
    /// The reference right ascension along axis 1, in degrees, or `nil` when the
    /// WCS carries no reference point.
    public let referenceRA: Double?

    /// The reference declination along axis 2, in degrees, or `nil` when the WCS
    /// carries no reference point.
    public let referenceDec: Double?

    /// The reference pixel along axis 1, 1-based, or `nil`.
    public let referencePixelX: Double?

    /// The reference pixel along axis 2, 1-based, or `nil`.
    public let referencePixelY: Double?

    /// The linear transform mapping pixel offsets to intermediate world
    /// coordinates (the `CD` matrix, in degrees per pixel), or `nil` when the WCS
    /// carries no orientation.
    public let cdMatrix: CDMatrix?

    /// Creates a world-coordinate system from its parameters.
    ///
    /// - Parameters:
    ///   - referenceRA:     The reference right ascension, in degrees.
    ///   - referenceDec:    The reference declination, in degrees.
    ///   - referencePixelX: The reference pixel along axis 1, 1-based.
    ///   - referencePixelY: The reference pixel along axis 2, 1-based.
    ///   - cdMatrix:        The linear transform (`CD` matrix), in degrees per pixel.
    public init( referenceRA: Double?, referenceDec: Double?, referencePixelX: Double?, referencePixelY: Double?, cdMatrix: CDMatrix? )
    {
        self.referenceRA     = referenceRA
        self.referenceDec    = referenceDec
        self.referencePixelX = referencePixelX
        self.referencePixelY = referencePixelY
        self.cdMatrix        = cdMatrix
    }
}
