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

import Foundation

/// Stable accessibility identifiers for the views the UI-test suite drives.
///
/// These give XCUITest a contract that survives copy, layout and localisation
/// changes. The type is grouped into one nested enum per view, mirroring the
/// component that applies each identifier, so the call site and the definition
/// read the same.
///
/// Each string value mirrors its qualified path — e.g.
/// ``AccessibilityIdentifier/ImageToolbarView/zoomIn`` is `"ImageToolbarView.zoomIn"`
/// — so an identifier seen in the accessibility inspector or a test failure
/// names its component and role directly.
///
/// This file is a member of **both** the app and the UI-test target — it has no
/// app dependencies, so the tests reference the very same constants the views
/// set, with no duplicated strings to drift.
public enum AccessibilityIdentifier
{
    /// Identifiers applied by ``FITScope/ImageCanvasView``.
    public enum ImageCanvasView
    {
        /// The zoomable image canvas in the centre pane.
        public static let canvas = "ImageCanvasView.canvas"
    }

    /// Identifiers applied by ``FITScope/GraphView``.
    public enum GraphView
    {
        /// The one-dimensional data graph shown in the detail region.
        public static let chart = "GraphView.chart"
    }

    /// Identifiers applied by ``FITScope/ImageCarouselView``.
    public enum ImageCarouselView
    {
        /// The multi-frame filmstrip shown below the canvas.
        public static let strip = "ImageCarouselView.strip"

        /// A single frame cell, suffixed with the frame's index (e.g.
        /// `"ImageCarouselView.frame.0"`).
        ///
        /// - Parameter index: The frame's index into the file's frames.
        /// - Returns: The cell's identifier.
        public static func frame( _ index: Int ) -> String
        {
            "ImageCarouselView.frame.\( index )"
        }
    }

    /// Identifiers applied by ``FITScope/ImageComparisonLayer``.
    public enum ImageComparisonLayer
    {
        /// The draggable before/after divider handle.
        public static let divider = "ImageComparisonLayer.divider"
    }

    /// Identifiers applied by ``FITScope/LoadingView``.
    public enum LoadingView
    {
        /// The full-pane loading placeholder.
        public static let view = "LoadingView.view"
    }

    /// Identifiers applied by ``FITScope/ErrorView``.
    public enum ErrorView
    {
        /// The full-pane error placeholder.
        public static let view = "ErrorView.view"
    }

    /// Identifiers applied by ``FITScope/StatusBarView``.
    public enum StatusBarView
    {
        /// The floating status pill at the bottom of the canvas.
        public static let bar = "StatusBarView.bar"
    }

    /// Identifiers applied by ``FITScope/FilesSidebarView``.
    public enum FilesSidebarView
    {
        /// The files sidebar list.
        public static let list = "FilesSidebarView.list"

        /// The "open files" (+) button in the sidebar header.
        public static let addButton = "FilesSidebarView.addButton"

        /// The sort menu in the sidebar header.
        public static let sortMenu = "FilesSidebarView.sortMenu"

        /// The button in the sidebar header that opens the session metrics window.
        public static let metricsButton = "FilesSidebarView.metricsButton"
    }

    /// Identifiers applied by ``FITScope/OpenFileRowView``.
    public enum OpenFileRowView
    {
        /// A single row in the files sidebar (shared by every row).
        public static let row = "OpenFileRowView.row"

        /// The per-row pill showing the image's computed weight.
        public static let weightPill = "OpenFileRowView.weightPill"

        /// The per-row marker shown when the file's image has adjustments applied.
        public static let adjustedMarker = "OpenFileRowView.adjustedMarker"
    }

    /// Identifiers applied by ``FITScope/InspectorView``.
    public enum InspectorView
    {
        /// The inspector column's scrolling content.
        public static let container = "InspectorView.container"

        /// The inspector's "Reset View" button.
        public static let resetButton = "InspectorView.resetButton"

        /// The button that opens the Levels editor window.
        public static let openLevelsButton = "InspectorView.openLevelsButton"

        /// The button that opens the Curves editor window.
        public static let openCurvesButton = "InspectorView.openCurvesButton"

        /// Stable identifiers for the inspector's sections.
        ///
        /// Each is an explicit constant rather than a value derived from the
        /// section's display title, so renaming or localizing a heading cannot
        /// silently change the identifier and break the tests.
        public enum Section
        {
            /// The histogram section.
            public static let histogram = "InspectorView.Section.histogram"

            /// The stretch section.
            public static let stretch = "InspectorView.Section.stretch"

