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
    @State private var tapMapPoint: Point?
    
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
        .animation(.default, value: calloutPlacement)
        .task { await model.loadData() }
    }
    
    @ViewBuilder
    func mapView(_ data: Data) -> some View {
        MapViewReader { mapView in
            MapView(map: data.map)
                .onSingleTapGesture { tapLocation, tapMapPoint in
                    self.tapLocation = tapLocation
                    self.tapMapPoint = tapMapPoint
                    clearSelection()
                }
                .callout(placement: $calloutPlacement) { placement in
                    if let feature = placement.geoElement as? Feature {
                        featureCalloutContent(feature: feature, table: data.featureTable)
                    } else if let tapMapPoint {
                        newFeatureCalloutContent(table: data.featureTable, point: tapMapPoint)
                    }
                }
                .overlay(alignment: .top) {
                    overlayContent
                }
                .task(id: tapLocation) {
                    guard let tapLocation, let tapMapPoint else { return }
                    if let identifyResult = try? await mapView.identify(on: data.featureLayer, screenPoint: tapLocation, tolerance: 12),
                       let geoElement = identifyResult.geoElements.first,
                       let feature = geoElement as? Feature {
                        calloutPlacement = .geoElement(geoElement)
                        data.featureLayer.selectFeature(feature)
                    } else {
                        calloutPlacement = .location(tapMapPoint)
                    }
                }
        }
    }
    
    @ViewBuilder
    func newFeatureCalloutContent(table: ServiceFeatureTable, point: Point) -> some View {
        HStack {
            Text("Add New Feature")
            Button {
                clearSelection()
                Task {
                    try await createFeature(table: table, point: point)
                }
            } label: {
                Image(systemName: "plus.circle")
            }
        }
        .padding()
    }
    
    @ViewBuilder
    func featureCalloutContent(feature: Feature, table: ServiceFeatureTable) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("ID: \(feature.id)")
                Text("Damage: \(feature.damageKind?.value ?? "Unknown")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Menu {
                Button {
                    Task {
                        clearSelection()
                        try await updateAttribute(for: feature, table: table)
                    }
                } label: {
                    Text("Update Attribute")
                }
                Button {
                    Task {
                        clearSelection()
                        try await updateGeometry(for: feature, table: table)
                    }
                } label: {
                    Text("Update Geometry")
                }
                Button {
                    Task {
                        clearSelection()
                        try await delete(feature: feature, table: table)
                    }
                } label: {
                    Text("Delete Feature")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .padding(.leading)
            }
        }
        .padding()
    }
    
    @ViewBuilder var overlayContent: some View {
        Text("Tap the map to create a new feature, or an existing feature for more options.")
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
    }
    
    func clearSelection() {
        if case .success(let data) = model.data {
            data.featureLayer.clearSelection()
        }
        calloutPlacement = nil
    }
    
    func createFeature(table: ServiceFeatureTable, point: Point) async throws {
        let feature = table.makeFeature(
            attributes: [
                Feature.damageTypeFieldName: DamageKind.inaccessible.value
            ],
            geometry: point
        )
        try await table.add(feature)
        _ = try await table.serviceGeodatabase?.applyEdits()
    }
    
    func updateAttribute(for feature: Feature, table: ServiceFeatureTable) async throws {
        feature.damageKind = feature.damageKind?.next ?? .inaccessible
        try await table.update(feature)
        _ = try await table.serviceGeodatabase?.applyEdits()
    }
    
    func updateGeometry(for feature: Feature, table: ServiceFeatureTable) async throws {
        // TODO: ...
        try await table.update(feature)
        _ = try await table.serviceGeodatabase?.applyEdits()
    }
    
    func delete(feature: Feature, table: ServiceFeatureTable) async throws {
        try await table.delete(feature)
        _ = try await table.serviceGeodatabase?.applyEdits()
    }
}

extension Feature {
    static let damageTypeFieldName = "typdamage"
    static let objectIDFieldName = "objectid"
    
    var id: String {
        if let objectID = attributeValue(forKey: "objectid") {
            return "\(objectID)"
        } else {
            return "Unknown"
        }
    }
    
    var damageKind: ManageFeaturesView.DamageKind? {
        get {
            ManageFeaturesView.DamageKind(
                attributeValue(forKey: Self.damageTypeFieldName) as? String ?? ""
            )
        } set {
            setAttributeValue(newValue?.value, forKey: Self.damageTypeFieldName)
        }
    }
}

extension ManageFeaturesView {
    struct Data {
        let map: Map
        let geodatabase: ServiceGeodatabase
        let featureTable: ServiceFeatureTable
        let featureLayer: FeatureLayer
    }
    
    enum DamageKind: CaseIterable {
        case inaccessible
        case affected
        case minor
        case major
        case destroyed
        
        init?(_ value: String) {
            for `case` in Self.allCases {
                if value == `case`.value {
                    self = `case`
                    return
                }
            }
            return nil
        }
        
        var value: String {
            switch self {
            case .inaccessible:
                "Inaccessible"
            case .affected:
                "Affected"
            case .minor:
                "Minor"
            case .major:
                "Major"
            case .destroyed:
                "Destroyed"
            }
        }
        
        var next: ManageFeaturesView.DamageKind {
            switch self {
            case .inaccessible:
                .affected
            case .affected:
                .minor
            case .minor:
                .major
            case .major:
                .destroyed
            case .destroyed:
                .inaccessible
            }
        }
    }
}

extension ManageFeaturesView {
    @Observable
    @MainActor
    final class Model {
        var data: Result<Data, Error>?
        
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
