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

struct FindAddressWithReverseGeocodeView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The point on the map where the user tapped.
    @State private var tapLocation: Point?
    
    /// The placement of the callout on the map.
    @State private var calloutPlacement: CalloutPlacement?
    
    /// The text shown in the callout.
    @State private var calloutText: String?
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
            .callout(placement: $calloutPlacement.animation(.default.speed(2))) { _ in
                Text(calloutText ?? "No address found.")
                    .font(.callout)
                    .padding(8)
            }
            .onSingleTapGesture { _, mapPoint in
                tapLocation = mapPoint
            }
            .task(id: tapLocation) {
                guard let tapLocation else { return }
                await reverseGeocode(tapLocation)
            }
            .task {
                do {
                    try await model.locatorTask.load()
                } catch {
                    self.error = error
                }
            }
            .overlay(alignment: .top) {
                Text("Tap on the map to get the address for point.")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
            }
            .errorAlert(presentingError: $error)
    }
    
    /// Reverse geocodes a given point and updates the marker with the result.
    /// - Parameter mapPoint: The point on the map to reverse geocode.
    private func reverseGeocode(_ mapPoint: Point) async {
        //  Normalize the map point.
        guard let normalizedPoint = GeometryEngine.normalizeCentralMeridian(
            of: mapPoint
        ) as? Point else { return }
        
        do {
            // Perform reverse geocode using the locator task with the point and parameters.
            let geocodeResults = try await model.locatorTask.reverseGeocode(
                forLocation: normalizedPoint,
                parameters: model.reverseGeocodeParameters
            )
            
            // Update the callout text using the first result from the reverse geocode.
            updateCalloutText(using: geocodeResults.first)
        } catch {
            self.error = error
            calloutText = nil
        }
        
        // Update the marker and callout location.
        model.markerGraphic.geometry = normalizedPoint
        calloutPlacement = .geoElement(model.markerGraphic, tapLocation: normalizedPoint)
    }
    
    /// Updates the callout text using the address from a given geocode result.
    /// - Parameter geocodeResult: The result to get the address from.
    private func updateCalloutText(using geocodeResult: GeocodeResult?) {
        // Get the address from the result's attributes.
        let addressText = model.reverseGeocodeParameters.resultAttributeNames
            .compactMap { geocodeResult?.attributes[$0] as? String }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        
        // Update the callout text if an address was found.
        calloutText = !addressText.isEmpty ? addressText : nil
    }
}

private extension FindAddressWithReverseGeocodeView {
    /// The model used to store the geo model and other expensive objects used in this view.
    class Model: ObservableObject {
        /// A map with a topographic basemap initially centered on Redlands, CA, USA.
        let map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            map.initialViewpoint = Viewpoint(
                center: Point(x: -117.195, y: 34.058, spatialReference: .wgs84),
                scale: 5e4
            )
            return map
        }()
        
        /// The graphics overlay for the marker graphic.
        let graphicsOverlay = GraphicsOverlay()
        
        /// The red map marker graphic used to indicate a tap location on the map.
        let markerGraphic = {
            // Create a symbol using the image from the project assets.
            guard let markerImage = UIImage(named: "RedMarker") else { return Graphic() }
            let markerSymbol = PictureMarkerSymbol(image: markerImage)
            
            // Change the symbol's offsets, so it aligns properly to a given point.
            markerSymbol.leaderOffsetY = markerImage.size.height / 2
            markerSymbol.offsetY = markerImage.size.height / 2
            
            // Create a graphic with the symbol.
            return Graphic(symbol: markerSymbol)
        }()
        
        /// The locator task for reverse geocoding.
        let locatorTask = LocatorTask(url: .geocodeServer)
        
        /// The parameters for the reverse geocode operation.
        let reverseGeocodeParameters = {
            let parameters = ReverseGeocodeParameters()
            parameters.addResultAttributeNames(["Address", "City", "RegionAbbr"])
            parameters.maxResults = 1
            return parameters
        }()
        
        init() {
            graphicsOverlay.addGraphic(markerGraphic)
        }
    }
}

private extension URL {
    /// A URL to a geocode server on ArcGIS Online.
    static var geocodeServer: URL {
        URL(string: "https://geocode-api.arcgis.com/arcgis/rest/services/World/GeocodeServer")!
    }
}

#Preview {
    FindAddressWithReverseGeocodeView()
}
