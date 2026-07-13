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

import AppKit
import SwiftUI

/// The before/after comparison wipe drawn over the image canvas.
///
/// The processed result is shown by ``ZoomableImageView`` underneath; this layer
/// reveals the captured "before" image on the left of a draggable vertical
/// divider by drawing it into the same on-screen rectangle the result occupies
/// (reported as ``displayedRect``), clipped to the left region. Because both
/// images share that rectangle — and the before image is rendered at the same
/// orientation as the result — they stay registered pixel-for-pixel under zoom,
/// pan, rotate and flip, for free.
///
/// Only the divider handle is interactive; the rest of the layer is hit-test
/// transparent so panning the image underneath keeps working. Dragging the handle
/// reports a new divider fraction through ``onFractionChange`` (the caller clamps
/// it), so the divider position stays the single source of truth in the canvas
/// controller.
public struct ImageComparisonLayer: View
{
    /// The captured "before" image, revealed on the left of the divider.
    private let beforeImage: CGImage

    /// The on-screen rectangle the image occupies, in this layer's coordinate
    /// space — the very rectangle ``ZoomableImageView`` draws the result into, so
    /// the before image registers with it exactly.
    private let displayedRect: CGRect

    /// The divider position as a fraction of the viewport width (`0` reveals only
    /// the processed result, `1` only the captured before).
    private let fraction: CGFloat

    /// Called with the proposed divider fraction as the handle is dragged; the
    /// caller clamps and stores it.
    private let onFractionChange: ( CGFloat ) -> Void

    /// The full width of the invisible, draggable strip centred on the divider, so
    /// the handle is easy to grab while drags elsewhere fall through to panning.
    private static let handleStripWidth: CGFloat = 30

    /// The name of the coordinate space the drag reads its location in, so the
    /// fraction is measured against the whole layer rather than the moving handle.
    private static let coordinateSpace = "ImageComparisonLayer"

    /// Creates the comparison layer.
    ///
    /// - Parameters:
    ///   - beforeImage:      The captured "before" image to reveal on the left.
    ///   - displayedRect:    The on-screen rectangle the image occupies.
    ///   - fraction:         The divider position (a fraction of the width).
    ///   - onFractionChange: Called with the proposed fraction as the handle
    ///                       is dragged.
    public init( beforeImage: CGImage, displayedRect: CGRect, fraction: CGFloat, onFractionChange: @escaping ( CGFloat ) -> Void )
    {
        self.beforeImage      = beforeImage
        self.displayedRect    = displayedRect
        self.fraction         = fraction
        self.onFractionChange = onFractionChange
    }

    /// The view's content.
    public var body: some View
    {
        GeometryReader
        {
            geometry in

            let width    = max( geometry.size.width, 1 )
            let dividerX = width * self.fraction

            ZStack( alignment: .topLeading )
            {
                self.beforeReveal( dividerX: dividerX )
                self.labels
                self.divider( dividerX: dividerX, height: geometry.size.height, width: width )
            }
            .coordinateSpace( .named( Self.coordinateSpace ) )
        }
    }

    /// The captured before image, drawn into the shared displayed rectangle and
    /// clipped to the region left of the divider. Non-interactive, so panning the
    /// result underneath still works everywhere but the handle.
    private func beforeReveal( dividerX: CGFloat ) -> some View
    {
        Canvas
        {
            context, size in

            // At the far-left divider (`dividerX == 0`) or a transient zero-height
            // layout there is no region to reveal. Clipping to the resulting empty
            // rect would draw the same nothing but makes Core Graphics log
            // "clip: empty path.", so skip the clip and draw entirely.
            guard Self.revealsBeforeImage( dividerX: dividerX, height: size.height )
            else
            {
                return
            }

            context.clip( to: Path( CGRect( x: 0, y: 0, width: dividerX, height: size.height ) ) )
            context.draw( Image( decorative: self.beforeImage, scale: 1, orientation: .up ), in: self.displayedRect )
        }
        .allowsHitTesting( false )
    }

