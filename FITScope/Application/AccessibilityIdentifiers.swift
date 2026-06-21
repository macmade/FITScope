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
    }

    /// Identifiers applied by ``FITScope/OpenFileRowView``.
    public enum OpenFileRowView
    {
        /// A single row in the files sidebar (shared by every row).
        public static let row = "OpenFileRowView.row"
    }

    /// Identifiers applied by ``FITScope/InspectorView``.
    public enum InspectorView
    {
        /// The inspector column's scrolling content.
        public static let container = "InspectorView.container"

        /// The inspector's "Reset View" button.
        public static let resetButton = "InspectorView.resetButton"

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
        }
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
}
