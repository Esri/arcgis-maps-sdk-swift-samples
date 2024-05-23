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
    @State private var waterInfoLayer: WMSLayer?
    
    /// The text of a WMS placemark's balloon content that is shown in the callout.
    @State private var calloutText = String()

    /// The tapped screen point.
    @State var tapScreenPoint: CGPoint?
    
    /// The string text for the identify layer results overlay.
    @State var overlayText = "Tap on the map to identify features in the WMS layer."

    /// The error shown in the error alert.
    @State private var error: Error?

    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: map)
                .onSingleTapGesture { screenPoint, _ in
                    tapScreenPoint = screenPoint
                }
                .task {
                    do {
                        // Create a WMS layer from URL and load it.
                        let wmsLayer = WMSLayer(url: .EPAWaterInfo, layerNames: ["4"])
                        try await wmsLayer.load()
                        
                        // Add the layer to the map.
                        map.addOperationalLayer(wmsLayer)
                        
                        waterInfoLayer = wmsLayer
                    } catch {
                        self.error = error
                    }
                }
                .task(id: tapScreenPoint) {
                    // Identify on WMS layer using the screen point.
                    if let screenPoint = tapScreenPoint,
                       let waterInfoLayer,
                       let identifyResult = try? await mapViewProxy.identify(
                        on: waterInfoLayer,
                        screenPoint: screenPoint,
                        tolerance: 2
                       ) {
                        do {
                            try updateCalloutText(using: identifyResult)
                        } catch {
                            self.error = error
                        }
                    }
                }
                .overlay(alignment: .top) {
                    VStack {
                        Text(overlayText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top)
                        ScrollView(.horizontal) {
                            WebView(htmlString: calloutText)
                                // Set the width so the html is readable.
                                .frame(width: 800, height: calloutText.isEmpty ? 0 : 95)
                        }
                        .padding(.leading)
                        .padding(.trailing)
                        .padding(.bottom, calloutText.isEmpty ? 0 : 10)
                    }
                    .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
                }
        }
        .errorAlert(presentingError: $error)
    }
}

private extension IdentifyFeaturesInWMSLayerView {
    /// Updates the callout text using the HTML attribute of the feature.
    /// - Parameter result: The identify result.
    func updateCalloutText(using result: IdentifyLayerResult) throws {
        // Convert the result to text.
        calloutText = if let feature = result.geoElements.first,
                         let htmlText = feature.attributes["HTML"] as? String,
                         htmlText.contains("OBJECTID") {
            htmlText
        } else {
            String()
        }
    }
}

private extension URL {
    /// A URL to the WMS service showing EPA water info.
    static var EPAWaterInfo: URL {
        URL(string: "https://watersgeo.epa.gov/arcgis/services/OWPROGRAM/SDWIS_WMERC/MapServer/WMSServer?request=GetCapabilities&service=WMS")!
    }
}

#Preview {
    IdentifyFeaturesInWMSLayerView()
}
