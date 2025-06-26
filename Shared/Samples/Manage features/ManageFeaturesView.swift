// Copyright 2025 Esri
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

struct ManageFeaturesView: View {
    /// A map with a streets basemap and a feature layer.
    @State private var model = Model()
    
    @State private var tapLocation: CGPoint?
    
    @State private var calloutPlacement: CalloutPlacement?
    
    var body: some View {
        VStack {
            switch model.data {
            case .success(let data):
                mapView(data)
            case .failure:
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text("Failed to load sample data."))
            case .none:
                ProgressView()
            }
        }
        .animation(.default, value: model.action)
        .animation(.default, value: calloutPlacement)
        .task { await model.loadData() }
    }
    
    @ViewBuilder
    func mapView(_ data: Data) -> some View {
        MapViewReader { mapView in
            MapView(map: data.map)
                .onSingleTapGesture { tapLocation, _ in
                    self.tapLocation = tapLocation
                    data.featureLayer.clearSelection()
                    calloutPlacement = nil
                }
                .callout(placement: $calloutPlacement) { placement in
                    Group {
                        if let geoElement = placement.geoElement {
                            Text("element!")
                        } else {
                            HStack {
                                Text("Add new feature here")
                                Button {
                                    createFeature()
                                } label: {
                                    Image(systemName: "plus.circle")
                                }
                            }
                        }
                    }
                    .padding()
                }
                .overlay(alignment: .top) {
                    overlayContent
                }
                .task(id: tapLocation) {
                    guard let tapLocation else { return }
                    if let identifyResult = try? await mapView.identify(on: data.featureLayer, screenPoint: tapLocation, tolerance: 12),
                       let geoElement = identifyResult.geoElements.first,
                       let feature = geoElement as? Feature {
                        print("-- result: \(geoElement)")
                        calloutPlacement = .geoElement(geoElement)
                        data.featureLayer.selectFeature(feature)
                    } else if let mapPoint = mapView.location(fromScreenPoint: tapLocation) {
                        calloutPlacement = .location(mapPoint)
                    }
                }
        }
    }
    
    @ViewBuilder var overlayContent: some View {
        VStack {
            Text("Tap the map to create a new feature, or an existing feature for more options.")
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
    
    func createFeature() {
    }
}

extension ManageFeaturesView {
    struct Data {
        let map: Map
        let geodatabase: ServiceGeodatabase
        let featureTable: ServiceFeatureTable
        let featureLayer: FeatureLayer
    }
    
    enum Action: CaseIterable {
        case create
        case delete
        case updateAttribute
        case updateGeometry
        
        var label: String {
            switch self {
            case .create:
                "Create Feature"
            case .delete:
                "Delete Feature"
            case .updateAttribute:
                "Update Attribute"
            case .updateGeometry:
                "Update Geometry"
            }
        }
        
        var instructions: String {
            switch self {
            case .create:
                "Tap the map to create a new feature."
            case .delete:
                "Tap on a feature to delete it."
            case .updateAttribute:
                "Tap something to update..."
            case .updateGeometry:
                "Tap something to update geometry..."
            }
        }
    }
}

extension ManageFeaturesView {
    @Observable
    @MainActor
    final class Model {
        var data: Result<Data, Error>?
        var action: Action = .create
        
        func loadData() async {
            let map = Map(basemapStyle: .arcGISStreets)
            map.initialViewpoint = Viewpoint(
                center: Point(x: -10_800_000, y: 4_500_000, spatialReference: .webMercator),
                scale: 3e7
            )
            
            let geodatabase = ServiceGeodatabase(
                url: URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/DamageAssessment/FeatureServer/0")!
            )
            
            do {
                try await geodatabase.load()
                let featureTable = geodatabase.table(withLayerID: 0)!
                let layer = FeatureLayer(featureTable: featureTable)
                map.addOperationalLayer(layer)
                data = .success(
                    Data(map: map, geodatabase: geodatabase, featureTable: featureTable, featureLayer: layer)
                )
            } catch {
                data = .failure(error)
            }
        }
    }
}

#Preview {
    ManageFeaturesView()
}