            /// The white-balance section.
            public static let whiteBalance = "InspectorView.Section.whiteBalance"

            /// The debayer section.
            public static let debayer = "InspectorView.Section.debayer"

            /// The color section.
            public static let color = "InspectorView.Section.color"

            /// The brightness & contrast section.
            public static let brightnessContrast = "InspectorView.Section.brightnessContrast"

            /// The colour-balance section (colour images only).
            public static let colorBalance = "InspectorView.Section.colorBalance"

            /// The saturation section (colour images only).
            public static let saturation = "InspectorView.Section.saturation"

            /// The combined levels & curves section (holds the buttons opening the
            /// Levels and Curves editors).
            public static let levelsCurves = "InspectorView.Section.levelsCurves"

            /// The orientation (rotate / flip) section.
            public static let orientation = "InspectorView.Section.orientation"
        }

        /// Per-section reset buttons shown in a section header when that section
        /// deviates from its defaults.
        public enum SectionReset
        {
            /// The orientation section's reset button.
            public static let orientation = "InspectorView.SectionReset.orientation"

            /// The white-balance section's reset button.
            public static let whiteBalance = "InspectorView.SectionReset.whiteBalance"

            /// The debayer section's reset button.
            public static let debayer = "InspectorView.SectionReset.debayer"

            /// The stretch section's reset button.
            public static let stretch = "InspectorView.SectionReset.stretch"

            /// The color section's reset button.
            public static let color = "InspectorView.SectionReset.color"

            /// The colour-balance section's reset button.
            public static let colorBalance = "InspectorView.SectionReset.colorBalance"
        }
    }

    /// Identifiers applied by ``FITScope/LevelsWindowView`` and its editor.
    public enum LevelsWindowView
    {
        /// The editor's root container, present when an image is being edited.
        public static let editor = "LevelsWindowView.editor"

        /// The placeholder shown when no image is available to edit.
        public static let unavailable = "LevelsWindowView.unavailable"

        /// The per-channel toggle (colour images only).
        public static let perChannelToggle = "LevelsWindowView.perChannelToggle"

        /// The "Switch to Master" button in the confirmation shown when leaving
        /// per-channel mode with edits.
        public static let switchToMasterConfirm = "LevelsWindowView.switchToMasterConfirm"

        /// The channel picker shown while editing per channel.
        public static let channelPicker = "LevelsWindowView.channelPicker"

        /// The input black-point slider.
        public static let inputBlackSlider = "LevelsWindowView.inputBlackSlider"

        /// The input white-point slider.
        public static let inputWhiteSlider = "LevelsWindowView.inputWhiteSlider"

        /// The midtone gamma slider.
        public static let gammaSlider = "LevelsWindowView.gammaSlider"

        /// The output black-point slider.
        public static let outputBlackSlider = "LevelsWindowView.outputBlackSlider"

        /// The output white-point slider.
        public static let outputWhiteSlider = "LevelsWindowView.outputWhiteSlider"

        /// The reset button for the input black-point slider.
        public static let inputBlackReset = "LevelsWindowView.inputBlackReset"

        /// The reset button for the input white-point slider.
        public static let inputWhiteReset = "LevelsWindowView.inputWhiteReset"

        /// The reset button for the midtone gamma slider.
        public static let gammaReset = "LevelsWindowView.gammaReset"

        /// The reset button for the output black-point slider.
        public static let outputBlackReset = "LevelsWindowView.outputBlackReset"

        /// The reset button for the output white-point slider.
        public static let outputWhiteReset = "LevelsWindowView.outputWhiteReset"

        /// The button that resets the levels to their defaults.
        public static let resetButton = "LevelsWindowView.resetButton"
    }

    /// Identifiers applied by ``FITScope/STFEditorView`` (the Screen Transfer
    /// editor window).
    public enum ScreenTransferWindowView
    {
        /// The editor's root container, present when an image is being edited.
        public static let editor = "ScreenTransferWindowView.editor"

        /// The placeholder shown when no image is available to edit.
        public static let unavailable = "ScreenTransferWindowView.unavailable"

        /// The per-channel toggle (colour images only).
        public static let perChannelToggle = "ScreenTransferWindowView.perChannelToggle"

        /// The "Switch to Master" button in the confirmation shown when leaving
        /// per-channel mode with edits.
        public static let switchToMasterConfirm = "ScreenTransferWindowView.switchToMasterConfirm"

        /// The channel picker shown while editing per channel.
        public static let channelPicker = "ScreenTransferWindowView.channelPicker"

