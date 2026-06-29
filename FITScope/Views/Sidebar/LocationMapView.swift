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

/// A MapKit map centred on a single geographic coordinate, with a pin at that
/// point — used to show the capture location of an image whose header carries
/// observing-site coordinates.
///
/// It shows a progress indicator while the map's tiles load and, when they fail
/// to load (most often because the device is offline), an offline fallback that
/// still presents the coordinate in text.
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

    /// The coordinate to centre the map on and mark.
    private let coordinate: CLLocationCoordinate2D

    /// The map's current tile-loading state, driven by the map view's delegate.
    @State private var loadState: LoadState = .loading

    /// Creates the map.
    ///
    /// - Parameter coordinate: The location to centre on and mark.
    public init( coordinate: CLLocationCoordinate2D )
    {
        self.coordinate = coordinate
    }

    /// The view's content.
    public var body: some View
    {
        LocationMapRepresentable( coordinate: self.coordinate, loadState: self.$loadState )
            .overlay
            {
                self.statusOverlay
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

                MapStatusView( systemImage: "wifi.slash", title: "Map Unavailable", message: "Check your internet connection." )

            case .loaded:

                EmptyView()
        }
    }
}

#Preview
{
    LocationMapView( coordinate: CLLocationCoordinate2D( latitude: 46.2, longitude: -6.15 ) )
        .frame( width: 260, height: 200 )
}
