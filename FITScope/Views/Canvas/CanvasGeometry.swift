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

/// Pure geometry for the zoomable canvas: the magnification that fits content
/// into a viewport, and the document-space origin that centres it.
public enum CanvasGeometry
{
    /// The magnification at which `content` fits entirely within `visible`,
    /// i.e. the smaller of the width and height ratios. Returns `0` for any
    /// non-positive dimension.
    public static func fitFactor( content: CGSize, visible: CGSize ) -> CGFloat
    {
        guard content.width > 0, content.height > 0, visible.width > 0, visible.height > 0
        else
        {
            return 0
        }

        return min( visible.width / content.width, visible.height / content.height )
    }

    /// The document-space origin of the visible rectangle that centres
    /// `content` within a viewport whose size, expressed in document space, is
    /// `visibleInDocumentSpace` (i.e. the clip bounds divided by magnification).
    public static func centeredOrigin( content: CGSize, visibleInDocumentSpace: CGSize ) -> CGPoint
    {
        CGPoint(
            x: ( content.width  - visibleInDocumentSpace.width  ) / 2,
            y: ( content.height - visibleInDocumentSpace.height ) / 2
        )
    }

    /// `value` clamped to `min...max`.
    public static func clamp( _ value: CGFloat, min lower: CGFloat, max upper: CGFloat ) -> CGFloat
    {
        Swift.max( lower, Swift.min( upper, value ) )
    }

    /// The relative tolerance used when comparing magnifications, so that
    /// floating-point rounding at a bound reads as equality.
    private static let tolerance: CGFloat = 0.0001

    /// The magnification at which `content` fits entirely within `visible`,
    /// clamped to the scroll view's `minimum...maximum` magnification range so an
    /// extreme content-to-viewport ratio can't push it past those limits. This is
    /// the magnification a "fit" applies, and re-evaluating it after a viewport
    /// resize keeps a fitted image fitted. Returns `0` for degenerate sizes.
    public static func boundedFitFactor( content: CGSize, visible: CGSize, minimum: CGFloat, maximum: CGFloat ) -> CGFloat
    {
        let factor = self.fitFactor( content: content, visible: visible )

        guard factor > 0
        else
        {
            return 0
        }

        return self.clamp( factor, min: minimum, max: maximum )
    }

    /// The smallest useful magnification given a `fitFactor`: zooming out past the
    /// point where the whole image is visible only adds empty margin, so the fit
    /// factor is the lower bound — but never above actual size (so 100% stays
    /// reachable for a small image scaled up to fit) nor below `floor`.
    public static func minimumMagnification( fitFactor: CGFloat, floor: CGFloat ) -> CGFloat
    {
        Swift.max( floor, Swift.min( fitFactor, 1.0 ) )
    }

    /// Whether zoom-out remains useful: `true` while `magnification` sits
    /// meaningfully above the `minimum` bound. At or below the bound the whole
    /// image is already visible, so zoom-out is disabled.
    public static func canZoomOut( magnification: CGFloat, minimum: CGFloat ) -> Bool
    {
        guard minimum > 0
        else
        {
            return true
        }

        return magnification > minimum * ( 1 + self.tolerance )
    }

    /// Whether `magnification` is at the `fitMagnification` (within tolerance),
    /// used to keep a fitted image fitted across viewport resizes. Distinct from
    /// the zoom-out bound, since a small image fits while scaled up above 100%.
    public static func isFitted( magnification: CGFloat, fitMagnification: CGFloat ) -> Bool
    {
        guard fitMagnification > 0
        else
        {
            return false
        }

        return abs( magnification - fitMagnification ) <= fitMagnification * self.tolerance
    }

    /// The magnification to display after a viewport resize. A fitted image
    /// follows the new `fitMagnification`; a zoomed-in image keeps its
    /// magnification while it still fills the viewport, but never drops below the
    /// fit magnification — otherwise the viewport would have grown past the image
    /// and show black borders on all sides.
    public static func magnificationAfterResize( currentMagnification: CGFloat, fitMagnification: CGFloat, wasFitted: Bool ) -> CGFloat
    {
        wasFitted ? fitMagnification : Swift.max( currentMagnification, fitMagnification )
    }

    /// The point in the canvas (overlay) coordinate space corresponding to an
    /// image-pixel point.
    ///
    /// `displayedRect` is the on-screen rectangle the full image currently
    /// occupies; because it already encodes magnification, pan and the centering
    /// of a small image, mapping an image point into it needs no separate zoom or
    /// offset terms.
    public static func viewPoint( forImagePoint point: CGPoint, imageSize: CGSize, displayedRect: CGRect ) -> CGPoint
    {
        guard imageSize.width > 0, imageSize.height > 0
        else
        {
            return displayedRect.origin
        }

        return CGPoint(
            x: displayedRect.minX + ( point.x / imageSize.width  ) * displayedRect.width,
            y: displayedRect.minY + ( point.y / imageSize.height ) * displayedRect.height
        )
    }

    /// The image-pixel point under a point in the canvas (overlay) coordinate
    /// space — the inverse of ``viewPoint(forImagePoint:imageSize:displayedRect:)``.
    public static func imagePoint( forViewPoint point: CGPoint, imageSize: CGSize, displayedRect: CGRect ) -> CGPoint
    {
        guard imageSize.width > 0, imageSize.height > 0, displayedRect.width > 0, displayedRect.height > 0
        else
        {
            return .zero
        }

        return CGPoint(
            x: ( point.x - displayedRect.minX ) / displayedRect.width  * imageSize.width,
            y: ( point.y - displayedRect.minY ) / displayedRect.height * imageSize.height
        )
    }

    /// On-screen points per image pixel, i.e. the effective magnification of the
    /// displayed image. Used to keep stroke widths and marker radii constant on
    /// screen regardless of zoom.
    public static func displayScale( imageSize: CGSize, displayedRect: CGRect ) -> CGFloat
    {
        guard imageSize.width > 0
        else
        {
            return 0
        }

        return displayedRect.width / imageSize.width
    }
}
