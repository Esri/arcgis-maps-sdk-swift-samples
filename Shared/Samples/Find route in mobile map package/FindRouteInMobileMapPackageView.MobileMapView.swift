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
        
        /// The point on the screen where the user tapped.
        @State private var tapScreenPoint: CGPoint?
        
        /// A Boolean value indicating whether the reset button is disabled.
        @State private var resetDisabled = true
        
        /// The error shown in the error alert.
        @State private var error: Error?
        
        init(map: Map, locatorTask: LocatorTask) {
            let model = Model(map: map, locatorTask: locatorTask)
            _model = StateObject(wrappedValue: model)
        }
        
        var body: some View {
            MapViewReader { mapViewProxy in
                MapView(map: model.map, graphicsOverlays: model.graphicsOverlays)
                    .callout(placement: $calloutPlacement) { _ in
                        Text(calloutText)
                            .font(.callout)
                            .padding(8)
                    }
                    .onSingleTapGesture { screenPoint, _ in
                        tapScreenPoint = screenPoint
                    }
                    .task(id: tapScreenPoint) {
                        guard let tapScreenPoint else { return }
                        
                        do {
                            // Check to see if the tap was on a marker.
                            let identifyResult = try await mapViewProxy.identify(
                                on: model.markerGraphicsOverlay,
                                screenPoint: tapScreenPoint,
                                tolerance: 12
                            )
                            
                            if let graphic = identifyResult.graphics.first,
                               let graphicPoint = graphic.geometry as? Point {
                                // Update the callout to the identified marker.
                                await updateCallout(point: graphicPoint, graphic: graphic)
                            } else {
                                // Add a graphic at the tapped map point.
                                guard let location = mapViewProxy.location(
                                    fromScreenPoint: tapScreenPoint
                                ) else { return }
                                await addGraphic(at: location)
                            }
                        } catch {
                            self.error = error
                        }
                    }
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
                // Load the route parameters sample loads.
                do {
                    try await model.loadRouteParameters()
                } catch {
                    self.error = error
                }
            }
            .errorAlert(presentingError: $error)
        }
        
        /// Updates the placement and text of the callout using a given point and graphic.
        /// - Parameters:
        ///   - point: The point to reverse geocode and set the callout placement to.
        ///   - graphic: The graphic at the point.
        private func updateCallout(point: Point, graphic: Graphic) async {
            // Update the callout text with the address from a reverse geocode.
            do {
                calloutText = try await model.reverseGeocode(point: point)
            } catch {
                self.error = error
                calloutText = "No address found"
            }
            
            // Update the callout placement with the graphic and point.
            calloutPlacement = .geoElement(graphic, tapLocation: point)
        }
        
        /// Adds a marker or route stop with a callout at a given point.
        /// - Parameter point: The point to add the graphic at.
        private func addGraphic(at point: Point) async {
            // Normalize the tap location.
            guard let point = GeometryEngine.normalizeCentralMeridian(of: point) as? Point else { return }
            
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
            
            // Update the callout with the last marker.
            guard let lastMarker = model.lastMarker else { return }
            await updateCallout(point: point, graphic: lastMarker)
            
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
