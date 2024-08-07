// Copyright 2024 Esri
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

struct IdentifyFeaturesInWMSLayerView: View {
    /// A map with a dark gray base basemap centered on the USA.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISDarkGrayBase)
        let center = Point(x: -95.7129, y: 37.0902, spatialReference: .wgs84)
        map.initialViewpoint = Viewpoint(center: center, scale: 7e7)
        return map
    }()
    
    /// The WMS layer with EPA water info.
    @State private var waterInfoLayer = WMSLayer(url: .epaWaterInfo, layerNames: ["4"])
    
    /// The text of a WMS feature HTML attribute that is shown in the web view.
    @State private var webViewText = ""
    
    /// The tapped screen point.
    @State private var tapScreenPoint: CGPoint?
    
    /// The placement of the callout on the map.
    @State private var calloutPlacement: CalloutPlacement?
    
    /// The string text for the identify layer overlay.
    private let overlayText = "Tap on the map to identify features in the WMS layer."
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    init() {
        map.addOperationalLayer(waterInfoLayer)
    }
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map)
                .callout(placement: $calloutPlacement.animation(.default.speed(2))) { _ in
                    ScrollView(.horizontal) {
                        WebView(htmlString: webViewText)
                            // Set the width so the html is readable.
                            .frame(width: 800, height: 95)
                            // Disable the WebView scrolling.
                            .disabled(true)
                    }
                    .frame(maxWidth: 300)
                    .padding(10)
                }
                .onSingleTapGesture { screenPoint, _ in
                    tapScreenPoint = screenPoint
                }
                .task(id: tapScreenPoint) {
                    do {
                        // Identify on WMS layer using the screen point.
                        guard let screenPoint = tapScreenPoint else {
                            return
                        }
                        calloutPlacement = nil
                        
                        // Identify feature on water info layer.
                        let identifyResult = try await mapViewProxy.identify(
                            on: waterInfoLayer,
                            screenPoint: screenPoint,
                            tolerance: 2
                        )
                        // Convert the result to text.
                        if let feature = identifyResult.geoElements.first,
                           let htmlText = feature.attributes["HTML"] as? String,
                           // Display the HTML table if it has an OBJECTID column.
                           htmlText.contains("OBJECTID"),
                           let location = mapViewProxy.location(fromScreenPoint: screenPoint) {
                            webViewText = htmlText
                            calloutPlacement = .location(location)
                        }
                    } catch {
                        self.error = error
                    }
                }
                .overlay(alignment: .top) {
                    Text(overlayText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(8)
                        .multilineTextAlignment(.center)
                        .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
                }
        }
        .errorAlert(presentingError: $error)
    }
}

private extension URL {
    /// A URL to the WMS service showing EPA water info.
    static var epaWaterInfo: URL {
        URL(string: "https://watersgeo.epa.gov/arcgis/services/OWPROGRAM/SDWIS_WMERC/MapServer/WMSServer?request=GetCapabilities&service=WMS")!
    }
}

#Preview {
    IdentifyFeaturesInWMSLayerView()
}
