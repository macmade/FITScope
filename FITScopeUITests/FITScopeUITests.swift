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

import XCTest

final class FITScopeUITests: XCTestCase
{
    override func setUpWithError() throws
    {
        self.continueAfterFailure = false
    }

    override func tearDownWithError() throws
    {}

    /// Verifies the UI-test launch hook: launching, then opening a renderable
    /// fixture through the Open panel, brings up the image canvas. This proves
    /// the panel-driving path and the canvas identifier work — the foundation the
    /// M0.2 smoke suite builds on.
    @MainActor
    func testOpeningFixtureRendersCanvas() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        let canvas = UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas )

        XCTAssertTrue( canvas.waitForExistence( timeout: 30 ), "The image canvas did not appear after opening a fixture." )
    }

    /// The error-path counterpart to ``testOpeningFixtureRendersCanvas``: opening
    /// a structurally-invalid FITS file surfaces the error view instead of the
    /// canvas. Exercises the malformed fixture and the error-view identifier.
    @MainActor
    func testOpeningInvalidFileShowsError() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "InvalidStructure.fits", in: app )

        let errorView = UITestSupport.element( app, AccessibilityIdentifier.ErrorView.view )

        XCTAssertTrue( errorView.waitForExistence( timeout: 30 ), "The error view did not appear for an invalid FITS file." )
        XCTAssertFalse( UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas ).exists, "The canvas appeared for an invalid FITS file." )

        // A file that fails to load is still listed in the sidebar (shown with an
        // error), not silently dropped.
        XCTAssertTrue( UITestSupport.element( app, AccessibilityIdentifier.OpenFileRowView.row ).exists, "The failed file was not listed in the sidebar." )
    }

    /// Guards against a mis-wired accessibility identifier: after opening a file,
    /// every identifier that is always present in the main window must resolve.
    /// This is one cheap check across the contract rather than a brittle test per
    /// identifier — the per-flow tests then drive these elements for real.
    ///
    /// The canvas's floating bars are excluded here because they auto-hide; their
    /// identifiers are verified in ``testFloatingBarsRevealHideAndStayOnHover``.
    /// The headers-window controls and the loading / error placeholders appear in
    /// states this test does not enter, and are covered by the flows that produce
    /// them.
    @MainActor
    func testAccessibilityIdentifiersAreWired() throws
    {
        self.continueAfterFailure = true

        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        // The canvas confirms the file rendered before the rest is probed.
        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas ).waitForExistence( timeout: 30 ),
            "The image canvas did not appear after opening a fixture."
        )

        let identifiers: [ ( name: String, identifier: String ) ] =
            [
                ( "files list",       AccessibilityIdentifier.FilesSidebarView.list ),
                ( "file row",         AccessibilityIdentifier.OpenFileRowView.row ),
                ( "inspector",        AccessibilityIdentifier.InspectorView.container ),
                ( "inspector toggle", AccessibilityIdentifier.MainWindowView.inspectorToggle ),
                ( "gamma section",    AccessibilityIdentifier.InspectorView.Section.gamma ),
                ( "gamma toggle",     AccessibilityIdentifier.GammaCorrectionControlView.toggle ),
            ]

        for entry in identifiers
        {
            XCTAssertTrue(
                UITestSupport.element( app, entry.identifier ).waitForExistence( timeout: 5 ),
                "Accessibility identifier not wired: \( entry.name ) (\( entry.identifier ))"
            )
        }
    }

    /// Verifies the real behaviour of the canvas's floating bars: they reveal on
    /// cursor movement, auto-hide when the cursor rests away from them, and stay
    /// visible while the cursor is over them. Revealing them also confirms the
    /// toolbar-button and status-pill identifiers are wired (they leave the
    /// accessibility tree while hidden, so they cannot be checked at rest).
    @MainActor
    func testFloatingBarsRevealHideAndStayOnHover() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        let canvas    = UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas )
        let filesList = UITestSupport.element( app, AccessibilityIdentifier.FilesSidebarView.list )
        let fit       = UITestSupport.element( app, AccessibilityIdentifier.ImageToolbarView.fit )

        XCTAssertTrue( canvas.waitForExistence( timeout: 30 ), "The image canvas did not appear after opening a fixture." )

        // Reveal: start the cursor off the canvas, then move onto it. The reveal
        // is driven by cursor *movement*, so the two hovers must target distinct
        // points (hovering one point twice generates no movement).
        filesList.hover()
        canvas.hover()

        XCTAssertTrue( fit.waitForExistence( timeout: 5 ), "The floating toolbar did not reveal on cursor movement." )

        // Hold the bars up by resting the cursor over the toolbar, so the wiring
        // checks below are not racing the auto-hide timer.
        fit.hover()

        // While shown, every floating identifier must resolve (the wiring check
        // for the bars, which leave the tree when hidden).
        let floating: [ ( name: String, identifier: String ) ] =
            [
                ( "status bar",          AccessibilityIdentifier.StatusBarView.bar ),
                ( "toolbar recenter",    AccessibilityIdentifier.ImageToolbarView.recenter ),
                ( "toolbar zoom out",    AccessibilityIdentifier.ImageToolbarView.zoomOut ),
                ( "toolbar zoom in",     AccessibilityIdentifier.ImageToolbarView.zoomIn ),
                ( "toolbar actual size", AccessibilityIdentifier.ImageToolbarView.actualSize ),
            ]

        for entry in floating
        {
            XCTAssertTrue( UITestSupport.element( app, entry.identifier ).exists, "Floating identifier not wired: \( entry.name ) (\( entry.identifier ))" )
        }

        // Stay visible: with the cursor still over the toolbar, it must remain
        // past the auto-hide delay — `waitForNonExistence` returning false means
        // it never disappeared. The window only needs to exceed the app's 2 s
        // auto-hide delay to be meaningful.
        XCTAssertFalse( fit.waitForNonExistence( timeout: 3 ), "The floating toolbar hid while the cursor was over it." )

        // Auto-hide: move the cursor off the bars (back onto the canvas). With it
        // at rest there, the bars fade out and leave the accessibility tree.
        canvas.hover()

        XCTAssertTrue( fit.waitForNonExistence( timeout: 5 ), "The floating toolbar did not auto-hide." )
    }
}
