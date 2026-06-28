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
    }

    /// Identifiers applied by ``FITScope/OpenFileRowView``.
    public enum OpenFileRowView
    {
        /// A single row in the files sidebar (shared by every row).
        public static let row = "OpenFileRowView.row"

        /// The per-row pill showing the image's computed weight.
        public static let weightPill = "OpenFileRowView.weightPill"
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

            /// The gamma section.
            public static let gamma = "InspectorView.Section.gamma"

            /// The white-balance section.
            public static let whiteBalance = "InspectorView.Section.whiteBalance"

            /// The debayer section.
            public static let debayer = "InspectorView.Section.debayer"

            /// The color section.
            public static let color = "InspectorView.Section.color"

            /// The brightness & contrast section.
            public static let brightnessContrast = "InspectorView.Section.brightnessContrast"

            /// The saturation section (colour images only).
            public static let saturation = "InspectorView.Section.saturation"

            /// The levels section (holds the button opening the Levels editor).
            public static let levels = "InspectorView.Section.levels"

            /// The curves section (holds the button opening the Curves editor).
            public static let curves = "InspectorView.Section.curves"

            /// The orientation (rotate / flip) section.
            public static let orientation = "InspectorView.Section.orientation"
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

        /// The button that resets the levels to their defaults.
        public static let resetButton = "LevelsWindowView.resetButton"
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
    }

    /// Identifiers applied by ``FITScope/SaturationControlView``.
    public enum SaturationControlView
    {
        /// The saturation slider.
        public static let slider = "SaturationControlView.slider"
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

        /// The logarithmic-intensity slider (shown only in logarithmic mode).
        public static let intensitySlider = "StretchControlView.intensitySlider"

        /// The arcsinh-factor slider (shown only in arcsinh mode).
        public static let factorSlider = "StretchControlView.factorSlider"

        /// The sigmoid-midpoint slider (shown only in sigmoid mode).
        public static let midpointSlider = "StretchControlView.midpointSlider"

        /// The sigmoid-contrast slider (shown only in sigmoid mode).
        public static let contrastSlider = "StretchControlView.contrastSlider"
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

    /// Identifiers applied by ``FITScope/GammaCorrectionControlView``.
    public enum GammaCorrectionControlView
    {
        /// The gamma-correction enable toggle.
        public static let toggle = "GammaCorrectionControlView.toggle"

        /// The gamma-exponent slider, shown only while correction is enabled.
        public static let slider = "GammaCorrectionControlView.slider"
    }

    /// Identifiers applied by ``FITScope/ImageInfoPanelView``.
    public enum ImageInfoPanelView
    {
        /// The button that opens the full FITS headers window.
        public static let viewHeadersButton = "ImageInfoPanelView.viewHeadersButton"
    }

    /// Identifiers applied by ``FITScope/InfoView`` (the FITS headers window).
    public enum InfoView
    {
        /// The header-keyword table.
        public static let table = "InfoView.table"

        /// The keyword search field.
        public static let searchField = "InfoView.searchField"

        /// The section picker.
        public static let sectionPicker = "InfoView.sectionPicker"
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

        /// The API Keys tab's content.
        public static let apiKeysTab = "PreferencesView.apiKeysTab"

        /// The Astrometry.net API-key secure field in the API Keys tab.
        public static let astrometryNetKeyField = "PreferencesView.astrometryNetKeyField"

        /// The OpenWeatherMap API-key secure field in the API Keys tab.
        public static let openWeatherMapKeyField = "PreferencesView.openWeatherMapKeyField"

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
    }
}
