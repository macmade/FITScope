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
import SwiftAstro

/// The optional position and scale hints sent to the plate-solving service to
/// steer — and speed up — a solve, derived from an image's metadata.
///
/// Astrometry.net accepts these only as request parameters; it does **not** read
/// hints from an uploaded file's header, so they are sent alongside the image
/// regardless of its format. Every field is optional: an image with no usable
/// metadata produces empty hints (see ``isEmpty``) and the solve runs blind.
public struct PlateSolveHints: Sendable, Equatable
{
    /// The approximate image-centre right ascension, in degrees `0 ..< 360`.
    public let centerRA: Double?

    /// The approximate image-centre declination, in degrees `-90 ... 90`.
    public let centerDec: Double?

    /// The search radius around the centre, in degrees. Present only alongside a
    /// centre, and founded on the field's angular size.
    public let radius: Double?

    /// The estimated plate scale, in arc-seconds per pixel.
    public let scaleEstimate: Double?

    /// Creates hints directly from their values, for composition and testing.
    ///
    /// - Parameters:
    ///   - centerRA:      The image-centre right ascension in degrees, or `nil`.
    ///   - centerDec:     The image-centre declination in degrees, or `nil`.
    ///   - radius:        The search radius in degrees, or `nil`.
    ///   - scaleEstimate: The plate scale in arc-seconds per pixel, or `nil`.
    public init( centerRA: Double? = nil, centerDec: Double? = nil, radius: Double? = nil, scaleEstimate: Double? = nil )
    {
        self.centerRA      = centerRA
        self.centerDec     = centerDec
        self.radius        = radius
        self.scaleEstimate = scaleEstimate
    }

    /// Derives the hints from an image's pointing, plate scale and pixel
    /// dimensions.
    ///
    /// The scale hint is included whenever a positive plate scale is known. The
    /// position hint (centre + radius) is included only when the pointing, the
    /// plate scale *and* the dimensions are all known, so the search radius can be
    /// founded on the field's real angular size: the radius is the field's longest
    /// angular extent (`pixelScale · max(width, height)`), which generously covers
    /// the field and the pointing error. A right ascension is wrapped into
    /// `0 ..< 360`; a declination outside `-90 ... 90` drops the position hint.
    ///
    /// - Parameters:
    ///   - coordinate: The image-centre pointing, or `nil`.
    ///   - pixelScale: The plate scale in arc-seconds per pixel, or `nil`.
    ///   - dimensions: The image's pixel dimensions, or `nil`.
    public init( coordinate: EquatorialCoordinate?, pixelScale: Double?, dimensions: ( width: Int, height: Int )? )
    {
        let scale = pixelScale.flatMap { $0 > 0 ? $0 : nil }

        self.scaleEstimate = scale

        guard let coordinate,
              ( -90.0 ... 90.0 ).contains( coordinate.declination ),
              let scale,
              let dimensions,
              dimensions.width > 0,
              dimensions.height > 0
        else
        {
            self.centerRA  = nil
            self.centerDec = nil
            self.radius    = nil

            return
        }

        self.centerRA  = Self.normalizedRightAscension( coordinate.rightAscension )
        self.centerDec = coordinate.declination
        self.radius    = scale * Double( max( dimensions.width, dimensions.height ) ) / 3600.0
    }

    /// Whether no hint at all is available, so the solve would run blind.
    public var isEmpty: Bool
    {
        self.centerRA == nil && self.centerDec == nil && self.radius == nil && self.scaleEstimate == nil
    }

    /// Wraps a right ascension into the `0 ..< 360` degree range the service
    /// expects.
    ///
    /// - Parameter ra: The right ascension in degrees.
    /// - Returns: The equivalent angle in `0 ..< 360`.
    private static func normalizedRightAscension( _ ra: Double ) -> Double
    {
        let wrapped = ra.truncatingRemainder( dividingBy: 360 )

        return wrapped < 0 ? wrapped + 360 : wrapped
    }
}
