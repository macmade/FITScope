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

import SwiftAstro
import SwiftUI

/// The Analysis tab's content: the results of the automatic image analysis, laid
/// out as two independent, equal peer sections in one bordered card — the
/// star-detection results (``StarsView``) above the sky-background read-out
/// (``SkyBackgroundView``).
///
/// This view is only a composer: each section is a self-contained component that
/// owns all of its own state, and each is fed its own data, so the two load and
/// render independently of each other. The canvas overlay is unaffected.
public struct AnalysisView: View
{
    /// The detected star field, or `nil` before detection has produced one.
    private let starField: StarField?

    /// Whether star detection has completed for this image.
    private let hasDetected: Bool

    /// The robust sky-background estimate, or `nil` before it has been measured.
    private let skyBackground: SkyBackground?

    /// Whether the sky-background measurement has completed for this image.
    private let hasMeasuredBackground: Bool

    /// Creates the analysis view.
    ///
    /// - Parameters:
    ///   - starField:             The detected star field, or `nil` when not yet
    ///                            available.
    ///   - hasDetected:           Whether star detection has completed.
    ///   - skyBackground:         The sky-background estimate, or `nil` when not
    ///                            yet available.
    ///   - hasMeasuredBackground: Whether the background measurement has completed.
    public init( starField: StarField?, hasDetected: Bool, skyBackground: SkyBackground?, hasMeasuredBackground: Bool )
    {
        self.starField             = starField
        self.hasDetected           = hasDetected
        self.skyBackground         = skyBackground
        self.hasMeasuredBackground = hasMeasuredBackground
    }

    /// The view's content: the two sections, each filling an equal half of the
    /// bordered card and centering its own content, split by a divider.
    public var body: some View
    {
        VStack( spacing: 16 )
        {
            StarsView( starField: self.starField, hasDetected: self.hasDetected )

            Divider()

            SkyBackgroundView( skyBackground: self.skyBackground, hasMeasured: self.hasMeasuredBackground )
        }
        .padding( 12 )
        .frame( maxWidth: .infinity, maxHeight: .infinity )
        .background( .regularMaterial )
        .clipShape( RoundedRectangle( cornerRadius: 10 ) )
        .overlay( RoundedRectangle( cornerRadius: 10 ).strokeBorder( .quaternary, lineWidth: 0.5 ) )
        // Let the counts and metrics be selected and copied, matching the other
        // info panels.
        .textSelection( .enabled )
        .accessibilityIdentifier( AccessibilityIdentifier.AnalysisView.container )
    }
}

#Preview( "Analyzing" )
{
    AnalysisView( starField: nil, hasDetected: false, skyBackground: nil, hasMeasuredBackground: false )
        .frame( width: 260, height: 300 )
        .padding()
}

#Preview( "Analyzed" )
{
    let stars: [ Star ] = ( 0 ..< 640 ).map
    {
        index in

        let position      = Double( index )
        let fwhm          = 3.1 + Double( index % 5 ) * 0.1
        let hfr           = 1.8 + Double( index % 4 ) * 0.1
        let eccentricity  = 0.2 + Double( index % 3 ) * 0.05

        return Star( x: position, y: position, flux: 1, hfr: hfr, fwhm: fwhm, eccentricity: eccentricity )
    }

    let background = SkyBackground( level: 1_532, noise: 48, minimum: 96, maximum: 65_535 )

    return AnalysisView( starField: StarField( stars: stars ), hasDetected: true, skyBackground: background, hasMeasuredBackground: true )
        .frame( width: 260, height: 300 )
        .padding()
}

#Preview( "No stars, background only" )
{
    let background = SkyBackground( level: 1_532, noise: 48, minimum: 96, maximum: 65_535 )

    return AnalysisView( starField: StarField( stars: [] ), hasDetected: true, skyBackground: background, hasMeasuredBackground: true )
        .frame( width: 260, height: 300 )
        .padding()
}
