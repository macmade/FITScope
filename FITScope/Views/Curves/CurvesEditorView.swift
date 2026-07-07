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

import SwiftPixel
import SwiftUI

/// The interactive Curves editor: a draggable tone-curve canvas, applied
/// uniformly or, for a colour image, per channel.
///
/// Mirrors ``LevelsEditorView``: the control points are cached in `@State`,
/// seeded from the image's ``ImageAdjustments`` on creation, and every change
/// writes the recomposed ``Processors/Curves/Channels`` back and requests a
/// debounced re-render. Switching back to master mode with per-channel edits is
/// confirmed first, since it discards that work.
struct CurvesEditorView: View
{
    /// The identity control points (a straight line from `(0, 0)` to `(1, 1)`).
    private static let identityPoints = Processors.Curves.Curve.identity.points

    /// The image whose tone curve is being edited; observed so the editor tracks
    /// the committed render.
    @ObservedObject private var image: LoadedImage

    /// The shared adjustments the editor writes to, observed so the editor also
    /// follows a change made from outside it — a menu/inspector Reset View, say —
    /// rather than showing a stale curve (see ``syncFromAdjustments()``).
    @ObservedObject private var adjustments: ImageAdjustments

    /// Whether the curve is edited per channel rather than as one master curve.
    @State private var perChannel: Bool

    /// The channel whose curve the canvas edits while ``perChannel`` is on.
    @State private var channel = Channel.red

    /// The master (all-channel) control points, used when ``perChannel`` is off.
    @State private var master: [ Processors.Curves.Point ]

    /// The per-channel control points, used when ``perChannel`` is on.
    @State private var red:   [ Processors.Curves.Point ]
    @State private var green: [ Processors.Curves.Point ]
    @State private var blue:  [ Processors.Curves.Point ]

    /// Whether the "switch to master" confirmation is shown (see
    /// ``LevelsEditorView`` for the rationale).
    @State private var showSwitchToMasterConfirmation = false

    /// Which per-channel curve is being edited.
    enum Channel: CaseIterable, Hashable, CustomStringConvertible
    {
        case red
        case green
        case blue

        /// The picker label.
        var description: String
        {
            switch self
            {
                case .red:   return "Red"
                case .green: return "Green"
                case .blue:  return "Blue"
            }
        }
    }

    /// Creates the editor, seeding its control points from the image's current
    /// tone curve.
    ///
    /// - Parameter image: The image whose tone curve is edited.
    init( image: LoadedImage )
    {
        self.image       = image
        self.adjustments = image.renderer.adjustments

        switch image.renderer.adjustments.curves
        {
            case .uniform( let curve ):

                self.perChannel = false
                self.master     = curve.points
                self.red        = curve.points
                self.green      = curve.points
                self.blue       = curve.points

            case .perChannel( let r, let g, let b ):

                self.perChannel = true
                self.master     = Self.identityPoints
                self.red        = r.points
                self.green      = g.points
                self.blue       = b.points

            @unknown default:

                self.perChannel = false
                self.master     = Self.identityPoints
                self.red        = Self.identityPoints
                self.green      = Self.identityPoints
                self.blue       = Self.identityPoints
        }
    }

    /// The view's content.
    var body: some View
    {
        // No scroll view: the window is content-sized (fixed width, height adapts to
        // this content), so the controls lay out at their natural height. The
        // `.contain` accessibility element keeps the child controls individually
        // reachable in the accessibility tree while still exposing the `editor`
        // identifier — the role the enclosing scroll view previously served.
        VStack( alignment: .leading, spacing: 14 )
        {
            CurveEditorCanvas( points: self.activePointsBinding, tint: self.tint, histogram: self.image.renderer.result?.histogram, onChange: self.commit )
                .frame( height: 260 )

            Text( "Drag to add or move points. Drag a point off the chart to remove it." )
                .font( .caption )
                .foregroundStyle( .secondary )

            if self.isMono == false
            {
                Toggle( "Per-channel", isOn: self.perChannelBinding )
                    .toggleStyle( CapsuleToggleStyle() )
                    .accessibilityIdentifier( AccessibilityIdentifier.CurvesWindowView.perChannelToggle )
                    .help( "Edit Each Colour Channel Independently" )

                if self.perChannel
                {
                    SegmentedControlView( selection: self.$channel, values: Channel.allCases, title: { $0.description } )
                        .accessibilityIdentifier( AccessibilityIdentifier.CurvesWindowView.channelPicker )
                }
            }

            HStack
            {
                Spacer()

                Button( action: self.reset )
                {
                    Label( "Reset", systemImage: "arrow.counterclockwise" )
                }
                .accessibilityIdentifier( AccessibilityIdentifier.CurvesWindowView.resetButton )
                .help( "Reset the Curve to a Straight Line" )
            }
        }
        // Lock the controls while a render driven by an edit is in flight, matching
        // the inspector; they re-enable as soon as it commits.
        .disabled( self.image.renderer.isRendering )
        .padding( 16 )
        .frame( maxWidth: .infinity, alignment: .top )
        .navigationTitle( "Curves — \( self.image.url.lastPathComponent )" )
        .accessibilityElement( children: .contain )
        .accessibilityIdentifier( AccessibilityIdentifier.CurvesWindowView.editor )
        // Follow a change made from outside the editor (e.g. a Reset View): pull
        // it back into the curve's displayed state.
        .onChange( of: self.adjustments.curves )
        {
            self.syncFromAdjustments()
        }
        .confirmationDialog( "Switch to Master Mode?", isPresented: self.$showSwitchToMasterConfirmation, titleVisibility: .visible )
        {
            Button( "Switch to Master", role: .destructive )
            {
                self.switchToMaster()
            }
            .accessibilityIdentifier( AccessibilityIdentifier.CurvesWindowView.switchToMasterConfirm )

            Button( "Cancel", role: .cancel )
            {}
        }
        message:
        {
            Text( "Your per-channel adjustments will be discarded." )
        }
    }

