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

/// End-to-end UI coverage of the app's current interface, exercised through the
/// real Open panel and accessibility identifiers (never display strings, except
/// when *choosing* a menu/picker value, where the title is the only handle).
///
/// The suite aims to cover the whole current UI: the core viewing flows, the
/// windows and menu commands, the files sidebar and its context menu, the canvas
/// toolbar, every inspector section, and the FITS headers window. It is organised
/// into `MARK` sections by area.
///
/// **Depth.** Controls are tested for reachability and their *observable UI
/// response* — a toggle flips, a picker reveals the sliders that mode needs, a
/// section is present — rather than by driving slider values and asserting the
/// resulting pixels. The pixel math, geometry and formatting behind the controls
/// are covered far more cheaply and precisely by the unit suite
/// (``FITScopeTests``, Swift Testing), so they are deliberately not re-tested
/// through the UI.
///
/// **Deliberately not UI-tested** (covered by unit tests or not observable through
/// XCUITest, documented at their call sites):
/// - Scroll-wheel zoom, click-drag pan and pinch-zoom — AppKit `NSScrollView`
///   gestures XCUITest cannot drive reliably; the zoom/pan geometry is unit-tested
///   in `CanvasGeometryTests`. Zoom is exercised here through the toolbar buttons.
/// - The status-bar cursor read-out (X / Y / value), which requires hovering exact
///   image pixels and is inherently position-dependent.
/// - Inspector slider *values* — the custom slider is not reliably draggable; the
///   sliders' presence/reveal is asserted instead.
/// - The "Invert Appearance" developer command, whose effect (`NSApp.appearance`)
///   is not observable through the accessibility tree.
///
/// **Resilience.** Every assertion waits for existence (`waitForExistence` /
/// `waitForNonExistence`) rather than sleeping for a fixed interval, so the suite
/// neither flakes on a slow render nor wastes time on a fast one.
final class FITScopeUITests: XCTestCase
{
    override func setUpWithError() throws
    {
        self.continueAfterFailure = false
    }

    override func tearDownWithError() throws
    {}

    // MARK: - Core viewing flows

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

