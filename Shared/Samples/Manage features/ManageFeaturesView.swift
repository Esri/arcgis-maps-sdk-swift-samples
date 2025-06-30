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
    /// The data for the view.
    @State private var data: Result<Data, Error>?
    
    /// The screen location that the user tapped.
    @State private var tapLocation: CGPoint?
    
    /// The map location that the user tapped.
    @State private var tapMapPoint: Point?
    
    /// The placement of the callout.
    @State private var calloutPlacement: CalloutPlacement?
    
    /// The current viewpoint of the map view.
    @State private var currentViewpoint: Viewpoint?
    
    /// The result of the latest action.
    @State private var status = ""
    
    /// The height of the attribution bar.
    @State private var attributionHeight: CGFloat = 0
    
    var body: some View {
        VStack {
            switch data {
            case .success(let data):
                // Show map view if data loads.
                mapView(data)
            case .failure:
                // Show content unavailable if data does not load.
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text("Failed to load sample data."))
            case .none:
                // Show progress view during loading.
                ProgressView()
            }
        }
        .animation(.default, value: status)
        .animation(.default, value: calloutPlacement)
        .task { await loadData() }
    }
    
    /// Loads the data for this view.
    private func loadData() async {
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
    
    @ViewBuilder
    func mapView(_ data: Data) -> some View {
        MapViewReader { mapView in
            MapView(map: data.map)
                .onAttributionBarHeightChanged { attributionHeight = $0 }
                .onSingleTapGesture { tapLocation, tapMapPoint in
                    // Store state and clear selection on tap.
                    self.tapLocation = tapLocation
                    self.tapMapPoint = tapMapPoint
                    clearSelection()
                }
                .callout(placement: $calloutPlacement) { placement in
                    if let feature = placement.geoElement as? Feature {
                        featureCalloutContent(feature: feature, table: data.featureTable)
                    } else if let tapMapPoint {
                        addNewFeatureCalloutContent(table: data.featureTable, point: tapMapPoint)
                    }
                }
                .onNavigatingChanged { _ in
                    // Reset status when user moves the map.
                    status = ""
                }
                .onViewpointChanged(kind: .centerAndScale) { viewpoint in
                    // Track current viewpoint.
                    currentViewpoint = viewpoint
                }
                .overlay(alignment: .top) {
                    instructionsOverlay
                }
                .overlay(alignment: .bottom) {
                    statusOverlay
                        .padding(.bottom, attributionHeight)
                }
                .task(id: tapLocation) {
                    // Identify when we get a tap location.
                    guard let tapLocation, let tapMapPoint else { return }
                    if let identifyResult = try? await mapView.identify(on: data.featureLayer, screenPoint: tapLocation, tolerance: 12),
                       let geoElement = identifyResult.geoElements.first,
                       let feature = geoElement as? Feature {
                        // Place a callout for a feature.
                        calloutPlacement = .geoElement(geoElement)
                        data.featureLayer.selectFeature(feature)
                    } else {
                        // Place a callout for adding a new feature.
                        calloutPlacement = .location(tapMapPoint)
                    }
                }
        }
    }
    
    /// A callout that allows the user to add a new feature.
    @ViewBuilder
    func addNewFeatureCalloutContent(table: ServiceFeatureTable, point: Point) -> some View {
        Button("Create Feature", systemImage: "plus.circle") {
            clearSelection()
            Task {
                await createFeature(point: point, table: table)
            }
        }
        .padding()
    }
    
    /// A callout that allows a user to modify or delete an existing feature.
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
                        await updateAttribute(for: feature, table: table)
                    }
                } label: {
                    Text("Update Attribute")
                }
                Button {
                    // Hide callout, leave feature selected.
                    calloutPlacement = nil
                    Task {
                        await updateGeometry(for: feature, table: table)
                        // Update callout location after moving feature.
                        calloutPlacement = .geoElement(feature)
                    }
                } label: {
                    Text("Update Geometry")
                }
                Button {
                    Task {
                        clearSelection()
                        await delete(feature: feature, table: table)
                    }
                } label: {
                    Text("Delete Feature")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .padding(.leading)
            }
            .fixedSize()
        }
        .padding()
    }
    
    /// Overlay with instructions for the user.
    @ViewBuilder var instructionsOverlay: some View {
        Text("Tap the map to create a new feature, or an existing feature for more options.")
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
    }
    
    /// Overlay with latest status.
    @ViewBuilder var statusOverlay: some View {
        if !status.isEmpty {
            Text(status)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
        }
    }
    
    /// Clears the selection on the feature layer, hides the callout, and
    /// resets the status.
    func clearSelection() {
        if case .success(let data) = data {
            data.featureLayer.clearSelection()
        }
        calloutPlacement = nil
        status = ""
    }
    
    /// Creates a new feature at a specified location and applies edits to the service.
    func createFeature(point: Point, table: ServiceFeatureTable) async {
        let feature = table.makeFeature(
            attributes: [
                Feature.damageTypeFieldName: DamageKind.inaccessible.value,
                "primcause": "Earthquake"
            ],
            geometry: point
        )
        do {
            try await table.add(feature)
            _ = try await table.serviceGeodatabase?.applyEdits()
            status = "Create feature succeeded."
        } catch {
            status = "Error creating feature."
        }
    }
    
    /// Updates the attributes of a feature and applies edits to the service.
    func updateAttribute(for feature: Feature, table: ServiceFeatureTable) async {
        do {
            feature.damageKind = feature.damageKind?.next ?? .inaccessible
            try await table.update(feature)
            _ = try await table.serviceGeodatabase?.applyEdits()
            status = "Update attribute succeeded."
        } catch {
            status = "Error updating attribute."
        }
    }
    
    /// Updates the geometry of a feature and applies edits to the service.
    /// This moves the feature to the center of the map.
    func updateGeometry(for feature: Feature, table: ServiceFeatureTable) async {
        guard let currentViewpoint else { return }
        do {
            feature.geometry = currentViewpoint.targetGeometry
            try await table.update(feature)
            _ = try await table.serviceGeodatabase?.applyEdits()
            status = "Update geometry succeeded."
        } catch {
            status = "Error updating geometry."
        }
    }
    
    /// Deletes a feature from the table and applies edits to the service.
    func delete(feature: Feature, table: ServiceFeatureTable) async {
        do {
            try await table.delete(feature)
            _ = try await table.serviceGeodatabase?.applyEdits()
            status = "Delete feature succeeded."
        } catch {
            status = "Error deleting feature."
        }
    }
}