        /// The shadows clip-point slider.
        public static let shadowsSlider = "ScreenTransferWindowView.shadowsSlider"

        /// The midtones balance slider.
        public static let midtonesSlider = "ScreenTransferWindowView.midtonesSlider"

        /// The highlights clip-point slider.
        public static let highlightsSlider = "ScreenTransferWindowView.highlightsSlider"

        /// The low range-expansion slider.
        public static let lowSlider = "ScreenTransferWindowView.lowSlider"

        /// The high range-expansion slider.
        public static let highSlider = "ScreenTransferWindowView.highSlider"

        /// The auto shadow-clip-factor slider.
        public static let shadowClipFactorSlider = "ScreenTransferWindowView.shadowClipFactorSlider"

        /// The auto target-background slider.
        public static let targetBackgroundSlider = "ScreenTransferWindowView.targetBackgroundSlider"

        /// The reset button for the shadows slider.
        public static let shadowsReset = "ScreenTransferWindowView.shadowsReset"

        /// The reset button for the midtones slider.
        public static let midtonesReset = "ScreenTransferWindowView.midtonesReset"

        /// The reset button for the highlights slider.
        public static let highlightsReset = "ScreenTransferWindowView.highlightsReset"

        /// The reset button for the low range-expansion slider.
        public static let lowReset = "ScreenTransferWindowView.lowReset"

        /// The reset button for the high range-expansion slider.
        public static let highReset = "ScreenTransferWindowView.highReset"

        /// The reset button for the auto shadow-clip-factor slider.
        public static let shadowClipFactorReset = "ScreenTransferWindowView.shadowClipFactorReset"

        /// The reset button for the auto target-background slider.
        public static let targetBackgroundReset = "ScreenTransferWindowView.targetBackgroundReset"

        /// The button that derives and applies an auto-STF from the image.
        public static let autoButton = "ScreenTransferWindowView.autoButton"

        /// The button that resets the screen transfer to the identity.
        public static let resetButton = "ScreenTransferWindowView.resetButton"
    }

    /// Identifiers applied by ``FITScope/CurvesWindowView`` and its editor.
    public enum CurvesWindowView
    {
        /// The editor's root container, present when an image is being edited.
        public static let editor = "CurvesWindowView.editor"

        /// The placeholder shown when no image is available to edit.
        public static let unavailable = "CurvesWindowView.unavailable"

        /// The interactive curve-editor canvas.
        public static let canvas = "CurvesWindowView.canvas"

        /// The per-channel toggle (colour images only).
        public static let perChannelToggle = "CurvesWindowView.perChannelToggle"

        /// The "Switch to Master" button in the confirmation shown when leaving
        /// per-channel mode with edits.
        public static let switchToMasterConfirm = "CurvesWindowView.switchToMasterConfirm"

        /// The channel picker shown while editing per channel.
        public static let channelPicker = "CurvesWindowView.channelPicker"

        /// The button that resets the curve to the identity (a straight line).
        public static let resetButton = "CurvesWindowView.resetButton"
    }

    /// Identifiers applied by ``FITScope/ImageToolbarView``.
    public enum ImageToolbarView
    {
        /// The recenter button.
        public static let recenter = "ImageToolbarView.recenter"

        /// The zoom-out button.
        public static let zoomOut = "ImageToolbarView.zoomOut"

        /// The zoom-in button.
        public static let zoomIn = "ImageToolbarView.zoomIn"

        /// The fit-to-window button.
        public static let fit = "ImageToolbarView.fit"

        /// The actual-size (100%) button.
        public static let actualSize = "ImageToolbarView.actualSize"

        /// The zoom-percentage readout between the zoom-out and zoom-in buttons.
        public static let zoomReadout = "ImageToolbarView.zoomReadout"

        /// The plate-solve button.
        public static let plateSolve = "ImageToolbarView.plateSolve"

        /// The before/after comparison toggle button.
        public static let compare = "ImageToolbarView.compare"

        /// The toggle button for the overlay with the given stable identifier.
        ///
        /// - Parameter overlay: The overlay's stable ``CanvasOverlay/id``.
        /// - Returns: The toggle's accessibility identifier.
        public static func overlayToggle( _ overlay: String ) -> String
        {
            "ImageToolbarView.overlayToggle.\( overlay )"
        }
    }

    /// Identifiers applied by ``FITScope/PlateSolveResultView``.
    public enum PlateSolveWindowView
    {
        /// The status line (progress label, "Solved", or failure headline).
        public static let status = "PlateSolveWindowView.status"
    }

