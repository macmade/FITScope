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

/// The info-panel tab host shown below the file list: the Image Information grid
/// in its first tab, plus a Map tab when the selected image carries observing
/// site coordinates.
///
/// It is the shared host for the per-image context views; further tabs (e.g.
/// moon phase, weather) join here as their data becomes available, each shown
/// only when the image actually carries the information it needs. The tabs use
/// the same segmented control as the histogram section, and both views are kept
/// laid out together so switching between them never resizes the panel.
public struct ImageInfoTabView: View
{
    /// The tabs the host can show.
    private enum Tab: Hashable
    {
        /// The Image Information grid.
        case info

        /// The capture-location map and coordinates.
        case location

        /// The segmented-control label for the tab.
        var title: String
        {
            switch self
            {
                case .info:     return "Info"
                case .location: return "Location"
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
    /// Information grid and the Location tab. The Location tab is always offered;
    /// when the image has no coordinates it shows a placeholder instead of a map.
    public var body: some View
    {
        VStack( spacing: 10 )
        {
            SegmentedControlView( selection: self.$tab, values: [ .info, .location ], title: { $0.title } )
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

            self.locationTab
                .opacity( self.tab == .location ? 1 : 0 )
                .allowsHitTesting( self.tab == .location )
                .accessibilityHidden( self.tab != .location )
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

    /// The Location tab: the map (with the coordinate shown beneath it) when the
    /// image carries coordinates, otherwise a "no location" placeholder. The map
    /// area is framed identically in both cases so switching images doesn't shift
    /// it.
    private var locationTab: some View
    {
        VStack( spacing: 10 )
        {
            Group
            {
                if let coordinate = self.coordinate
                {
                    LocationMapView( coordinate: coordinate )
                }
                else
                {
                    MapStatusView( systemImage: "location.slash", title: "No Location Data", message: "This image has no GPS coordinates." )
                }
            }
            .frame( maxWidth: .infinity, maxHeight: .infinity )
            .clipShape( RoundedRectangle( cornerRadius: 10 ) )
            .overlay( RoundedRectangle( cornerRadius: 10 ).strokeBorder( .white.opacity( 0.08 ), lineWidth: 1 ) )

            if let coordinate = self.coordinate
            {
                LocationInfoView( latitude: coordinate.latitude, longitude: coordinate.longitude )

                Button( "Open in Maps" )
                {
                    self.openInMaps( coordinate )
                }
                .frame( maxWidth: .infinity )
                .accessibilityIdentifier( AccessibilityIdentifier.ImageInfoTabView.openInMapsButton )
            }
        }
        .padding( .horizontal, 14 )
        .padding( .bottom, 14 )
    }

    /// Opens the capture location in the Maps app, dropping a named pin at the
    /// coordinate.
    ///
    /// - Parameter coordinate: The location to show in Maps.
    private func openInMaps( _ coordinate: CLLocationCoordinate2D )
    {
        let mapItem  = MKMapItem( placemark: MKPlacemark( coordinate: coordinate ) )
        mapItem.name = "Capture Location"

        mapItem.openInMaps()
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