extension Feature {
    /// The name of the damage type field.
    static let damageTypeFieldName = "typdamage"
    
    /// The name of the object ID field.
    static let objectIDFieldName = "objectid"
    
    /// An ID string for the feature.
    var id: String {
        if let objectID = attributeValue(forKey: "objectid") {
            return "\(objectID)"
        } else {
            return "Unknown"
        }
    }
    
    /// The damage assessment of the feature.
    var damageKind: ManageFeaturesView.DamageKind? {
        get {
            // Return the attribute value as a DamageKind.
            ManageFeaturesView.DamageKind(
                attributeValue(forKey: Self.damageTypeFieldName) as? String ?? ""
            )
        } set {
            // Set the attribute value on the feature by converting the
            // DamageKind to a String value.
            setAttributeValue(newValue?.value, forKey: Self.damageTypeFieldName)
        }
    }
}

extension ManageFeaturesView {
    /// Data value for the sample.
    struct Data {
        /// The map that will be displayed.
        let map: Map
        /// The service geodatabase.
        let geodatabase: ServiceGeodatabase
        /// The service feature table.
        let featureTable: ServiceFeatureTable
        /// The feature layer.
        let featureLayer: FeatureLayer
    }
}

extension ManageFeaturesView {
    /// A value that describes the damage assessment value for a feature.
    enum DamageKind: CaseIterable {
        case inaccessible
        case affected
        case minor
        case major
        case destroyed
        
        /// Initializes a DamageKind with a String value.
        init?(_ value: String) {
            for `case` in Self.allCases {
                if value == `case`.value {
                    self = `case`
                    return
                }
            }
            return nil
        }
        
        /// The string value of the damage kind.
        /// This is the value that will be set or get from the feature attributes.
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
        
        /// The next damage kind to set on a feature.
        var next: Self {
            let allCases = Self.allCases
            let index = allCases.firstIndex(of: self)!
            let nextIndex = allCases.index(after: index)
            return allCases[nextIndex == allCases.count ? 0 : nextIndex]
        }
    }
}

#Preview {
    ManageFeaturesView()
}