    /// Identifiers applied by ``FITScope/BrightnessContrastControlView``.
    public enum BrightnessContrastControlView
    {
        /// The brightness slider.
        public static let brightnessSlider = "BrightnessContrastControlView.brightnessSlider"

        /// The contrast slider.
        public static let contrastSlider = "BrightnessContrastControlView.contrastSlider"

        /// The reset button for the brightness slider.
        public static let brightnessReset = "BrightnessContrastControlView.brightnessReset"

        /// The reset button for the contrast slider.
        public static let contrastReset = "BrightnessContrastControlView.contrastReset"
    }

    /// Identifiers applied by ``FITScope/SaturationControlView``.
    public enum SaturationControlView
    {
        /// The saturation slider.
        public static let slider = "SaturationControlView.slider"

        /// The reset button for the saturation slider.
        public static let reset = "SaturationControlView.reset"

        /// The hue slider.
        public static let hueSlider = "SaturationControlView.hueSlider"

        /// The reset button for the hue slider.
        public static let hueReset = "SaturationControlView.hueReset"
    }

    /// Identifiers applied by ``FITScope/ColorBalanceControlView``.
    public enum ColorBalanceControlView
    {
        /// The Shadows / Midtones / Highlights segmented range picker.
        public static let rangePicker = "ColorBalanceControlView.rangePicker"
    }

    /// Identifiers applied by ``FITScope/OrientationControlView``.
    public enum OrientationControlView
    {
        /// The rotate-left (counter-clockwise) button.
        public static let rotateLeft = "OrientationControlView.rotateLeft"

        /// The rotate-right (clockwise) button.
        public static let rotateRight = "OrientationControlView.rotateRight"

        /// The flip-horizontal button.
        public static let flipHorizontal = "OrientationControlView.flipHorizontal"

        /// The flip-vertical button.
        public static let flipVertical = "OrientationControlView.flipVertical"
    }

    /// Identifiers applied by ``FITScope/HistogramControlView``.
    public enum HistogramControlView
    {
        /// The RGB / Luminance mode segmented control.
        public static let mode = "HistogramControlView.mode"

        /// The view-options menu button that holds the histogram toggles. The
        /// toggles themselves are menu items, which carry no identifier — tests
        /// drive them by title.
        public static let viewOptions = "HistogramControlView.viewOptions"

        /// The statistics panel, shown only while the Statistics toggle is on.
        public static let statisticsPanel = "HistogramControlView.statisticsPanel"
    }

    /// Identifiers applied by ``FITScope/StretchControlView``.
    public enum StretchControlView
    {
        /// The stretch-mode picker.
        public static let modePicker = "StretchControlView.modePicker"

        /// The Auto button (shown only in screen-transfer mode) that derives and
        /// applies an auto-STF from the image.
        public static let autoButton = "StretchControlView.autoButton"

        /// The Edit button (shown only in screen-transfer mode) that opens the
        /// Screen Transfer editor window.
        public static let editButton = "StretchControlView.editButton"
    }

    /// Identifiers applied by ``FITScope/WhiteBalanceControlView``.
    public enum WhiteBalanceControlView
    {
        /// The white-balance mode picker.
        public static let modePicker = "WhiteBalanceControlView.modePicker"

        /// The manual red-gain slider (shown only in manual mode).
        public static let redSlider = "WhiteBalanceControlView.redSlider"

        /// The manual green-gain slider (shown only in manual mode).
        public static let greenSlider = "WhiteBalanceControlView.greenSlider"

        /// The manual blue-gain slider (shown only in manual mode).
        public static let blueSlider = "WhiteBalanceControlView.blueSlider"

        /// The reset button for the manual red-gain slider.
        public static let redReset = "WhiteBalanceControlView.redReset"

        /// The reset button for the manual green-gain slider.
        public static let greenReset = "WhiteBalanceControlView.greenReset"

        /// The reset button for the manual blue-gain slider.
        public static let blueReset = "WhiteBalanceControlView.blueReset"
    }

    /// Identifiers applied by ``FITScope/DebayerControlView``.
    public enum DebayerControlView
    {
        /// The Bayer-pattern mode picker.
        public static let modePicker = "DebayerControlView.modePicker"

        /// The reconstruction-algorithm picker (disabled when mode is None).
        public static let algorithmPicker = "DebayerControlView.algorithmPicker"
    }

