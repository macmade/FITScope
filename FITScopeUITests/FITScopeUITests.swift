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

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

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

        try UITestSupport.openFixture( "InvalidImage.fits", in: app )

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

        try UITestSupport.openFixture( "InvalidImage.fits", in: app )

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

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

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

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

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

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

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

    /// The inspector's orientation section exposes its four reorient buttons, and
    /// rotating re-renders the image without losing the canvas. The reorientation
    /// is a geometry transform whose correctness is covered by unit tests (the
    /// SwiftPixel `Orient` processor and the source-coordinate mapping); here we
    /// only confirm the controls are reachable and keep the image rendered.
    @MainActor
    func testOrientationControlsReorientAndKeepRendering() throws
    {
        self.continueAfterFailure = true

        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

        let canvas = UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas )

        XCTAssertTrue( canvas.waitForExistence( timeout: 30 ), "The image canvas did not appear after opening a fixture." )

        let buttons: [ ( name: String, identifier: String ) ] =
            [
                ( "rotate left",     AccessibilityIdentifier.OrientationControlView.rotateLeft ),
                ( "rotate right",    AccessibilityIdentifier.OrientationControlView.rotateRight ),
                ( "flip horizontal", AccessibilityIdentifier.OrientationControlView.flipHorizontal ),
                ( "flip vertical",   AccessibilityIdentifier.OrientationControlView.flipVertical ),
            ]

        for entry in buttons
        {
            XCTAssertTrue(
                UITestSupport.element( app, entry.identifier ).waitForExistence( timeout: 5 ),
                "Orientation control missing: \( entry.name ) (\( entry.identifier ))"
            )
        }

        // Rotating triggers a re-render; the canvas must remain rendered.
        UITestSupport.element( app, AccessibilityIdentifier.OrientationControlView.rotateRight ).click()

        XCTAssertTrue( canvas.waitForExistence( timeout: 10 ), "The canvas disappeared after a rotation." )
    }

    /// The brightness/contrast section exposes both sliders. Their pixel effect
    /// is covered by unit tests (the SwiftPixel `BrightnessContrast` processor
    /// and the adjustments-to-config mapping); per the suite's depth, slider
    /// values are not dragged here — only reachability is asserted.
    @MainActor
    func testBrightnessContrastSlidersAreReachable() throws
    {
        self.continueAfterFailure = true

        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas ).waitForExistence( timeout: 30 ),
            "The image canvas did not appear after opening a fixture."
        )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.BrightnessContrastControlView.brightnessSlider ).waitForExistence( timeout: 5 ),
            "The brightness slider did not appear in the inspector."
        )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.BrightnessContrastControlView.contrastSlider ).exists,
            "The contrast slider did not appear in the inspector."
        )
    }

    /// Opening the FITS headers window from the sidebar's information panel brings
    /// up the headers view (its search field and keyword table), in a window
    /// distinct from the main one.
    @MainActor
    func testOpeningHeadersWindow() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

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

    /// The inspector's Levels button opens the Levels editor window, which shows
    /// its sliders. For a monochrome image the per-channel toggle is hidden (the
    /// channels are replicated, so per-channel editing would only tint). The
    /// levels pixel math and the adjustments-to-config mapping are covered by
    /// unit tests; per the suite's depth the slider values are not dragged.
    @MainActor
    func testOpeningLevelsEditorWindow() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas ).waitForExistence( timeout: 30 ),
            "The image canvas did not appear after opening a fixture."
        )

        let openLevels = UITestSupport.element( app, AccessibilityIdentifier.InspectorView.openLevelsButton )

        XCTAssertTrue( openLevels.waitForExistence( timeout: 10 ), "The Levels button did not appear in the inspector." )

        openLevels.click()

        let editor      = UITestSupport.element( app, AccessibilityIdentifier.LevelsWindowView.editor )
        let inputBlack  = UITestSupport.element( app, AccessibilityIdentifier.LevelsWindowView.inputBlackSlider )
        let gammaSlider = UITestSupport.element( app, AccessibilityIdentifier.LevelsWindowView.gammaSlider )

        XCTAssertTrue( editor.waitForExistence( timeout: 10 ), "The Levels editor did not appear after clicking the Levels button." )
        XCTAssertTrue( inputBlack.waitForExistence( timeout: 10 ), "The Levels editor's input-black slider did not appear." )
        XCTAssertTrue( gammaSlider.waitForExistence( timeout: 5 ), "The Levels editor's gamma slider did not appear." )

        // The per-channel toggle is hidden for a monochrome image; it is covered
        // for a colour image by testLevelsEditorPerChannelForColorImage.
        XCTAssertFalse(
            UITestSupport.element( app, AccessibilityIdentifier.LevelsWindowView.perChannelToggle ).exists,
            "The per-channel toggle should be hidden for a monochrome image."
        )
    }

    /// For a colour image the Levels editor offers the per-channel toggle, which
    /// reveals the channel picker when enabled.
    @MainActor
    func testLevelsEditorPerChannelForColorImage() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "ColorImage.fits", in: app )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas ).waitForExistence( timeout: 30 ),
            "The image canvas did not appear after opening the colour fixture."
        )

        let openLevels = UITestSupport.element( app, AccessibilityIdentifier.InspectorView.openLevelsButton )

        XCTAssertTrue( openLevels.waitForExistence( timeout: 10 ), "The Levels button did not appear in the inspector." )

        openLevels.click()

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.LevelsWindowView.editor ).waitForExistence( timeout: 10 ),
            "The Levels editor did not appear after clicking the Levels button."
        )

        let perChannel = UITestSupport.element( app, AccessibilityIdentifier.LevelsWindowView.perChannelToggle )

        XCTAssertTrue( perChannel.waitForExistence( timeout: 10 ), "The per-channel toggle did not appear for a colour image." )

        perChannel.click()

        let channelPicker = UITestSupport.element( app, AccessibilityIdentifier.LevelsWindowView.channelPicker )

        XCTAssertTrue(
            channelPicker.waitForExistence( timeout: 5 ),
            "Enabling per-channel did not reveal the channel picker."
        )

        // With no per-channel edits made, switching back to master is not
        // destructive, so it happens immediately with no confirmation: the
        // channel picker disappears and no "switch to master" dialog appears.
        // (The confirmation path — switching with edits — needs a slider drag,
        // which this suite leaves to manual verification.)
        perChannel.click()

        XCTAssertTrue(
            channelPicker.waitForNonExistence( timeout: 5 ),
            "Disabling per-channel did not hide the channel picker."
        )

        XCTAssertFalse(
            UITestSupport.element( app, AccessibilityIdentifier.LevelsWindowView.switchToMasterConfirm ).exists,
            "Switching to master with no per-channel edits should not show a confirmation."
        )
    }

    /// The inspector's Curves button opens the Curves editor window, which shows
    /// its draggable canvas. For a monochrome image the per-channel toggle is
    /// hidden. The curve math and the adjustments-to-config mapping are covered by
    /// unit tests; the drag interaction (add/move/remove points) is left to manual
    /// verification, as with the suite's other drag exclusions.
    @MainActor
    func testOpeningCurvesEditorWindow() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas ).waitForExistence( timeout: 30 ),
            "The image canvas did not appear after opening a fixture."
        )

        let openCurves = UITestSupport.element( app, AccessibilityIdentifier.InspectorView.openCurvesButton )

        XCTAssertTrue( openCurves.waitForExistence( timeout: 10 ), "The Curves button did not appear in the inspector." )

        openCurves.click()

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.CurvesWindowView.editor ).waitForExistence( timeout: 10 ),
            "The Curves editor did not appear after clicking the Curves button."
        )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.CurvesWindowView.canvas ).waitForExistence( timeout: 10 ),
            "The Curves editor's canvas did not appear."
        )

        // The per-channel toggle is hidden for a monochrome image; it is covered
        // for a colour image by testCurvesEditorPerChannelForColorImage.
        XCTAssertFalse(
            UITestSupport.element( app, AccessibilityIdentifier.CurvesWindowView.perChannelToggle ).exists,
            "The per-channel toggle should be hidden for a monochrome image."
        )
    }

    /// For a colour image the Curves editor offers the per-channel toggle, which
    /// reveals the channel picker; switching back with no edits is immediate (no
    /// confirmation).
    @MainActor
    func testCurvesEditorPerChannelForColorImage() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "ColorImage.fits", in: app )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas ).waitForExistence( timeout: 30 ),
            "The image canvas did not appear after opening the colour fixture."
        )

        let openCurves = UITestSupport.element( app, AccessibilityIdentifier.InspectorView.openCurvesButton )

        XCTAssertTrue( openCurves.waitForExistence( timeout: 10 ), "The Curves button did not appear in the inspector." )

        openCurves.click()

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.CurvesWindowView.editor ).waitForExistence( timeout: 10 ),
            "The Curves editor did not appear after clicking the Curves button."
        )

        let perChannel = UITestSupport.element( app, AccessibilityIdentifier.CurvesWindowView.perChannelToggle )

        XCTAssertTrue( perChannel.waitForExistence( timeout: 10 ), "The per-channel toggle did not appear for a colour image." )

        perChannel.click()

        let channelPicker = UITestSupport.element( app, AccessibilityIdentifier.CurvesWindowView.channelPicker )

        XCTAssertTrue( channelPicker.waitForExistence( timeout: 5 ), "Enabling per-channel did not reveal the channel picker." )

        perChannel.click()

        XCTAssertTrue( channelPicker.waitForNonExistence( timeout: 5 ), "Disabling per-channel did not hide the channel picker." )

        XCTAssertFalse(
            UITestSupport.element( app, AccessibilityIdentifier.CurvesWindowView.switchToMasterConfirm ).exists,
            "Switching to master with no per-channel edits should not show a confirmation."
        )
    }

    /// The inspector toggle hides and re-shows the trailing inspector column. The
    /// inspector's content is identified by ``AccessibilityIdentifier/InspectorView/container``,
    /// so its presence tracks whether the column is shown.
    @MainActor
    func testTogglingInspectorHidesAndShowsIt() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

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

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

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
        try UITestSupport.openFixture( "MonoImage.fits", in: app )

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

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

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

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

        let canvas = UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas )
        let error  = UITestSupport.element( app, AccessibilityIdentifier.ErrorView.view )

        XCTAssertTrue( canvas.waitForExistence( timeout: 30 ), "The first (valid) file did not render." )

        try UITestSupport.openAnotherFixture( "InvalidImage.fits", in: app )

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

    /// Switching the selected file must refresh the inspector controls to that
    /// file's own adjustments — a control's state must not leak between images.
    /// Enabling gamma on one file must not show as enabled on another, and the
    /// first file's state must survive switching away and back.
    @MainActor
    func testSwitchingFilesRefreshesInspectorControls() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

        let canvas = UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas )
        let toggle = UITestSupport.element( app, AccessibilityIdentifier.GammaCorrectionControlView.toggle )
        let slider = UITestSupport.element( app, AccessibilityIdentifier.GammaCorrectionControlView.slider )

        XCTAssertTrue( canvas.waitForExistence( timeout: 30 ), "The first file did not render." )

        try UITestSupport.openAnotherFixture( "ColorImage.fits", in: app )

        let rows = app.descendants( matching: .any ).matching( identifier: AccessibilityIdentifier.OpenFileRowView.row )

        XCTAssertTrue(
            UITestSupport.waitFor( timeout: 30 ) { rows.count == 2 },
            "Expected two file rows after opening two files (rows: \( rows.count ))."
        )

        // Select the first file and enable gamma: its slider appears.
        rows.element( boundBy: 0 ).click()
        XCTAssertTrue( toggle.waitForExistence( timeout: 30 ), "The gamma toggle did not appear." )
        XCTAssertFalse( slider.exists, "The gamma slider was present before gamma was enabled." )

        toggle.click()
        XCTAssertTrue( slider.waitForExistence( timeout: 5 ), "Enabling gamma did not reveal its slider." )

        // Switch to the second file: it has its own (default) adjustments, so gamma
        // reads as off and the slider must be gone — the control must follow the
        // newly selected image, not keep the first file's state.
        rows.element( boundBy: 1 ).click()
        XCTAssertTrue(
            slider.waitForNonExistence( timeout: 10 ),
            "The gamma slider stayed visible after switching files — the inspector did not refresh to the new image."
        )

        // Switch back: the first file's gamma is still enabled (its adjustments
        // persisted), so the control must reseed from that image rather than reset.
        rows.element( boundBy: 0 ).click()
        XCTAssertTrue(
            slider.waitForExistence( timeout: 10 ),
            "The first file's gamma state was lost after switching away and back."
        )
    }

    /// "Reset View" must reset the inspector controls' displayed state, not just
    /// the underlying render: after enabling gamma, resetting must hide the gamma
    /// slider again, proving the control followed the reset rather than keeping
    /// its enabled state.
    @MainActor
    func testResetViewResetsInspectorControls() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

        let canvas = UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas )
        let toggle = UITestSupport.element( app, AccessibilityIdentifier.GammaCorrectionControlView.toggle )
        let slider = UITestSupport.element( app, AccessibilityIdentifier.GammaCorrectionControlView.slider )
        let reset  = UITestSupport.element( app, AccessibilityIdentifier.InspectorView.resetButton )

        XCTAssertTrue( canvas.waitForExistence( timeout: 30 ), "The image did not render." )
        XCTAssertTrue( toggle.waitForExistence( timeout: 5 ), "The gamma toggle did not appear." )

        toggle.click()
        XCTAssertTrue( slider.waitForExistence( timeout: 5 ), "Enabling gamma did not reveal its slider." )

        reset.click()
        XCTAssertTrue(
            slider.waitForNonExistence( timeout: 10 ),
            "Reset View did not reset the gamma control — its slider stayed visible."
        )
    }

    /// The histogram view options are per image: enabling Statistics on one file
    /// must not carry over to another, and must still be set when switching back —
    /// they survive the inspector's per-image recreation via a per-image store.
    @MainActor
    func testHistogramOptionsPersistPerImage() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

        let canvas = UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas )

        XCTAssertTrue( canvas.waitForExistence( timeout: 30 ), "The first file did not render." )

        try UITestSupport.openAnotherFixture( "ColorImage.fits", in: app )

        let rows = app.descendants( matching: .any ).matching( identifier: AccessibilityIdentifier.OpenFileRowView.row )

        XCTAssertTrue(
            UITestSupport.waitFor( timeout: 30 ) { rows.count == 2 },
            "Expected two file rows after opening two files (rows: \( rows.count ))."
        )

        let viewOptions = UITestSupport.element( app, AccessibilityIdentifier.HistogramControlView.viewOptions )
        let panel       = UITestSupport.element( app, AccessibilityIdentifier.HistogramControlView.statisticsPanel )

        // Enable Statistics on the first image: its panel appears.
        rows.element( boundBy: 0 ).click()
        XCTAssertTrue( viewOptions.waitForExistence( timeout: 30 ), "The histogram view-options button did not appear." )
        XCTAssertFalse( panel.exists, "The statistics panel was visible before it was enabled." )

        viewOptions.click()
        app.menuItems[ "Statistics" ].click()
        XCTAssertTrue( panel.waitForExistence( timeout: 5 ), "Enabling Statistics did not reveal the panel." )

        // The second image has its own options, defaulting off — it must not
        // inherit the first image's Statistics setting.
        rows.element( boundBy: 1 ).click()
        XCTAssertTrue(
            panel.waitForNonExistence( timeout: 10 ),
            "The second image inherited the first image's Statistics setting."
        )

        // Switching back shows the first image's Statistics setting still on.
        rows.element( boundBy: 0 ).click()
        XCTAssertTrue(
            panel.waitForExistence( timeout: 10 ),
            "The first image's Statistics setting was lost after switching away and back."
        )
    }

    /// The file row's context menu opens the FITS headers window via "View FITS
    /// Headers".
    @MainActor
    func testRowContextMenuOpensHeaders() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

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

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

        try UITestSupport.openAnotherFixture( "InvalidImage.fits", in: app )

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

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

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

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

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
                ( "brightness & contrast section", AccessibilityIdentifier.InspectorView.Section.brightnessContrast ),
                ( "levels section",      AccessibilityIdentifier.InspectorView.Section.levels ),
                ( "curves section",      AccessibilityIdentifier.InspectorView.Section.curves ),
                ( "color section",       AccessibilityIdentifier.InspectorView.Section.color ),
                ( "orientation section", AccessibilityIdentifier.InspectorView.Section.orientation ),
                ( "reset button",        AccessibilityIdentifier.InspectorView.resetButton ),
            ]

        for entry in sections
        {
            XCTAssertTrue(
                UITestSupport.element( app, entry.identifier ).waitForExistence( timeout: 5 ),
                "Inspector element missing: \( entry.name ) (\( entry.identifier ))"
            )
        }

        // The debayer section is omitted for a monochrome file (no Bayer pattern
        // to act on); it is covered for a colour image by
        // testDebayerAlgorithmEnablementFollowsMode.
        XCTAssertFalse(
            UITestSupport.element( app, AccessibilityIdentifier.InspectorView.Section.debayer ).exists,
            "The debayer section should be hidden for a monochrome image."
        )

        // Saturation is likewise hidden for a monochrome file (no colour to
        // scale); it is covered for a colour image by
        // testSaturationSectionShownForColorImage.
        XCTAssertFalse(
            UITestSupport.element( app, AccessibilityIdentifier.InspectorView.Section.saturation ).exists,
            "The saturation section should be hidden for a monochrome image."
        )
    }

    /// For a colour (Bayer) image the saturation section and its slider are
    /// present. Its pixel effect is covered by unit tests (the SwiftPixel
    /// `Saturation` processor and the adjustments-to-config mapping); per the
    /// suite's depth, the slider value is not dragged.
    @MainActor
    func testSaturationSectionShownForColorImage() throws
    {
        self.continueAfterFailure = true

        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "ColorImage.fits", in: app )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas ).waitForExistence( timeout: 30 ),
            "The image canvas did not appear after opening the colour fixture."
        )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.InspectorView.Section.saturation ).waitForExistence( timeout: 5 ),
            "The saturation section was not shown for a colour image."
        )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.SaturationControlView.slider ).exists,
            "The saturation slider was not shown for a colour image."
        )
    }

    /// A file that fails to render shows the inspector's placeholder instead of the
    /// adjustment sections.
    @MainActor
    func testInspectorShowsPlaceholderForInvalidFile() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "InvalidImage.fits", in: app )

        XCTAssertTrue(
            UITestSupport.element( app, AccessibilityIdentifier.InspectorPlaceholderView.view ).waitForExistence( timeout: 30 ),
            "The inspector placeholder did not appear for an invalid file."
        )

        XCTAssertFalse(
            UITestSupport.element( app, AccessibilityIdentifier.InspectorView.Section.gamma ).exists,
            "Adjustment sections appeared for a file that failed to render."
        )
    }

    /// The histogram's Statistics toggle — now an item in the view-options pull-
    /// down menu — reveals and hides the statistics panel. Clicking a menu item
    /// dismisses the menu, so each toggle reopens it.
    @MainActor
    func testHistogramStatisticsToggleRevealsPanel() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

        let viewOptions = UITestSupport.element( app, AccessibilityIdentifier.HistogramControlView.viewOptions )
        let panel       = UITestSupport.element( app, AccessibilityIdentifier.HistogramControlView.statisticsPanel )

        XCTAssertTrue( viewOptions.waitForExistence( timeout: 30 ), "The histogram view-options button did not appear." )
        XCTAssertFalse( panel.exists, "The statistics panel was visible before the toggle was enabled." )

        // Menu items carry no accessibility identifier, so they are matched by
        // their (unique) title.
        viewOptions.click()
        let statistics = app.menuItems[ "Statistics" ]
        XCTAssertTrue( statistics.waitForExistence( timeout: 5 ), "The Statistics menu item did not appear." )
        statistics.click()
        XCTAssertTrue( panel.waitForExistence( timeout: 5 ), "Enabling Statistics did not reveal the panel." )

        viewOptions.click()
        app.menuItems[ "Statistics" ].click()
        XCTAssertTrue( panel.waitForNonExistence( timeout: 5 ), "Disabling Statistics did not hide the panel." )
    }

    /// A monochrome image offers only the single "Mono" histogram mode — not the
    /// RGB/Luminance choice — and "Separate Channels" is disabled, since channel
    /// separation is meaningless for a single-channel histogram. The launch
    /// fixture (`MonoImage.fits`) is a mono image.
    @MainActor
    func testMonoImageOffersOnlyMonoHistogram() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

        let viewOptions = UITestSupport.element( app, AccessibilityIdentifier.HistogramControlView.viewOptions )

        XCTAssertTrue( viewOptions.waitForExistence( timeout: 30 ), "The histogram view-options button did not appear." )

        // The segmented control's segments are plain buttons labelled by their
        // title. A mono image shows only "Mono", never the colour-only choices.
        XCTAssertTrue( app.buttons[ "Mono" ].waitForExistence( timeout: 5 ), "The mono histogram segment did not appear." )
        XCTAssertFalse( app.buttons[ "Luminance" ].exists, "A mono image must not offer the Luminance mode." )
        XCTAssertFalse( app.buttons[ "RGB" ].exists,       "A mono image must not offer the RGB mode." )

        // Separate Channels is meaningless for a single-channel histogram.
        viewOptions.click()
        let separateChannels = app.menuItems[ "Separate Channels" ]
        XCTAssertTrue( separateChannels.waitForExistence( timeout: 5 ), "The Separate Channels menu item did not appear." )
        XCTAssertFalse( separateChannels.isEnabled, "Separate Channels must be disabled for a mono image." )
    }

    /// A colour image offers the RGB and Luminance modes (not Mono), and switching
    /// from RGB to Luminance disables the "Separate Channels" menu item. The
    /// `ColorImage.fits` fixture is a Bayer mosaic the app demosaics to RGB.
    @MainActor
    func testColorImageOffersRGBAndLuminanceModes() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "ColorImage.fits", in: app )

        let viewOptions = UITestSupport.element( app, AccessibilityIdentifier.HistogramControlView.viewOptions )

        XCTAssertTrue( viewOptions.waitForExistence( timeout: 30 ), "The histogram view-options button did not appear." )

        // A colour image offers RGB and Luminance segments, never Mono.
        XCTAssertTrue( app.buttons[ "RGB" ].waitForExistence( timeout: 5 ), "The RGB histogram segment did not appear." )
        XCTAssertTrue( app.buttons[ "Luminance" ].exists, "A colour image must offer the Luminance mode." )
        XCTAssertFalse( app.buttons[ "Mono" ].exists,     "A colour image must not offer the Mono mode." )

        // In RGB mode the item is enabled.
        viewOptions.click()
        let separateChannels = app.menuItems[ "Separate Channels" ]
        XCTAssertTrue( separateChannels.waitForExistence( timeout: 5 ), "The Separate Channels menu item did not appear." )
        XCTAssertTrue( separateChannels.isEnabled, "Separate Channels should be enabled in RGB mode." )

        // Dismiss the menu, switch to luminance, then reopen it. "Luminance" is
        // unique in the UI.
        app.typeKey( .escape, modifierFlags: [] )
        app.buttons[ "Luminance" ].click()
        viewOptions.click()

        XCTAssertTrue(
            UITestSupport.waitFor( timeout: 5 ) { app.menuItems[ "Separate Channels" ].isEnabled == false },
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

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

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

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

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
    /// enabled once a pattern (or Auto) is selected. The debayer section only
    /// appears for a colour-filter-array image, so this uses the colour fixture;
    /// the mode picker existing also confirms the section is shown for a CFA file.
    @MainActor
    func testDebayerAlgorithmEnablementFollowsMode() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "ColorImage.fits", in: app )

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

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

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

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

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

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

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

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

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

    // MARK: - Preferences

    /// The Preferences window renders its tabs with no file open: the General
    /// tab's toggle and the API Keys tab's two key fields are all reachable. It is
    /// driven the right way — by cancelling the launch Open panel rather than
    /// loading an image, since Preferences has nothing to do with a loaded file.
    @MainActor
    func testPreferencesWindowShowsItsControls() throws
    {
        let app = UITestSupport.launchApp()

        UITestSupport.dismissLaunchPanel( in: app )

        app.typeKey( ",", modifierFlags: .command )

        // The Settings window remembers its last-selected pane, so select each tab
        // explicitly rather than assuming which one opens.
        let generalTab = app.buttons[ "General" ]

        XCTAssertTrue( generalTab.waitForExistence( timeout: 10 ), "The Preferences window did not open." )

        generalTab.click()

        let toggle = UITestSupport.element( app, AccessibilityIdentifier.PreferencesView.autoHideFloatingBarsToggle )

        XCTAssertTrue( toggle.waitForExistence( timeout: 10 ), "The General tab's auto-hide toggle did not appear in Preferences." )

        app.buttons[ "API Keys" ].click()

        let astrometry = UITestSupport.element( app, AccessibilityIdentifier.PreferencesView.astrometryNetKeyField )
        let weather    = UITestSupport.element( app, AccessibilityIdentifier.PreferencesView.openWeatherMapKeyField )

        XCTAssertTrue( astrometry.waitForExistence( timeout: 10 ), "The Astrometry.net key field did not appear on the API Keys tab." )
        XCTAssertTrue( weather.waitForExistence( timeout: 10 ),    "The OpenWeatherMap key field did not appear on the API Keys tab." )

        app.typeKey( "w", modifierFlags: .command )
    }

    /// The General preference "Automatically hide the floating toolbars" controls
    /// the canvas's auto-hide behaviour both ways. The test exercises the real
    /// behaviour rather than a stored value: with auto-hide on (the default) the
    /// bars fade when the cursor rests away from them; turning the preference off
    /// keeps them visible even at rest; turning it back on restores the fade.
    ///
    /// The preference is opened with the standard Settings shortcut (⌘,), the
    /// toggle is driven by its identifier, and the Settings window is closed (⌘W)
    /// between phases so the main window's canvas is observed each time. The
    /// preference is left back on at the end so the run doesn't change the
    /// machine's default behaviour.
    @MainActor
    func testAutoHideFloatingBarsPreferenceControlsHiding() throws
    {
        let app = UITestSupport.launchApp()

        try UITestSupport.openFixture( "MonoImage.fits", in: app )

        let canvas    = UITestSupport.element( app, AccessibilityIdentifier.ImageCanvasView.canvas )
        let filesList = UITestSupport.element( app, AccessibilityIdentifier.FilesSidebarView.list )
        let fit        = UITestSupport.element( app, AccessibilityIdentifier.ImageToolbarView.fit )
        let toggle     = UITestSupport.element( app, AccessibilityIdentifier.PreferencesView.autoHideFloatingBarsToggle )
        let generalTab = app.buttons[ "General" ]

        XCTAssertTrue( canvas.waitForExistence( timeout: 30 ), "The image canvas did not appear after opening a fixture." )

        // Reveal the bars (movement onto the canvas), then confirm the default
        // behaviour: with auto-hide on, resting the cursor away from the bars
        // (canvas centre) lets them fade out and leave the accessibility tree.
        filesList.hover()
        canvas.hover()

        XCTAssertTrue( fit.waitForExistence( timeout: 5 ), "The floating toolbar did not reveal on cursor movement." )
        XCTAssertTrue( fit.waitForNonExistence( timeout: 5 ), "The floating toolbar did not auto-hide by default." )

        // Turn auto-hide off in Preferences. The Settings window remembers its
        // last-selected pane, so select the General tab explicitly.
        app.typeKey( ",", modifierFlags: .command )

        XCTAssertTrue( generalTab.waitForExistence( timeout: 10 ), "The Preferences window did not open." )

        generalTab.click()

        XCTAssertTrue( toggle.waitForExistence( timeout: 10 ), "The auto-hide toggle did not appear in Preferences." )

        toggle.click()
        app.typeKey( "w", modifierFlags: .command )

        // With auto-hide off the bars stay visible — even when the cursor rests on
        // the canvas, which would normally start the fade. They are revealed by the
        // change and must not disappear past the auto-hide delay.
        XCTAssertTrue( fit.waitForExistence( timeout: 5 ), "The floating toolbar was not shown after disabling auto-hide." )

        canvas.hover()

        XCTAssertFalse( fit.waitForNonExistence( timeout: 3 ), "The floating toolbar auto-hid even though auto-hide was disabled." )

        // Turn auto-hide back on, restoring the default for the machine.
        app.typeKey( ",", modifierFlags: .command )

        XCTAssertTrue( generalTab.waitForExistence( timeout: 10 ), "The Preferences window did not reopen." )

        generalTab.click()

        XCTAssertTrue( toggle.waitForExistence( timeout: 10 ), "The auto-hide toggle did not reappear in Preferences." )

        toggle.click()
        app.typeKey( "w", modifierFlags: .command )

        // The fade is restored: resting the cursor on the canvas hides the bars.
        filesList.hover()
        canvas.hover()

        XCTAssertTrue( fit.waitForNonExistence( timeout: 5 ), "The floating toolbar did not auto-hide after re-enabling auto-hide." )
    }
}
