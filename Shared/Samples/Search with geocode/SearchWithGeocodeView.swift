// Copyright 2022 Esri
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI
import ArcGIS
import ArcGISToolkit

struct SearchWithGeocodeView: View {
    /// A map with imagery basemap.
    @StateObject private var map = Map(basemapStyle: .arcGISImagery)
    
    /// The viewpoint used by the `SearchView` to pan/zoom the map to the extent
    /// of the search results.
    @State private var searchResultViewpoint: Viewpoint? = Viewpoint(
        center: Point(
            x: -93.258133,
            y: 44.986656,
            spatialReference: .wgs84
        ),
        scale: 1e6
    )
    
    /// Denotes whether the geoview is navigating. Used for the repeat search
    /// behavior.
    @State private var isGeoViewNavigating = false
    
    /// The current map view extent. Used to allow repeat searches after
    /// panning/zooming the map.
    @State private var geoViewExtent: Envelope?
    
    /// The center for the search.
    @State private var queryCenter: Point?
    
    /// The screen point to perform an identify operation.
    @State private var identifyScreenPoint: CGPoint?
    
    /// The tap location to perform an identify operation.
    @State private var identifyTapLocation: Point?
    
    /// The placement for a graphic callout.
    @State private var calloutPlacement: GraphicCalloutPlacement?
    
    /// Provides search behavior customization.
    private let locatorDataSource = LocatorSearchSource(
        name: "My Locator",
        maximumResults: 10,
        maximumSuggestions: 5
    )
    
    /// The graphics overlay used by the `SearchView` toolkit component to
    /// display search results on the map.
    private let searchResultsOverlay = GraphicsOverlay()
    
    var body: some View {
        MapViewReader { proxy in
            MapView(
                map: map,
                viewpoint: searchResultViewpoint,
                graphicsOverlays: [searchResultsOverlay]
            )
            .onSingleTapGesture { screenPoint, tapLocation in
                identifyScreenPoint = screenPoint
                identifyTapLocation = tapLocation
            }
            .onNavigatingChanged { isGeoViewNavigating = $0 }
            .onViewpointChanged(kind: .centerAndScale) {
                queryCenter = $0.targetGeometry.extent.center
            }
            .onVisibleAreaChanged { newValue in
                // For "Repeat Search Here" behavior, use `geoViewExtent` and
                // `isGeoViewNavigating` modifiers on the `SearchView`.
                geoViewExtent = newValue.extent
            }
            .callout(placement: $calloutPlacement.animation()) { placement in
                // Show the address of user tapped location graphic.
                // To get the full geocoded address, use "Place_addr".
                Text(placement.graphic.attributes["Match_addr"] as? String ?? "")
                    .font(.body)
                    .padding()
            }
            .task(id: identifyScreenPoint) {
                guard let screenPoint = identifyScreenPoint,
                      // Identifies when user taps a graphic.
                      let identifyResult = try? await proxy.identify(
                        graphicsOverlay: searchResultsOverlay,
                        screenPoint: screenPoint,
                        tolerance: 10
                      )
                else {
                    return
                }
                // Creates a callout placement at the user tapped location.
                calloutPlacement = identifyResult.graphics.first.flatMap { graphic in
                    GraphicCalloutPlacement(graphic: graphic, tapLocation: identifyTapLocation)
                }
                self.identifyScreenPoint = nil
                self.identifyTapLocation = nil
            }
            .overlay {
                SearchView(
                    sources: [locatorDataSource],
                    viewpoint: $searchResultViewpoint
                )
                .resultsOverlay(searchResultsOverlay)
                .queryCenter($queryCenter)
                .geoViewExtent($geoViewExtent)
                .isGeoViewNavigating($isGeoViewNavigating)
                .padding()
            }
        }
    }
}
