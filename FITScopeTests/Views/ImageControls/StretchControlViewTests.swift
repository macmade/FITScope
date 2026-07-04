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

@testable import FITScope
import Testing

/// Tests for `StretchControlView`'s pure selection-to-algorithm mapping.
@Suite( "StretchControlView" )
struct StretchControlViewTests
{
    /// The stretch control maps its selection and slider values to the matching
    /// algorithm, including the `.sigmoid` case.
    @Test
    @MainActor
    func stretchControlMapsToAlgorithm() throws
    {
        #expect( StretchControlView.algorithm( mode: .none,    logIntensity: 50, arcsinhFactor: 10, sigmoidMidpoint: 1, sigmoidContrast: 2 ) == nil )
        #expect( StretchControlView.algorithm( mode: .log,     logIntensity: 50, arcsinhFactor: 10, sigmoidMidpoint: 1, sigmoidContrast: 2 ) == .log( 50 ) )
        #expect( StretchControlView.algorithm( mode: .arcsinh, logIntensity: 50, arcsinhFactor: 10, sigmoidMidpoint: 1, sigmoidContrast: 2 ) == .arcsinh( 10 ) )
        #expect( StretchControlView.algorithm( mode: .sigmoid, logIntensity: 50, arcsinhFactor: 10, sigmoidMidpoint: 1, sigmoidContrast: 2 ) == .sigmoid( 1, 2 ) )
    }

    /// The reverse mapping — an algorithm back to the control's mode — that seeds
    /// the control and, since M27, re-syncs its displayed mode when the shared
    /// adjustments change from outside it (e.g. a Reset). A wrong mapping would
    /// leave the picker showing the wrong mode after an external change.
    @Test
    @MainActor
    func stretchControlMapsAlgorithmBackToMode() throws
    {
        #expect( StretchControlView.mode( nil )              == .none )
        #expect( StretchControlView.mode( .log( 50 ) )       == .log )
        #expect( StretchControlView.mode( .arcsinh( 10 ) )   == .arcsinh )
        #expect( StretchControlView.mode( .sigmoid( 1, 2 ) ) == .sigmoid )
    }

    /// The seeded stretch defaults are non-degenerate: the arcsinh factor is
    /// non-zero (zero throws) and the sigmoid slope is non-zero (a zero slope
    /// flattens the image to 50% grey).
    @Test
    @MainActor
    func seededDefaultsAreNonDegenerate() throws
    {
        #expect( StretchControlView.defaultArcsinhFactor != 0, "a zero arcsinh factor throws" )
        #expect( StretchControlView.defaultSigmoidN1     != 0, "a zero sigmoid slope flattens the image" )
    }

    /// Every seeded stretch default renders to a varied (non-flat, non-black)
    /// image rather than throwing or blanking.
    @Test
    @MainActor
    func seededStretchDefaultsRenderNonDegenerate() throws
    {
        let ( data, properties ) = FITSTestData.gradient()

        for mode in [ StretchControlView.Mode.log, .arcsinh, .sigmoid ]
        {
            let algorithm = StretchControlView.algorithm(
                mode:            mode,
                logIntensity:    StretchControlView.defaultLogIntensity,
                arcsinhFactor:   StretchControlView.defaultArcsinhFactor,
                sigmoidMidpoint: StretchControlView.defaultSigmoidN1,
                sigmoidContrast: StretchControlView.defaultSigmoidN2
            )
            let settings = ImageProcessor.Settings( stretch: algorithm )
            let bytes    = try ImageProcessor.render( data: data, properties: properties, settings: settings ).bytes

            #expect( bytes.contains { $0 != 0 },          "\( mode ) should not render all black" )
            #expect( bytes.contains { $0 != bytes[ 0 ] }, "\( mode ) should not render flat" )
        }
    }
}
