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
import SwiftUI
import Testing

/// Tests for ``ImageCanvasController``: the shared source of truth that both the
/// floating toolbar and the *Image* menu drive. The zoom methods must issue
/// distinct one-shot commands so the same command can be requested twice in a
/// row, and the generic overlay tap must toggle, warn, or run the overlay's call
/// to action exactly as the toolbar does.
@MainActor
@Suite( "ImageCanvasController" )
struct ImageCanvasControllerTests
{
    /// A minimal overlay stub letting the tests set availability, a warning, and a
    /// call to action without any real image data.
    private struct StubOverlay: CanvasOverlay
    {
        let id:               String
        let title:            String
        let systemImageName = "star"
        let isAvailable:      Bool
        var warning:          String?         = nil
        var onUnavailableTap: ( () -> Void )? = nil

        func draw( in context: inout GraphicsContext, canvasSize: CGSize, imageSize: CGSize, displayedRect: CGRect ) {}
    }

    @Test
    func zoomMethodsIssueTheirMatchingCommandKind()
    {
        let controller = ImageCanvasController()

        controller.zoomIn()
        #expect( controller.command.kind == .zoomIn )

        controller.zoomOut()
        #expect( controller.command.kind == .zoomOut )

        controller.fit()
        #expect( controller.command.kind == .fit )

        controller.actualSize()
        #expect( controller.command.kind == .actualSize )

        controller.recenter()
        #expect( controller.command.kind == .recenter )
    }

    @Test
    func repeatingACommandBumpsTheTokenSoItIsAppliedAgain()
    {
        let controller = ImageCanvasController()

        controller.zoomIn()

        let first = controller.command.token

        controller.zoomIn()

        // Same kind twice in a row must still be a distinct command, or the scroll
        // view would ignore the repeat (it de-dupes by token).
        #expect( controller.command.token != first )
    }

    @Test
    func tappingAnAvailableOverlayTogglesItOnAndOff()
    {
        let controller = ImageCanvasController()

        controller.overlays = [ StubOverlay( id: "stars", title: "Stars", isAvailable: true ) ]

        #expect( controller.isOverlayEnabled( "stars" ) == false )

        controller.overlayTapped( "stars" )
        #expect( controller.isOverlayEnabled( "stars" ) )

        controller.overlayTapped( "stars" )
        #expect( controller.isOverlayEnabled( "stars" ) == false )
    }

    @Test
    func tappingAnUnavailableOverlayWithAWarningShowsTheAlertWithoutEnablingIt()
    {
        let controller = ImageCanvasController()

        controller.overlays = [ StubOverlay( id: "stars", title: "Stars", isAvailable: false, warning: "No stars were detected." ) ]

        controller.overlayTapped( "stars" )

        #expect( controller.isOverlayAlertPresented )
        #expect( controller.overlayAlertTitle   == "Stars" )
        #expect( controller.overlayAlertMessage == "No stars were detected." )
        #expect( controller.isOverlayEnabled( "stars" ) == false )
    }

    @Test
    func tappingAnUnavailableOverlayWithACallToActionRunsItWithoutAlerting()
    {
        let controller = ImageCanvasController()
        var ran        = false

        controller.overlays = [ StubOverlay( id: "objects", title: "Objects", isAvailable: false, onUnavailableTap: { ran = true } ) ]

        controller.overlayTapped( "objects" )

        #expect( ran )
        #expect( controller.isOverlayAlertPresented == false )
        #expect( controller.isOverlayEnabled( "objects" ) == false )
    }

    @Test
    func tappingAnUnknownOverlayDoesNothing()
    {
        let controller = ImageCanvasController()

        controller.overlays = [ StubOverlay( id: "stars", title: "Stars", isAvailable: true ) ]

        controller.overlayTapped( "missing" )

        #expect( controller.isOverlayEnabled( "missing" ) == false )
        #expect( controller.isOverlayAlertPresented == false )
    }
}
