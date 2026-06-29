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

/// The Location tab's content: a MapKit map centred on the capture coordinate
/// with a pin, the coordinate as info-panel rows, and an "Open in Maps" button —
/// or, when the image carries no coordinates, a "No Location Data" placeholder.
///
/// It owns all of its states: the loading indicator while the map's tiles load,
/// a "Map Unavailable" message when they fail (most often because the device is
/// offline), and the no-coordinate placeholder — so its host doesn't branch on
/// the data.
public struct LocationMapView: View
{
    /// The tile-loading state of the underlying map view.
    public enum LoadState: Sendable
    {
        /// Tiles are still loading.
        case loading

        /// Tiles finished loading.
        case loaded

        /// Tiles failed to load — most commonly, the device is offline.
        case failed
    }

    /// The coordinate to centre the map on and mark, or `nil` when the image has
    /// no observing-site coordinates.
    private let coordinate: CLLocationCoordinate2D?

    /// The map's current tile-loading state, driven by the map view's delegate.
    @State private var loadState: LoadState = .loading

    /// Creates the location view.
    ///
    /// - Parameter coordinate: The capture location, or `nil` when unknown.
    public init( coordinate: CLLocationCoordinate2D? )
    {
        self.coordinate = coordinate
    }

    /// The view's content: the map with its coordinate rows when a location is
    /// known, otherwise a placeholder.
    public var body: some View
    {
        if let coordinate = self.coordinate
        {
            self.content( coordinate: coordinate )
        }
        else
        {
            StatusMessageView( systemImage: "location.slash", title: "No Location Data", message: "This image has no GPS coordinates." )
                .clipShape( RoundedRectangle( cornerRadius: 10 ) )
                .overlay( Self.cardBorder )
        }
    }

    /// The map card, the coordinate rows and the "Open in Maps" button for a known
    /// location.
    ///
    /// - Parameter coordinate: The capture location.
    private func content( coordinate: CLLocationCoordinate2D ) -> some View
    {
        VStack( spacing: 10 )
        {
            LocationMapRepresentable( coordinate: coordinate, loadState: self.$loadState )
                .overlay( self.statusOverlay )
                .frame( maxWidth: .infinity, maxHeight: .infinity )
                .clipShape( RoundedRectangle( cornerRadius: 10 ) )
                .overlay( Self.cardBorder )

            LocationInfoView( latitude: coordinate.latitude, longitude: coordinate.longitude )

            Button( "Open in Maps" )
            {
                self.openInMaps( coordinate )
            }
            .frame( maxWidth: .infinity )
            .accessibilityIdentifier( AccessibilityIdentifier.LocationMapView.openInMapsButton )
        }
    }

    /// The overlay shown over the map: a progress indicator while loading and a
    /// message when loading fails (an error or no connection); nothing once the
    /// tiles are loaded. The coordinate itself is shown below the map by
    /// ``LocationInfoView``, so it is not repeated here.
    @ViewBuilder     private var statusOverlay: some View
    {
        switch self.loadState
        {
            case .loading:

                ProgressView()
                    .controlSize( .small )
                    .padding( 10 )
                    .background( .regularMaterial, in: RoundedRectangle( cornerRadius: 8 ) )

            case .failed:

                StatusMessageView( systemImage: "wifi.slash", title: "Map Unavailable", message: "Check your internet connection." )

            case .loaded:

                EmptyView()
        }
    }

    /// The hairline border drawn around the map / placeholder card.
    private static var cardBorder: some View
    {
        RoundedRectangle( cornerRadius: 10 ).strokeBorder( .white.opacity( 0.08 ), lineWidth: 1 )
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
}

#Preview
{
    LocationMapView( coordinate: CLLocationCoordinate2D( latitude: 46.2, longitude: -6.15 ) )
        .frame( width: 260, height: 320 )
}