    /// Identifiers applied by ``FITScope/ColorControlView``.
    public enum ColorControlView
    {
        /// The invert (photographic-negative) toggle.
        public static let invertToggle = "ColorControlView.invertToggle"
    }

    /// Identifiers applied by ``FITScope/ImageInfoPanelView``.
    public enum ImageInfoPanelView
    {
        /// The button that opens the full metadata window.
        public static let viewMetadataButton = "ImageInfoPanelView.viewMetadataButton"
    }

    /// Identifiers applied by ``FITScope/ImageInfoTabView`` (the info-panel tab
    /// host below the file list).
    public enum ImageInfoTabView
    {
        /// The segmented control switching between the Info, Location, Moon and
        /// Weather tabs.
        ///
        /// No container-level identifier is applied to the tab host's root: a
        /// container `accessibilityIdentifier` propagates to every descendant
        /// element, which would override the identifiers the inner views set (e.g.
        /// the Info panel's "View Metadata" button), so it is omitted.
        public static let tabs = "ImageInfoTabView.tabs"
    }

    /// Identifiers applied by ``FITScope/LocationMapView``.
    public enum LocationMapView
    {
        /// The map showing the capture location.
        public static let map = "LocationMapView.map"

        /// The button that opens the capture location in the Maps app.
        public static let openInMapsButton = "LocationMapView.openInMapsButton"
    }

    /// Identifiers applied by ``FITScope/MoonPhaseView``.
    public enum MoonPhaseView
    {
        /// The tab's outer container.
        public static let container = "MoonPhaseView.container"

        /// The large lunar-phase symbol.
        public static let icon = "MoonPhaseView.icon"
    }

    /// Identifiers applied by ``FITScope/WeatherView``.
    public enum WeatherView
    {
        /// The weather tab's container.
        public static let container = "WeatherView.container"

        /// The condition symbol.
        public static let icon = "WeatherView.icon"
    }

    /// Identifiers applied by ``FITScope/SunTwilightView``.
    public enum SunTwilightView
    {
        /// The sun & twilight section's container.
        public static let container = "SunTwilightView.container"

        /// The sky-condition symbol.
        public static let icon = "SunTwilightView.icon"
    }

    /// Identifiers applied by ``FITScope/PlanetsView``.
    public enum PlanetsView
    {
        /// The planets tab's container.
        public static let container = "PlanetsView.container"

        /// The planets header symbol.
        public static let icon = "PlanetsView.icon"
    }

    /// Identifiers applied by ``FITScope/AnalysisView``.
    public enum AnalysisView
    {
        /// The analysis tab's container.
        public static let container = "AnalysisView.container"
    }

    /// Identifiers applied by ``FITScope/StarsView``.
    public enum StarsView
    {
        /// The stars section's container.
        public static let container = "StarsView.container"

        /// The stars section's header symbol.
        public static let icon = "StarsView.icon"
    }

    /// Identifiers applied by ``FITScope/SkyBackgroundView``.
    public enum SkyBackgroundView
    {
        /// The sky-background section's container.
        public static let container = "SkyBackgroundView.container"

        /// The sky-background section's header symbol.
        public static let icon = "SkyBackgroundView.icon"
    }

    /// Identifiers applied by ``FITScope/InfoView`` (the metadata window).
    public enum InfoView
    {
        /// The header-keyword table.
        public static let table = "InfoView.table"

        /// The keyword search field.
        public static let searchField = "InfoView.searchField"

        /// The keyword-count summary shown in the bottom bar.
        public static let keywordCount = "InfoView.keywordCount"

        /// The section picker.
        public static let sectionPicker = "InfoView.sectionPicker"

        /// The button that exports the headers to CSV/TSV.
        public static let exportButton = "InfoView.exportButton"
    }

    /// Identifiers applied by ``FITScope/MainWindowView``.
    public enum MainWindowView
    {
        /// The window-toolbar button that toggles the inspector.
        public static let inspectorToggle = "MainWindowView.inspectorToggle"

        /// The window-toolbar control that shares the rendered image.
        public static let share = "MainWindowView.share"
    }

    /// Identifiers applied by ``FITScope/InspectorPlaceholderView``.
    public enum InspectorPlaceholderView
    {
        /// The placeholder shown in the inspector when a file failed to load or
        /// render.
        public static let view = "InspectorPlaceholderView.view"
    }

    /// Identifiers applied by ``FITScope/AboutView``.
    public enum AboutView
    {
        /// The About window's root content.
        public static let view = "AboutView.view"
    }

