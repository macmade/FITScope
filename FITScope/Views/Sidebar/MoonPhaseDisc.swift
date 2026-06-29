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

import SwiftUI

/// A Moon disc whose illuminated portion follows the phase: the real full-moon
/// image (the ``Moon`` vector asset) clipped to a circle, with the unlit region
/// shaded by the curved terminator — giving the true crescent / gibbous shapes
/// over the moon's actual surface rather than a flat symbol.
public struct MoonPhaseDisc: View
{
    /// The cycle position, 0…1 (0 new, 0.25 first quarter, 0.5 full, 0.75 last).
    private let fraction: Double

    /// The shading laid over the unlit region. Dark, with a hint of translucency
    /// so the night side keeps a faint "earthshine" presence rather than reading
    /// as a hole.
    private static let shadowColor = Color.black.opacity( 0.88 )

    /// Creates a moon disc.
    ///
    /// - Parameter fraction: The cycle position, 0…1.
    public init( fraction: Double )
    {
        self.fraction = fraction
    }

    /// The view's content.
    public var body: some View
    {
        Image( "Moon" )
            .resizable()
            .scaledToFit()
            .overlay
            {
                Canvas
                {
                    context, size in

                    let diameter = min( size.width, size.height )
                    let rect     = CGRect( x: ( size.width - diameter ) / 2, y: ( size.height - diameter ) / 2, width: diameter, height: diameter )

                    // Soften the terminator so it reads as a gradual shadow rather
                    // than a hard cut; the limb stays crisp via the circular clip.
                    context.addFilter( .blur( radius: diameter * 0.015 ) )
                    context.fill( Self.shadowPath( in: rect, fraction: self.fraction ), with: .color( Self.shadowColor ) )
                }
            }
            .clipShape( Circle() )
            .aspectRatio( 1, contentMode: .fit )
    }

    /// The illuminated region for a phase, within `rect`.
    ///
    /// - Parameters:
    ///   - rect:     The square the disc is drawn in.
    ///   - fraction: The cycle position, 0…1.
    /// - Returns: The lit-region path.
    nonisolated static func litPath( in rect: CGRect, fraction: Double ) -> Path
    {
        self.regionPath( in: rect, fraction: fraction, lit: true )
    }

    /// The unlit (shadowed) region for a phase — the complement of ``litPath`` —
    /// within `rect`.
    ///
    /// - Parameters:
    ///   - rect:     The square the disc is drawn in.
    ///   - fraction: The cycle position, 0…1.
    /// - Returns: The shadowed-region path.
    nonisolated static func shadowPath( in rect: CGRect, fraction: Double ) -> Path
    {
        self.regionPath( in: rect, fraction: fraction, lit: false )
    }

    /// The lit or unlit region of the disc, sampled as a polygon to avoid
    /// arc-direction pitfalls.
    ///
    /// The boundary is one limb (a semicircle — the lit side is right while waxing,
    /// left while waning; the unlit side is the opposite) joined to the terminator:
    /// a half-ellipse sharing the vertical diameter whose horizontal radius is
    /// `radius · cos(2π·fraction)`, signed so it bulges away from the lit side for a
    /// crescent and across the centre for a gibbous.
    ///
    /// - Parameters:
    ///   - rect:     The square the disc is drawn in.
    ///   - fraction: The cycle position, 0…1.
    ///   - lit:      `true` for the illuminated region, `false` for the shadow.
    /// - Returns: The region path.
    private nonisolated static func regionPath( in rect: CGRect, fraction: Double, lit: Bool ) -> Path
    {
        let radius       = min( rect.width, rect.height ) / 2
        let center       = CGPoint( x: rect.midX, y: rect.midY )
        let phaseAngle   = 2 * Double.pi * fraction
        let sideSign     = fraction <= 0.5 ? 1.0 : -1.0
        let terminatorRx = sideSign * radius * cos( phaseAngle )
        let limbRadius   = ( lit ? sideSign : -sideSign ) * radius
        let steps        = 90

        func point( atFraction t: Double, horizontalRadius: Double ) -> CGPoint
        {
            // t in 0…1 maps the angle from the top (−90°) to the bottom (+90°).
            let angle = -Double.pi / 2 + Double.pi * t

            return CGPoint( x: center.x + horizontalRadius * cos( angle ), y: center.y + radius * sin( angle ) )
        }

        var path = Path()

        // The limb, top to bottom.
        ( 0 ... steps ).forEach
        {
            i in

            let p = point( atFraction: Double( i ) / Double( steps ), horizontalRadius: limbRadius )

            if i == 0
            {
                path.move( to: p )
            }
            else
            {
                path.addLine( to: p )
            }
        }

        // The terminator, bottom back to top.
        ( 0 ... steps ).forEach
        {
            i in path.addLine( to: point( atFraction: Double( steps - i ) / Double( steps ), horizontalRadius: terminatorRx ) )
        }

        path.closeSubpath()

        return path
    }
}

#Preview
{
    HStack( spacing: 8 )
    {
        ForEach( [ 0.0, 0.15, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9 ], id: \.self )
        {
            MoonPhaseDisc( fraction: $0 ).frame( width: 48, height: 48 )
        }
    }
    .padding()
    .background( .black )
}