    /// Whether the rendered image is monochrome, in which case per-channel
    /// editing is hidden (the channels are replicated, so it would only tint).
    private var isMono: Bool
    {
        self.image.renderer.result?.histogram.isMono ?? false
    }

    /// The colour the curve is drawn in: a muted, adaptive grey for the master
    /// curve — the primary label colour at low opacity, so it flips black/white
    /// with the appearance yet stays soft rather than a harsh pure black/white on
    /// the light or dark editor background — otherwise the edited channel's colour.
    private var tint: Color
    {
        guard self.perChannel
        else
        {
            return .primary.opacity( 0.3 )
        }

        switch self.channel
        {
            case .red:   return .red
            case .green: return .green
            case .blue:  return .blue
        }
    }

    /// A binding to the control points the canvas currently edits (the master
    /// curve, or the selected channel while editing per channel).
    private var activePointsBinding: Binding< [ Processors.Curves.Point ] >
    {
        Binding(
            get: { self.activePoints },
            set: { self.writeActivePoints( $0 ) }
        )
    }

    /// The control points the canvas currently edits.
    private var activePoints: [ Processors.Curves.Point ]
    {
        guard self.perChannel
        else
        {
            return self.master
        }

        switch self.channel
        {
            case .red:   return self.red
            case .green: return self.green
            case .blue:  return self.blue
        }
    }

    /// Writes back the control points the canvas currently edits.
    ///
    /// - Parameter points: The updated control points.
    private func writeActivePoints( _ points: [ Processors.Curves.Point ] )
    {
        guard self.perChannel
        else
        {
            self.master = points

            return
        }

        switch self.channel
        {
            case .red:   self.red   = points
            case .green: self.green = points
            case .blue:  self.blue  = points
        }
    }

    /// A binding to the per-channel toggle (see ``LevelsEditorView`` for the
    /// confirm-on-disable rationale).
    private var perChannelBinding: Binding< Bool >
    {
        Binding(
            get: { self.perChannel },
            set:
            {
                if $0
                {
                    if self.perChannel == false
                    {
                        self.red   = self.master
                        self.green = self.master
                        self.blue  = self.master
                    }

                    self.perChannel = true

                    self.commit()
                }
                else if self.hasPerChannelEdits
                {
                    self.showSwitchToMasterConfirmation = true
                }
                else
                {
                    self.perChannel = false

                    self.commit()
                }
            }
        )
    }

    /// Whether any per-channel curve has been adjusted away from the identity.
    private var hasPerChannelEdits: Bool
    {
        Processors.Curves.Curve( points: self.red ).isIdentity == false
            || Processors.Curves.Curve( points: self.green ).isIdentity == false
            || Processors.Curves.Curve( points: self.blue ).isIdentity == false
    }

    /// Confirms the switch back to master: turns per-channel off and resets the
    /// per-channel curves to the identity, then re-renders from the master curve.
    private func switchToMaster()
    {
        self.perChannel = false
        self.red        = Self.identityPoints
        self.green      = Self.identityPoints
        self.blue       = Self.identityPoints

        self.commit()
    }

    /// The current channel configuration, recomposed from the editor's state.
    private var channels: Processors.Curves.Channels
    {
        self.perChannel
            ? .perChannel( red: .init( points: self.red ), green: .init( points: self.green ), blue: .init( points: self.blue ) )
            : .uniform( .init( points: self.master ) )
    }

    /// Re-seeds the editor's mode and control points from the shared adjustments
    /// when the curves change from outside the editor — a menu/inspector Reset
    /// View, say — so the canvas follows. Skipped when the adjustments already
    /// match what the editor represents, so the editor's own ``commit()`` writes
    /// don't echo back into a loop; it writes `@State` only, so it updates the
    /// display without re-committing or re-rendering.
    private func syncFromAdjustments()
    {
        guard self.adjustments.curves != self.channels
        else
        {
            return
        }

        switch self.adjustments.curves
        {
            case .uniform( let curve ):

                self.perChannel = false
                self.master     = curve.points
                self.red        = curve.points
                self.green      = curve.points
                self.blue       = curve.points

            case .perChannel( let r, let g, let b ):

                self.perChannel = true
                self.master     = Self.identityPoints
                self.red        = r.points
                self.green      = g.points
                self.blue       = b.points

            @unknown default:

                break
        }
    }

    /// Writes the current configuration into the image's adjustments and requests
    /// a debounced re-render.
    private func commit()
    {
        self.image.renderer.adjustments.curves = self.channels

        self.image.renderer.scheduleReRender()
    }

    /// Resets every curve to the identity (a straight line) and re-renders.
    private func reset()
    {
        self.perChannel = false
        self.master     = Self.identityPoints
        self.red        = Self.identityPoints
        self.green      = Self.identityPoints
        self.blue       = Self.identityPoints

        self.commit()
    }
}