    /// Identifiers applied by ``FITScope/PreferencesView``.
    public enum PreferencesView
    {
        /// The General tab's content.
        public static let generalTab = "PreferencesView.generalTab"

        /// The "auto-hide the floating bars" toggle in the General tab.
        public static let autoHideFloatingBarsToggle = "PreferencesView.autoHideFloatingBarsToggle"

        /// The "confirm before moving files to the Trash" toggle in the General tab.
        public static let confirmMoveToTrashToggle = "PreferencesView.confirmMoveToTrashToggle"

        /// The Auto-Stretch tab's content.
        public static let autoStretchTab = "PreferencesView.autoStretchTab"

        /// The "auto-stretch on open" toggle for a format, in the Auto-Stretch tab.
        ///
        /// - Parameter format: The image format.
        /// - Returns: The accessibility identifier.
        public static func autoStretchOnOpenToggle( _ format: AutoStretchPreference.Format ) -> String
        {
            "PreferencesView.autoStretchOnOpenToggle.\( format.rawValue )"
        }

        /// The "auto-stretch previews" toggle for a format, in the Auto-Stretch tab.
        ///
        /// - Parameter format: The image format.
        /// - Returns: The accessibility identifier.
        public static func autoStretchPreviewsToggle( _ format: AutoStretchPreference.Format ) -> String
        {
            "PreferencesView.autoStretchPreviewsToggle.\( format.rawValue )"
        }

        /// The API Keys tab's content.
        public static let apiKeysTab = "PreferencesView.apiKeysTab"

        /// The Astrometry.net API-key secure field in the API Keys tab.
        public static let astrometryNetKeyField = "PreferencesView.astrometryNetKeyField"

        /// The Information Panel tab's content.
        public static let informationPanelTab = "PreferencesView.informationPanelTab"

        /// The reorderable list of information-panel fields in the Information
        /// Panel tab.
        public static let informationPanelFieldList = "PreferencesView.informationPanelFieldList"

        /// The button that restores the information-panel fields to their
        /// defaults in the Information Panel tab.
        public static let informationPanelResetButton = "PreferencesView.informationPanelResetButton"

        /// The Weighting tab's content.
        public static let weightingTab = "PreferencesView.weightingTab"

        /// The image-weight formula editor in the Weighting tab.
        public static let weightFormulaEditor = "PreferencesView.weightFormulaEditor"

        /// The live validation message below the weight-formula editor.
        public static let weightFormulaValidationMessage = "PreferencesView.weightFormulaValidationMessage"

        /// The button that restores the weight formula to its default in the
        /// Weighting tab.
        public static let weightFormulaResetButton = "PreferencesView.weightFormulaResetButton"

        /// The Overlays tab's content.
        public static let overlaysTab = "PreferencesView.overlaysTab"

        /// The button that restores every overlay's appearance to its default in
        /// the Overlays tab.
        public static let overlaysRestoreAllButton = "PreferencesView.overlaysRestoreAllButton"

        /// The colour picker for the overlay with the given identifier, in the
        /// Overlays tab.
        ///
        /// - Parameter overlay: The overlay's identifier.
        /// - Returns: The accessibility identifier.
        public static func overlayColorPicker( _ overlay: String ) -> String
        {
            "PreferencesView.overlayColorPicker.\( overlay )"
        }

        /// The button that restores a single overlay's appearance to its default,
        /// in the Overlays tab.
        ///
        /// - Parameter overlay: The overlay's identifier.
        /// - Returns: The accessibility identifier.
        public static func overlayResetButton( _ overlay: String ) -> String
        {
            "PreferencesView.overlayResetButton.\( overlay )"
        }
    }

    /// Identifiers for the session metric-trend charts window.
    public enum SessionMetricsWindowView
    {
        /// The chart content shown when the window has files to trend.
        public static let chart = "SessionMetricsWindowView.chart"

        /// The integration-time / relative-SNR summary strip.
        public static let summary = "SessionMetricsWindowView.summary"

        /// The reference picker driving the relative-SNR figures.
        public static let referencePicker = "SessionMetricsWindowView.referencePicker"

        /// The cumulative relative-SNR curve.
        public static let snrCurve = "SessionMetricsWindowView.snrCurve"

        /// The metric selector.
        public static let metricPicker = "SessionMetricsWindowView.metricPicker"

        /// The menu selecting which other metrics to overlay on the chart.
        public static let overlaysMenu = "SessionMetricsWindowView.overlaysMenu"

        /// The placeholder shown when no files are open.
        public static let unavailable = "SessionMetricsWindowView.unavailable"
    }
}