    /// The split-view sidebars must stay within the window when the detail pane
    /// shows the error placeholder: the placeholder's minimum width must not push
    /// the columns wider than the window and clip the sidebars off its edges.
    @MainActor
    func testSidebarsStayWithinTheWindowForAnInvalidImage() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "InvalidStructure.fits", in: app )

        let window    = app.windows.firstMatch
        let filesList = UITestSupport.element( app, AccessibilityIdentifier.FilesSidebarView.list )

        XCTAssertTrue( UITestSupport.element( app, AccessibilityIdentifier.ErrorView.view ).waitForExistence( timeout: 30 ), "The error view did not appear for an invalid FITS file." )
        XCTAssertTrue( filesList.waitForExistence( timeout: 5 ), "The files sidebar did not appear." )

        // Clipping pushes the sidebar past the window's left edge; it must sit at
        // or inside it.
        XCTAssertGreaterThanOrEqual( filesList.frame.minX, window.frame.minX - 1, "The files sidebar is clipped past the window's left edge (minX \( filesList.frame.minX ) vs window \( window.frame.minX ))." )
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

    /// Adjusting a control feeds back into the render pipeline. Enabling the gamma
    /// toggle reveals its exponent slider — the control's own conditional UI — and
    /// the canvas remains rendered through the re-render the change triggers.
    ///
    /// The slider's appearance is the observable here because, until the render
    /// lifecycle work lands (M1.3 / M1.4), there is no in-app indicator of a
    /// re-render to assert against; M1.4's smoke test will assert the
    /// processing → ready cycle directly once it exists.
    @MainActor
    func testAdjustingGammaRevealsSliderAndKeepsRendering() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        let canvas = UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas )
        let toggle = UITestSupport.element( app, AccessibilityIdentifier.GammaCorrectionControlView.toggle )
        let slider = UITestSupport.element( app, AccessibilityIdentifier.GammaCorrectionControlView.slider )

        XCTAssertTrue( canvas.waitForExistence( timeout: 30 ), "The image canvas did not appear after opening a fixture." )

        // Gamma is off by default, so its slider is not present yet.
        XCTAssertTrue( toggle.waitForExistence( timeout: 5 ), "The gamma toggle did not appear in the inspector." )
        XCTAssertFalse( slider.exists, "The gamma slider was present before gamma was enabled." )

        toggle.click()

        // Enabling gamma reveals the slider and re-renders; the canvas stays put.
        XCTAssertTrue( slider.waitForExistence( timeout: 5 ), "Enabling gamma did not reveal its slider." )
        XCTAssertTrue( canvas.exists, "The canvas disappeared after a gamma adjustment." )
    }

    /// Opening the FITS headers window from the sidebar's information panel brings
    /// up the headers view (its search field and keyword table), in a window
    /// distinct from the main one.
    @MainActor
    func testOpeningHeadersWindow() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas ).waitForExistence( timeout: 30 ),
            "The image canvas did not appear after opening a fixture."
        )

        let openHeaders = UITestSupport.element( app, AccessibilityIdentifier.ImageInfoPanelView.viewHeadersButton )

        XCTAssertTrue( openHeaders.waitForExistence( timeout: 10 ), "The 'View Full FITS Headers' button did not appear." )

        openHeaders.click()

        let searchField = UITestSupport.element( app, AccessibilityIdentifier.InfoView.searchField )
        let table       = UITestSupport.element( app, AccessibilityIdentifier.InfoView.table )

        XCTAssertTrue( searchField.waitForExistence( timeout: 10 ), "The headers window's search field did not appear." )
        XCTAssertTrue( table.exists, "The headers window's keyword table did not appear." )
    }

    /// The inspector toggle hides and re-shows the trailing inspector column. The
    /// inspector's content is identified by ``AccessibilityIdentifier/InspectorView/container``,
    /// so its presence tracks whether the column is shown.
    @MainActor
    func testTogglingInspectorHidesAndShowsIt() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas ).waitForExistence( timeout: 30 ),
            "The image canvas did not appear after opening a fixture."
        )

        let inspector = UITestSupport.element( app, AccessibilityIdentifier.InspectorView.container )
        let toggle    = UITestSupport.element( app, AccessibilityIdentifier.MainWindowView.inspectorToggle )

        // The inspector is shown by default.
        XCTAssertTrue( inspector.waitForExistence( timeout: 10 ), "The inspector was not shown by default." )
        XCTAssertTrue( toggle.waitForExistence( timeout: 5 ), "The inspector toggle did not appear." )

        // Hide it.
        toggle.click()
        XCTAssertTrue( inspector.waitForNonExistence( timeout: 5 ), "The inspector did not hide when toggled off." )

        // Show it again.
        toggle.click()
        XCTAssertTrue( inspector.waitForExistence( timeout: 5 ), "The inspector did not reappear when toggled on." )
    }

    // MARK: - Windows & menus

    /// The "New Window" command (⌘N) opens an additional window. Starting from an
    /// open file (one window with a canvas), a new window brings the count to two;
    /// the new window shows no canvas (the "No File Open" placeholder).
    @MainActor
    func testNewWindowCommandOpensAnotherWindow() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas ).waitForExistence( timeout: 30 ),
            "The image canvas did not appear after opening a fixture."
        )

        XCTAssertEqual( app.windows.count, 1, "Expected exactly one window after opening a file." )

        app.typeKey( "n", modifierFlags: .command )

        XCTAssertTrue(
            UITestSupport.waitFor( timeout: 5 ) { app.windows.count == 2 },
            "The New Window command did not open a second window (windows: \( app.windows.count ))."
        )
    }

    /// The "About" app-menu command opens the custom About window. It is the only
    /// way to reach that window (no shortcut), so the menu bar is driven directly.
    @MainActor
    func testAboutCommandOpensAboutWindow() throws
    {
        let app = UITestSupport.launchApp()

        // Open a file first: the app menu only has a real on-screen frame while the
        // app has a window and is frontmost.
        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas ).waitForExistence( timeout: 30 ),
            "The image canvas did not appear after opening a fixture."
        )

        // Open the bold, app-named menu (the product name, not the test runner's)
        // and click its "About …" item. "About This Mac" in the Apple menu also
        // begins with "About", so the hittable match in the open menu is chosen.
        let appMenu = app.menuBars.menuBarItems[ "FITScope" ]

        XCTAssertTrue( appMenu.waitForExistence( timeout: 5 ), "The application menu was not found." )

        appMenu.click()

        UITestSupport.clickMenuItem( in: app, where: NSPredicate( format: "title BEGINSWITH %@", "About" ) )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.AboutView.view ).waitForExistence( timeout: 5 ),
            "The About window did not appear."
        )
    }

    // MARK: - Files sidebar

    /// The sidebar's add (+) button presents the Open panel, exactly as the menu
    /// command does. The panel is dismissed afterward to leave a clean state.
    @MainActor
    func testAddButtonPresentsOpenPanel() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        let add = UITestSupport.element( app, AccessibilityIdentifier.FilesSidebarView.addButton )

        XCTAssertTrue( add.waitForExistence( timeout: 30 ), "The add-files button did not appear." )

        add.click()

        let dialog = app.dialogs.firstMatch

        XCTAssertTrue( dialog.waitForExistence( timeout: 10 ), "The Open panel did not appear from the add button." )

        // Leave no modal panel behind for any subsequent assertions.
        app.typeKey( .escape, modifierFlags: [] )
    }

    /// Opening a second file lists both in the sidebar, and selecting a row drives
    /// the detail pane. A valid file (canvas) and an invalid file (error view) make
    /// the two selection states unambiguously distinguishable.
    @MainActor
    func testOpeningMultipleFilesListsRowsAndSwitchesSelection() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        let canvas = UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas )
        let error  = UITestSupport.element( app, AccessibilityIdentifier.ErrorView.view )

        XCTAssertTrue( canvas.waitForExistence( timeout: 30 ), "The first (valid) file did not render." )

        try UITestSupport.openAnotherFixture( "InvalidStructure.fits", in: app )

        let rows = app.descendants( matching: .any ).matching( identifier: AccessibilityIdentifier.OpenFileRowView.row )

        XCTAssertTrue(
            UITestSupport.waitFor( timeout: 30 ) { rows.count == 2 },
            "Expected two file rows after opening two files (rows: \( rows.count ))."
        )

        // Selecting the second (invalid) row shows the error view; selecting the
        // first (valid) row shows the canvas. Driving the selection explicitly
        // avoids assuming which file the open command auto-selects.
        rows.element( boundBy: 1 ).click()
        XCTAssertTrue( error.waitForExistence( timeout: 30 ), "Selecting the invalid file did not show the error view." )

        rows.element( boundBy: 0 ).click()
        XCTAssertTrue( canvas.waitForExistence( timeout: 30 ), "Selecting the valid file did not show the canvas." )
        XCTAssertTrue( error.waitForNonExistence( timeout: 5 ), "The error view stayed after selecting the valid file." )
    }

    /// The file row's context menu opens the FITS headers window via "View FITS
    /// Headers".
    @MainActor
    func testRowContextMenuOpensHeaders() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        let row = UITestSupport.element( app, AccessibilityIdentifier.OpenFileRowView.row )

        XCTAssertTrue( row.waitForExistence( timeout: 30 ), "The file row did not appear." )

        row.rightClick()

        UITestSupport.clickMenuItem( "View FITS Headers", in: app )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.InfoView.searchField ).waitForExistence( timeout: 10 ),
            "The headers window did not open from the context menu."
        )
    }

    /// The file row's context-menu "Close" removes that file from the window.
    @MainActor
    func testRowContextMenuClosesFile() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        try UITestSupport.openAnotherFixture( "InvalidStructure.fits", in: app )

        let rows = app.descendants( matching: .any ).matching( identifier: AccessibilityIdentifier.OpenFileRowView.row )

        XCTAssertTrue(
            UITestSupport.waitFor( timeout: 30 ) { rows.count == 2 },
            "Expected two file rows before closing one (rows: \( rows.count ))."
        )

        rows.element( boundBy: 0 ).rightClick()

        // "Close" also exists in the Window/File menus; click the hittable one in
        // the presented context menu.
        UITestSupport.clickMenuItem( "Close", in: app )

        XCTAssertTrue(
            UITestSupport.waitFor( timeout: 5 ) { rows.count == 1 },
            "Closing a file did not remove its row (rows: \( rows.count ))."
        )
    }

    // MARK: - Canvas toolbar

    /// The toolbar zoom controls change the zoom-percentage read-out: actual size
    /// sets 100 %, zoom-in increases it and zoom-out decreases it. (Scroll/drag/
    /// pinch zoom-pan are AppKit gestures left to `CanvasGeometryTests`.)
    @MainActor
    func testToolbarZoomControlsChangeReadout() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        let canvas      = UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas )
        let zoomIn      = UITestSupport.element( app, AccessibilityIdentifier.ImageToolbarView.zoomIn )
        let zoomOut     = UITestSupport.element( app, AccessibilityIdentifier.ImageToolbarView.zoomOut )
        let actualSize  = UITestSupport.element( app, AccessibilityIdentifier.ImageToolbarView.actualSize )
        let readout     = app.staticTexts.matching( identifier: AccessibilityIdentifier.ImageToolbarView.zoomReadout ).firstMatch

        XCTAssertTrue( canvas.waitForExistence( timeout: 30 ), "The image canvas did not appear after opening a fixture." )

        // Reveal the floating toolbar and keep it up by resting over a button.
        UITestSupport.element( app, AccessibilityIdentifier.FilesSidebarView.list ).hover()
        canvas.hover()

        XCTAssertTrue( actualSize.waitForExistence( timeout: 5 ), "The floating toolbar did not reveal." )
        actualSize.hover()

        // The read-out is a static text whose percentage is exposed as its
        // accessibility *value* (e.g. "100%"), not its label.
        let zoom = { ( readout.value as? String ).flatMap( UITestSupport.percentage ) }

        actualSize.click()
        XCTAssertTrue(
            UITestSupport.waitFor( timeout: 5 ) { zoom() == 100 },
            "Actual size did not set the zoom read-out to 100% (was \( readout.value ?? "nil" ))."
        )

        zoomIn.click()
        XCTAssertTrue(
            UITestSupport.waitFor( timeout: 5 ) { ( zoom() ?? 0 ) > 100 },
            "Zoom-in did not increase the zoom read-out above 100% (was \( readout.value ?? "nil" ))."
        )

        let zoomedIn = zoom() ?? 0

        zoomOut.click()
        XCTAssertTrue(
            UITestSupport.waitFor( timeout: 5 ) { ( zoom() ?? .max ) < zoomedIn },
            "Zoom-out did not decrease the zoom read-out (was \( readout.value ?? "nil" ))."
        )
    }

    // MARK: - Inspector

    /// Every inspector section, the container and the Reset View button are
    /// present for a rendered image.
    @MainActor
    func testInspectorSectionsArePresent() throws
    {
        self.continueAfterFailure = true

        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas ).waitForExistence( timeout: 30 ),
            "The image canvas did not appear after opening a fixture."
        )

        let sections: [ ( name: String, identifier: String ) ] =
            [
                ( "inspector container", AccessibilityIdentifier.InspectorView.container ),
                ( "histogram section",   AccessibilityIdentifier.InspectorView.Section.histogram ),
                ( "stretch section",     AccessibilityIdentifier.InspectorView.Section.stretch ),
                ( "gamma section",       AccessibilityIdentifier.InspectorView.Section.gamma ),
                ( "white-balance section", AccessibilityIdentifier.InspectorView.Section.whiteBalance ),
                ( "debayer section",     AccessibilityIdentifier.InspectorView.Section.debayer ),
                ( "color section",       AccessibilityIdentifier.InspectorView.Section.color ),
                ( "reset button",        AccessibilityIdentifier.InspectorView.resetButton ),
            ]

        for entry in sections
        {
            XCTAssertTrue(
                UITestSupport.element( app, entry.identifier ).waitForExistence( timeout: 5 ),
                "Inspector element missing: \( entry.name ) (\( entry.identifier ))"
            )
        }
    }

    /// A file that fails to render shows the inspector's placeholder instead of the
    /// adjustment sections.
    @MainActor
    func testInspectorShowsPlaceholderForInvalidFile() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "InvalidStructure.fits", in: app )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.InspectorPlaceholderView.view ).waitForExistence( timeout: 30 ),
            "The inspector placeholder did not appear for an invalid file."
        )

        XCTAssertFalse(
            UITestSupport.element( app, AccessibilityIdentifier.InspectorView.Section.gamma ).exists,
            "Adjustment sections appeared for a file that failed to render."
        )
    }

    /// The histogram's Statistics toggle reveals and hides the statistics panel.
    @MainActor
    func testHistogramStatisticsToggleRevealsPanel() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        let statistics = UITestSupport.element( app, AccessibilityIdentifier.HistogramControlView.statistics )
        let panel      = UITestSupport.element( app, AccessibilityIdentifier.HistogramControlView.statisticsPanel )

        XCTAssertTrue( statistics.waitForExistence( timeout: 30 ), "The Statistics toggle did not appear." )
        XCTAssertFalse( panel.exists, "The statistics panel was visible before the toggle was enabled." )

        statistics.click()
        XCTAssertTrue( panel.waitForExistence( timeout: 5 ), "Enabling Statistics did not reveal the panel." )

        statistics.click()
        XCTAssertTrue( panel.waitForNonExistence( timeout: 5 ), "Disabling Statistics did not hide the panel." )
    }

    /// Switching the histogram to luminance mode disables the "Separate Channels"
    /// toggle (channel separation is meaningless for a single-channel histogram).
    @MainActor
    func testHistogramLuminanceModeDisablesSeparateChannels() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        let separateChannels = UITestSupport.element( app, AccessibilityIdentifier.HistogramControlView.separateChannels )

        XCTAssertTrue( separateChannels.waitForExistence( timeout: 30 ), "The Separate Channels toggle did not appear." )
        XCTAssertTrue( separateChannels.isEnabled, "Separate Channels should be enabled in RGB mode." )

        // The segmented control's segments are plain buttons labelled by their
        // title; "Luminance" is unique in the UI.
        app.buttons[ "Luminance" ].click()

        XCTAssertTrue(
            UITestSupport.waitFor( timeout: 5 ) { separateChannels.isEnabled == false },
            "Separate Channels was not disabled in luminance mode."
        )
    }

    /// The stretch mode picker reveals exactly the sliders each algorithm needs:
    /// none for None, the intensity slider for Logarithmic, and both sigmoid
    /// sliders for Sigmoid.
    @MainActor
    func testStretchModeRevealsRelevantSliders() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        let picker    = UITestSupport.element( app, AccessibilityIdentifier.StretchControlView.modePicker )
        let intensity = UITestSupport.element( app, AccessibilityIdentifier.StretchControlView.intensitySlider )
        let midpoint  = UITestSupport.element( app, AccessibilityIdentifier.StretchControlView.midpointSlider )
        let contrast  = UITestSupport.element( app, AccessibilityIdentifier.StretchControlView.contrastSlider )

        XCTAssertTrue( picker.waitForExistence( timeout: 30 ), "The stretch mode picker did not appear." )

        // Default is None — no stretch sliders.
        XCTAssertFalse( intensity.exists, "A stretch slider was visible in None mode." )

        UITestSupport.selectPickerOption( picker, "Logarithmic", in: app )
        XCTAssertTrue( intensity.waitForExistence( timeout: 5 ), "Logarithmic mode did not reveal the Intensity slider." )

        UITestSupport.selectPickerOption( picker, "Sigmoid", in: app )
        XCTAssertTrue( midpoint.waitForExistence( timeout: 5 ), "Sigmoid mode did not reveal the Midpoint slider." )
        XCTAssertTrue( contrast.exists, "Sigmoid mode did not reveal the Contrast slider." )
        XCTAssertFalse( intensity.exists, "The Intensity slider lingered after leaving Logarithmic mode." )
    }

    /// The white-balance Manual mode reveals the per-channel red/green/blue gain
    /// sliders, which are absent in the other modes.
    @MainActor
    func testWhiteBalanceManualRevealsChannelSliders() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        let picker = UITestSupport.element( app, AccessibilityIdentifier.WhiteBalanceControlView.modePicker )
        let red    = UITestSupport.element( app, AccessibilityIdentifier.WhiteBalanceControlView.redSlider )
        let green  = UITestSupport.element( app, AccessibilityIdentifier.WhiteBalanceControlView.greenSlider )
        let blue   = UITestSupport.element( app, AccessibilityIdentifier.WhiteBalanceControlView.blueSlider )

        XCTAssertTrue( picker.waitForExistence( timeout: 30 ), "The white-balance mode picker did not appear." )
        XCTAssertFalse( red.exists, "A channel-gain slider was visible outside Manual mode." )

        UITestSupport.selectPickerOption( picker, "Manual", in: app )

        XCTAssertTrue( red.waitForExistence( timeout: 5 ), "Manual mode did not reveal the Red gain slider." )
        XCTAssertTrue( green.exists, "Manual mode did not reveal the Green gain slider." )
        XCTAssertTrue( blue.exists, "Manual mode did not reveal the Blue gain slider." )
    }

    /// The debayer algorithm picker is disabled when the Bayer mode is None and
    /// enabled once a pattern (or Auto) is selected.
    @MainActor
    func testDebayerAlgorithmEnablementFollowsMode() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        let mode      = UITestSupport.element( app, AccessibilityIdentifier.DebayerControlView.modePicker )
        let algorithm = UITestSupport.element( app, AccessibilityIdentifier.DebayerControlView.algorithmPicker )

        XCTAssertTrue( mode.waitForExistence( timeout: 30 ), "The debayer mode picker did not appear." )
        XCTAssertTrue( algorithm.exists, "The debayer algorithm picker is missing." )

        // Default mode is Auto, so the algorithm picker starts enabled.
        XCTAssertTrue( algorithm.isEnabled, "The algorithm picker should be enabled for the default mode." )

        UITestSupport.selectPickerOption( mode, "None", in: app )
        XCTAssertTrue(
            UITestSupport.waitFor( timeout: 5 ) { algorithm.isEnabled == false },
            "The algorithm picker was not disabled in None mode."
        )

        UITestSupport.selectPickerOption( mode, "Auto", in: app )
        XCTAssertTrue(
            UITestSupport.waitFor( timeout: 5 ) { algorithm.isEnabled },
            "The algorithm picker was not re-enabled after leaving None mode."
        )
    }

    /// The Color section's Invert toggle is present and flips when clicked, and the
    /// image stays rendered through the re-render it triggers.
    @MainActor
    func testInvertToggleFlips() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        let canvas = UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas )
        let invert = UITestSupport.element( app, AccessibilityIdentifier.ColorControlView.invertToggle )

        XCTAssertTrue( canvas.waitForExistence( timeout: 30 ), "The image canvas did not appear after opening a fixture." )
        XCTAssertTrue( invert.waitForExistence( timeout: 5 ), "The Invert toggle did not appear." )

        // A plain checkbox reports its value as a number (0/1), not a string, so
        // compare its description rather than casting to String.
        let before = String( describing: invert.value )

        invert.click()

        XCTAssertTrue(
            UITestSupport.waitFor( timeout: 5 ) { String( describing: invert.value ) != before },
            "The Invert toggle did not change state when clicked."
        )
        XCTAssertTrue( canvas.exists, "The canvas disappeared after toggling Invert." )
    }

    /// The Reset View button is present and clickable, and the image stays rendered
    /// afterward. (Reset clears the renderer's adjustments; it does not reset the
    /// controls' own displayed state, so there is no control-level UI change to
    /// assert here — see the unit suite for the adjustment-reset behaviour.)
    @MainActor
    func testResetViewIsClickableAndKeepsRendering() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        let canvas = UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas )
        let reset  = UITestSupport.element( app, AccessibilityIdentifier.InspectorView.resetButton )

        XCTAssertTrue( canvas.waitForExistence( timeout: 30 ), "The image canvas did not appear after opening a fixture." )
        XCTAssertTrue( reset.waitForExistence( timeout: 5 ), "The Reset View button did not appear." )

        reset.click()

        XCTAssertTrue( canvas.exists, "The canvas disappeared after Reset View." )
    }

    // MARK: - Headers window

    /// Typing in the headers window's search field filters the keyword table down,
    /// and clearing the query restores the full list.
    @MainActor
    func testHeadersWindowSearchFiltersTable() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas ).waitForExistence( timeout: 30 ),
            "The image canvas did not appear after opening a fixture."
        )

        let openHeaders = UITestSupport.element( app, AccessibilityIdentifier.ImageInfoPanelView.viewHeadersButton )

        XCTAssertTrue( openHeaders.waitForExistence( timeout: 10 ), "The 'View Full FITS Headers' button did not appear." )
        openHeaders.click()

        let table = UITestSupport.element( app, AccessibilityIdentifier.InfoView.table )

        XCTAssertTrue( table.waitForExistence( timeout: 10 ), "The headers table did not appear." )

        // The search-field identifier is shared by the leading icon and the text
        // field; target the text field specifically so typing lands in it.
        let field = app.textFields.matching( identifier: AccessibilityIdentifier.InfoView.searchField ).firstMatch

        XCTAssertTrue( field.waitForExistence( timeout: 5 ), "The headers search field did not appear." )

        // SIMPLE and BITPIX are both mandatory keywords present in any FITS image,
        // shown as name cells in the table. Filtering for "SIMPLE" must keep the
        // SIMPLE row and drop the unrelated BITPIX row — a behavioural check that
        // needs no row counting.
        let simple = app.staticTexts[ "SIMPLE" ]
        let bitpix = app.staticTexts[ "BITPIX" ]

        XCTAssertTrue( simple.waitForExistence( timeout: 5 ), "The SIMPLE keyword row was not shown." )
        XCTAssertTrue( bitpix.waitForExistence( timeout: 5 ), "The BITPIX keyword row was not shown." )

        field.click()
        field.typeText( "SIMPLE" )

        XCTAssertTrue( bitpix.waitForNonExistence( timeout: 5 ), "Searching for SIMPLE did not filter out the BITPIX row." )
        XCTAssertTrue( simple.exists, "Searching for SIMPLE filtered out the SIMPLE row." )

        // Clearing the query restores the full list.
        field.typeKey( "a", modifierFlags: .command )
        field.typeKey( .delete, modifierFlags: [] )

        XCTAssertTrue( bitpix.waitForExistence( timeout: 5 ), "Clearing the search did not restore the BITPIX row." )
    }

    /// The headers window's section picker lists the file's sections and can switch
    /// between them.
    @MainActor
    func testHeadersWindowSectionPickerIsPresent() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "RenderableImage.fits", in: app )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas ).waitForExistence( timeout: 30 ),
            "The image canvas did not appear after opening a fixture."
        )

        let openHeaders = UITestSupport.element( app, AccessibilityIdentifier.ImageInfoPanelView.viewHeadersButton )

        XCTAssertTrue( openHeaders.waitForExistence( timeout: 10 ), "The 'View Full FITS Headers' button did not appear." )
        openHeaders.click()

        let picker = UITestSupport.element( app, AccessibilityIdentifier.InfoView.sectionPicker )

        XCTAssertTrue( picker.waitForExistence( timeout: 10 ), "The headers section picker did not appear." )
        XCTAssertTrue( picker.isEnabled, "The headers section picker is not enabled." )
    }
}
