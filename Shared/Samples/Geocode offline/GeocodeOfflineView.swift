// Copyright 2023 Esri
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

import ArcGIS
import SwiftUI

struct GeocodeOfflineView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The viewpoint of the map view, initially centered on San Diego, CA, USA.
    @State private var viewpoint = Viewpoint(
        center: Point(x: -13_042_250, y: 3_857_970, spatialReference: .webMercator),
        scale: 2e4
    )
    
    /// The text in the search bar.
    @State private var searchText = ""
    
    /// The search text that has been submitted.
    @State private var submittedSearchText: String?
    
    /// A Boolean value indicating whether the "No results found." alert is showing.
    @State private var resultAlertIsShowing = false
    
    /// A pre-populated list of example addresses.
    private let exampleAddresses = [
        "910 N Harbor Dr, San Diego, CA 92101",
        "2920 Zoo Dr, San Diego, CA 92101",
        "111 W Harbor Dr, San Diego, CA 92101",
        "868 4th Ave, San Diego, CA 92101",
        "750 A St, San Diego, CA 92101"
    ]
    
    var body: some View {
        GeocodeMapView(model: model, viewpoint: $viewpoint)
            .searchable(text: $searchText, prompt: "Type in an address")
            .onSubmit(of: .search) {
                submittedSearchText = searchText
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(exampleAddresses, id: \.self) { address in
                            Button(address) {
                                searchText = address
                                submittedSearchText = address
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.down.circle")
                    }
                }
            }
            .onChange(of: searchText) { _ in
                // Reset the marker when the search text changes.
                model.resetGraphics()
            }
            .task(id: submittedSearchText) {
                // Geocode the text when a search is submitted.
                if let submittedSearchText {
                    if let resultExtent = await model.geocodeSearch(address: submittedSearchText) {
                        // If found, zoom to the extent of the result's location.
                        viewpoint = Viewpoint(boundingGeometry: resultExtent)
                    } else {
                        // If no result was found, inform the user with an alert.
                        resultAlertIsShowing = true
                    }
                }
                
                submittedSearchText = nil
            }
            .alert("No results found.", isPresented: $resultAlertIsShowing, actions: {})
    }
}

private extension GeocodeOfflineView {
    /// The map view for the sample.
    struct GeocodeMapView: View {
        /// The view model for the sample.
        @ObservedObject var model: Model
        
        /// The action that ends the current search interaction.
        @Environment(\.dismissSearch) private var dismissSearch
        
        /// The current viewpoint of the map view.
        @Binding var viewpoint: Viewpoint
        
        /// The point on the map where the user tapped.
        @State private var tapLocation: Point?
        
        var body: some View {
            MapView(map: model.map, viewpoint: viewpoint, graphicsOverlays: [model.graphicsOverlay])
                .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
                .callout(placement: $model.calloutPlacement) { _ in
                    Text(model.calloutText)
                        .font(.callout)
                        .padding(8)
                }
                .onSingleTapGesture { _, mapPoint in
                    tapLocation = mapPoint
                }
                .onLongPressAndDragGesture { mapPoint in
                    model.calloutIsOffset = true
                    tapLocation = mapPoint
                } onEnded: {
                    // Reset the callout's offset when the gesture ends.
                    if let tapLocation {
                        model.calloutIsOffset = false
                        model.updateCalloutPlacement(to: tapLocation)
                    }
                    tapLocation = nil
                }
                .task(id: tapLocation) {
                    // Reverse geocode the tap location when it changes.
                    if let tapLocation {
                        dismissSearch()
                        await model.reverseGeocode(mapPoint: tapLocation)
                    }
                }
        }
    }
}

private extension MapView {
    /// Sets a closure to perform when the map view recognizes a long press and drag gesture.
    /// - Parameters:
    ///   - action: The closure to perform when the gesture is recognized.
    ///   - onEnded: The closure to perform when the gesture ends.
    /// - Returns: A new `View` object.
    func onLongPressAndDragGesture(
        perform action: @escaping (Point) -> Void,
        onEnded: @escaping () -> Void
    ) -> some View {
        self
            .onLongPressGesture { _, mapPoint in
                action(mapPoint)
            }
            .gesture(
                LongPressGesture()
                    .simultaneously(with: DragGesture())
                    .onEnded { _ in
                        onEnded()
                    }
            )
    }
}
