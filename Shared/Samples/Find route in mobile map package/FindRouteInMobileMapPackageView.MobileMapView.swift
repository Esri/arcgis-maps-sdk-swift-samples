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

extension FindRouteInMobileMapPackageView {
    /// The map view for a mobile map package map.
    struct MobileMapView: View {
        /// The view model for the view.
        @StateObject private var model: Model
        
        /// The placement of the address callout on the map.
        @State private var calloutPlacement: CalloutPlacement?
        
        /// The text address shown in the callout.
        @State private var calloutText: String = ""
        
        /// The point on the map where the user tapped.
        @State private var tapLocation: Point?
        
        /// A Boolean value indicating whether the reset button is disabled.
        @State private var resetDisabled = true
        
        /// A Boolean value indicating whether the error alert is showing.
        @State private var errorAlertIsShowing = false
        
        /// The error shown in the error alert.
        @State private var error: Error? {
            didSet { errorAlertIsShowing = error != nil }
        }
        
        init(map: Map, locatorTask: LocatorTask) {
            let model = Model(map: map, locatorTask: locatorTask)
            _model = StateObject(wrappedValue: model)
        }
        
        var body: some View {
            MapView(map: model.map, graphicsOverlays: model.graphicsOverlays)
                .callout(placement: $calloutPlacement) { _ in
                    Text(calloutText)
                        .font(.callout)
                        .padding(8)
                }
                .onSingleTapGesture { _, mapPoint in
                    tapLocation = mapPoint
                }
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Spacer()
                        Button("Reset") {
                            resetGraphics()
                        }
                        .disabled(resetDisabled)
                    }
                }
                .task {
                    // Load the default route parameters from the route task when the sample loads.
                    do {
                        model.routeParameters = try await model.routeTask?.makeDefaultParameters()
                    } catch {
                        self.error = error
                    }
                }
                .task(id: tapLocation) {
                    guard let tapLocation else { return }
                    await handleTapLocation(tapLocation)
                    self.tapLocation = nil
                }
                .alert(isPresented: $errorAlertIsShowing, presentingError: error)
        }
        
        /// Adds a marker or route stop with a callout at a given tap location.
        /// - Parameter tapLocation: The point on the map where the user tapped.
        private func handleTapLocation(_ tapLocation: Point) async {
            // Normalize the tap location.
            guard let point = GeometryEngine.normalizeCentralMeridian(of: tapLocation) as? Point
            else { return }
            
            // Update the callout's text with address from a reverse geocode.
            do {
                calloutText = try await model.reverseGeocode(point: point)
            } catch {
                self.error = error
                calloutText = "No address found"
            }
            
            // Add a route stop if the map has routing. Otherwise, update the marker.
            if model.routeTask != nil {
                do {
                    try await model.addRouteStop(at: point)
                } catch {
                    self.error = error
                }
            } else {
                model.updateMarker(to: point)
            }
            
            // Update the callout placement with the graphic placed.
            guard let lastMarker = model.lastMarker else { return }
            calloutPlacement = .geoElement(lastMarker, tapLocation: point)
            
            resetDisabled = false
        }
        
        /// Resets the graphics on the map view.
        private func resetGraphics() {
            // Reset the view properties.
            calloutPlacement = nil
            resetDisabled = true
            
            // Reset the graphics.
            if model.routeTask != nil {
                model.markerGraphicsOverlay.removeAllGraphics()
                model.routeGraphicsOverlay?.removeAllGraphics()
            } else {
                model.lastMarker?.geometry = nil
            }
        }
    }
}
