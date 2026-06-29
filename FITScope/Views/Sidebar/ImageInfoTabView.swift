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

import MapKit
import SwiftUI

/// The info-panel tab host shown below the file list: the Image Information grid,
/// the capture Location, the Moon phase and the historical Weather, one per tab.
///
/// It is the shared host for the per-image context views. The Location, Moon and
/// Weather tabs are always offered; each owns its own empty/error state and shows
/// a placeholder when the image lacks the data it needs. The tabs use the same
/// segmented control as the histogram section, and all views are kept laid out
/// together so switching between them never resizes the panel.
public struct ImageInfoTabView: View
{
    /// The tabs the host can show.
    private enum Tab: Hashable
    {
        /// The Image Information grid.
        case info

        /// The capture-location map and coordinates.
        case location

        /// The capture's lunar phase.
        case moon

        /// The capture's historical weather.
        case weather

        /// The segmented-control label for the tab.
        var title: String
        {
            switch self
            {
                case .info:     return "Info"
                case .location: return "Location"
                case .moon:     return "Moon"
                case .weather:  return "Weather"
            }
        }
    }

    /// The file whose information and location are shown.
    @ObservedObject private var file: OpenFile

    /// The selected tab.
    @State private var tab = Tab.info

    /// Creates the tab host.
    ///
    /// - Parameter file: The file to describe.
    public init( file: OpenFile )
    {
        self.file = file
    }

    /// The view's content: a segmented control switching between the Image
    /// Information grid, the Location tab and the Moon tab. The Location and Moon
    /// tabs are always offered; when the image lacks the data they need they show
    /// a placeholder instead.
    public var body: some View
    {
        VStack( spacing: 10 )
        {
            SegmentedControlView( selection: self.$tab, values: [ .info, .location, .moon, .weather ], title: { $0.title }, icon: { self.icon( for: $0 ) } )
                .padding( .horizontal, 14 )
                .padding( .top, 12 )
                .accessibilityIdentifier( AccessibilityIdentifier.ImageInfoTabView.tabs )

            self.tabbedContent
        }
        .accessibilityIdentifier( AccessibilityIdentifier.ImageInfoTabView.container )
    }

    /// The measured natural height of the Image Information content (its ideal
    /// height, button included). Drives the info area's height so it follows the
    /// number of fields rather than the window.
    @State private var infoContentHeight = 0.0

    /// The minimum height of the info area, so the Location map is never tiny.
    private static let minContentHeight = 200.0

    /// The info area's height: the Image Information content's natural height,
    /// floored at ``minContentHeight``. A definite value (not a flexible fill), so
    /// the area grows with the field count yet never stretches with the window.
    private var contentHeight: Double
    {
        max( self.infoContentHeight, Self.minContentHeight )
    }

    /// The switchable content. Both the Image Information grid and the Location tab
    /// are kept in the layout — toggled with opacity rather than added and removed
    /// — and given the same definite ``contentHeight`` so switching never resizes
    /// the panel. A hidden, isolated probe measures the Image Information's natural
    /// height; the visible grid then fills ``contentHeight`` (its spacer dropping
    /// the button to the bottom when there is room), and the map matches it.
    private var tabbedContent: some View
    {
        ZStack
        {
            ImageInfoPanelView( file: self.file )
                .opacity( self.tab == .info ? 1 : 0 )
                .accessibilityHidden( self.tab != .info )

            // LocationMapView and MoonPhaseView own their own empty/error states,
            // so the host just supplies the (optional) data.
            LocationMapView( coordinate: self.coordinate )
                .padding( .horizontal, 14 )
                .padding( .bottom, 14 )
                .opacity( self.tab == .location ? 1 : 0 )
                .allowsHitTesting( self.tab == .location )
                .accessibilityHidden( self.tab != .location )

            MoonPhaseView( date: self.observationDate )
                .padding( .horizontal, 14 )
                .padding( .bottom, 14 )
                .opacity( self.tab == .moon ? 1 : 0 )
                .allowsHitTesting( self.tab == .moon )
                .accessibilityHidden( self.tab != .moon )

            WeatherView( coordinate: self.coordinate, date: self.observationDate, isActive: self.tab == .weather )
                .padding( .horizontal, 14 )
                .padding( .bottom, 14 )
                .opacity( self.tab == .weather ? 1 : 0 )
                .allowsHitTesting( self.tab == .weather )
                .accessibilityHidden( self.tab != .weather )
        }
        .frame( height: self.contentHeight )
        .background( self.heightProbe )
    }

    /// A hidden copy of the Image Information panel, fixed to its natural height
    /// and measured. It sits in the visible area's background so it is laid out at
    /// the same width but never influences the area's size — only reports the
    /// content height into ``infoContentHeight``.
    private var heightProbe: some View
    {
        ImageInfoPanelView( file: self.file )
            .fixedSize( horizontal: false, vertical: true )
            .hidden()
            .onGeometryChange( for: Double.self, of: { $0.size.height }, action: { self.infoContentHeight = $0 } )
    }

    /// The selected image's capture date (`DATE-OBS`), or `nil` when absent.
    private var observationDate: Date?
    {
        self.file.image?.info.metadata.observationDate
    }

    /// The SF Symbol for a tab. The Moon tab uses the current phase shape when the
    /// image carries a date, otherwise a generic moon; the others are fixed.
    ///
    /// - Parameter tab: The tab to icon.
    /// - Returns: The SF Symbol name.
    private func icon( for tab: Tab ) -> String
    {
        switch tab
        {
            case .info:     return "info.circle"
            case .location: return "mappin.and.ellipse"
            case .moon:     return self.observationDate.map { MoonPhase( date: $0 ).phase.systemImageName } ?? "moon"
            case .weather:  return "cloud.sun"
        }
    }

    /// The selected image's capture location as a MapKit coordinate, or `nil`
    /// when its header carries no observing-site coordinates.
    private var coordinate: CLLocationCoordinate2D?
    {
        guard let coordinate = self.file.image?.info.metadata.coordinate
        else
        {
            return nil
        }

        return CLLocationCoordinate2D( latitude: coordinate.latitude, longitude: coordinate.longitude )
    }
}