    /// Whether the before image has any region to reveal at the given divider
    /// position and canvas height.
    ///
    /// False at the far-left divider (`dividerX == 0`) or a transient zero-height
    /// layout, where the reveal rect would be empty — clipping to it draws nothing
    /// anyway but makes Core Graphics log "clip: empty path.".
    ///
    /// - Parameters:
    ///   - dividerX: The divider's x position, in points from the left edge.
    ///   - height:   The canvas height, in points.
    /// - Returns: `true` when there is a non-empty region to reveal.
    nonisolated static func revealsBeforeImage( dividerX: CGFloat, height: CGFloat ) -> Bool
    {
        dividerX > 0 && height > 0
    }

    /// The "Before" / "After" corner labels, marking which side is which.
    private var labels: some View
    {
        HStack
        {
            self.label( "Before" )
            Spacer()
            self.label( "After" )
        }
        .padding( 12 )
        .frame( maxWidth: .infinity, maxHeight: .infinity, alignment: .top )
        .allowsHitTesting( false )
    }

    /// A single translucent corner label.
    private func label( _ text: String ) -> some View
    {
        Text( text )
            .font( .caption.weight( .semibold ) )
            .foregroundStyle( .white )
            .padding( .horizontal, 8 )
            .padding( .vertical, 3 )
            .background( .ultraThinMaterial, in: Capsule() )
            .overlay( Capsule().stroke( .white.opacity( 0.15 ) ) )
    }

    /// The draggable divider: a full-height line with a central grab handle,
    /// sitting inside an invisible strip that captures the drag. The strip is the
    /// only interactive part of the layer.
    private func divider( dividerX: CGFloat, height: CGFloat, width: CGFloat ) -> some View
    {
        ZStack
        {
            Rectangle()
                .fill( .white )
                .frame( width: 2 )
                .shadow( color: .black.opacity( 0.5 ), radius: 2 )

            Image( systemName: "arrow.left.and.right" )
                .font( .system( size: 12, weight: .bold ) )
                .foregroundStyle( .black )
                .padding( 7 )
                .background( Circle().fill( .white ) )
                .shadow( color: .black.opacity( 0.5 ), radius: 2 )
        }
        .frame( width: Self.handleStripWidth, height: height )
        .contentShape( Rectangle() )
        .position( x: dividerX, y: height / 2 )
        .gesture(
            DragGesture( minimumDistance: 0, coordinateSpace: .named( Self.coordinateSpace ) )
                .onChanged { value in self.onFractionChange( value.location.x / width ) }
        )
        .accessibilityIdentifier( AccessibilityIdentifier.ImageComparisonLayer.divider )
    }
}

#Preview
{
    // A stand-in for the processed result — which is drawn by the canvas
    // underneath in the app — with a synthetic "before" image so the wipe is
    // visible in isolation. Drag the handle to move the divider.
    @Previewable @State var fraction: CGFloat = 0.5

    if let before = previewImage()
    {
        ImageComparisonLayer( beforeImage: before, displayedRect: CGRect( x: 20, y: 20, width: 360, height: 260 ), fraction: fraction )
        {
            fraction = min( max( $0, 0 ), 1 )
        }
        .background( LinearGradient( colors: [ .orange, .red ], startPoint: .topLeading, endPoint: .bottomTrailing ) )
        .frame( width: 400, height: 300 )
    }
}

/// Builds a synthetic gradient image for the preview, standing in for a captured
/// "before" frame. Returns `nil` if a bitmap context cannot be created.
private func previewImage() -> CGImage?
{
    let width  = 360
    let height = 260

    guard let context = CGContext( data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue )
    else
    {
        return nil
    }

    let colors = [ NSColor.systemTeal.cgColor, NSColor.systemIndigo.cgColor ] as CFArray

    guard let gradient = CGGradient( colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [ 0, 1 ] )
    else
    {
        return nil
    }

    context.drawLinearGradient( gradient, start: .zero, end: CGPoint( x: width, y: height ), options: [] )

    return context.makeImage()
}
