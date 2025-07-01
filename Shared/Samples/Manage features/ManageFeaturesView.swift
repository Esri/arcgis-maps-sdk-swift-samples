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
    /// The model for this view.
    @State private var model = Model()
    
    /// The screen location that the user tapped.
    @State private var tapLocation: CGPoint?
    
    /// The map location that the user tapped.
    @State private var tapMapPoint: Point?
    
    /// The placement of the callout.
    @State private var calloutPlacement: CalloutPlacement?
    
    /// The current viewpoint of the map view.
    @State private var currentViewpoint: Viewpoint?
    
    var body: some View {
        Group {
            if model.isLoading {
                // Show progress view during loading.
                ProgressView()
            } else if let map = model.map, let table = model.featureTable, let layer = model.featureLayer {
                mapView(map, featureTable: table, featureLayer: layer)
            } else if let error = model.error {
                // Show content unavailable if data does not load.
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Failed to load sample data.")
                )
            }
        }
        .animation(.default, value: model.status)
        .animation(.default, value: calloutPlacement)
        .task { await model.loadData() }
    }
    
    @ViewBuilder
    func mapView(_ map: Map, featureTable: ServiceFeatureTable, featureLayer: FeatureLayer) -> some View {
        MapViewReader { mapView in
            MapView(map: map)
                .onSingleTapGesture { tapLocation, tapMapPoint in
                    // Store state and clear selection on tap.
                    self.tapLocation = tapLocation
                    self.tapMapPoint = tapMapPoint
                    clearSelection()
                }
                .callout(placement: $calloutPlacement) { placement in
                    if let feature = placement.geoElement as? Feature {
                        featureCalloutContent(feature: feature, table: featureTable)
                    } else if let tapMapPoint {
                        addNewFeatureCalloutContent(table: featureTable, point: tapMapPoint)
                    }
                }
                .onNavigatingChanged { _ in
                    // Reset status when user moves the map.
                    model.clearStatus()
                }
                .onViewpointChanged(kind: .centerAndScale) { viewpoint in
                    // Track current viewpoint.
                    currentViewpoint = viewpoint
                }
                .overlay(alignment: .top) {
                    instructionsOverlay
                }
                .task(id: tapLocation) {
                    // Identify when we get a tap location.
                    guard let tapLocation, let tapMapPoint else { return }
                    if let identifyResult = try? await mapView.identify(on: featureLayer, screenPoint: tapLocation, tolerance: 12),
                       let geoElement = identifyResult.geoElements.first,
                       let feature = geoElement as? Feature {
                        // Place a callout for a feature.
                        calloutPlacement = .geoElement(geoElement)
                        featureLayer.selectFeature(feature)
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
                await model.createFeature(point: point)
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
                Text("Damage: \(feature.damageKind?.rawValue ?? "Unknown")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Menu {
                Button {
                    Task {
                        clearSelection()
                        await model.updateAttribute(for: feature)
                    }
                } label: {
                    Text("Update Attribute")
                }
                Button {
                    // Hide callout, leave feature selected.
                    calloutPlacement = nil
                    Task {
                        await model.updateGeometry(
                            for: feature,
                            geometry: currentViewpoint?.targetGeometry
                        )
                        // Update callout location after moving feature.
                        calloutPlacement = .geoElement(feature)
                    }
                } label: {
                    Text("Update Geometry")
                }
                Button {
                    Task {
                        clearSelection()
                        await model.delete(feature: feature)
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
        VStack(spacing: 8) {
            Text("Tap the map to create a new feature, or an existing feature for more options.")
                .multilineTextAlignment(.center)
            if !model.status.isEmpty {
                Text(model.status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
    
    /// Clears the selection on the feature layer, hides the callout, and
    /// resets the status.
    func clearSelection() {
        model.featureLayer?.clearSelection()
        calloutPlacement = nil
        model.clearStatus()
    }
}

extension ManageFeaturesView {
    @MainActor
    @Observable
    final class Model {
        /// The data used within the view that this model is associated with.
        private(set) var data: Result<Data, Error>?
        
        private(set) var isLoading = false
        
        private(set) var error: Error? = nil
        
        /// The map that will be displayed.
        private(set) var map: Map?
        /// The service geodatabase.
        private(set) var geodatabase: ServiceGeodatabase?
        /// The service feature table.
        private(set) var featureTable: ServiceFeatureTable?
        /// The feature layer.
        private(set) var featureLayer: FeatureLayer?
        
        /// The result of the latest action.
        private(set) var status = ""
        
        func clearStatus() {
            status = ""
        }
        
        /// Loads the data for this view.
        func loadData() async {
            isLoading = true
            defer { isLoading = false }
            
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
                
                self.map = map
                self.geodatabase = geodatabase
                self.featureTable = featureTable
                self.featureLayer = featureLayer
            } catch {
                self.error = error
            }
        }
        
        /// Creates a new feature at a specified location and applies edits to the service.
        /// - Parameters:
        ///   - point: The geometry for the feature you are creating.
        func createFeature(point: Point) async {
            guard let featureTable else { return }
            
            let feature = featureTable.makeFeature(
                attributes: [
                    Feature.damageTypeFieldName: DamageKind.inaccessible.rawValue,
                    "primcause": "Earthquake"
                ],
                geometry: point
            )
            do {
                try await featureTable.add(feature)
                _ = try await featureTable.serviceGeodatabase?.applyEdits()
                status = "Create feature succeeded."
            } catch {
                status = "Error creating feature."
            }
        }
        
        /// Updates the attributes of a feature and applies edits to the service.
        /// - Parameter feature: The feature to update.
        func updateAttribute(for feature: Feature) async {
            guard let featureTable else { return }
            
            do {
                feature.damageKind = feature.damageKind?.next ?? .inaccessible
                try await featureTable.update(feature)
                _ = try await featureTable.serviceGeodatabase?.applyEdits()
                status = "Update attribute succeeded."
            } catch {
                status = "Error updating attribute."
            }
        }
        
        /// Updates the geometry of a feature and applies edits to the service.
        /// This moves the feature to the center of the map.
        /// - Parameters:
        ///   - feature: The feature to update.
        ///   - geometry: The new geometry.
        func updateGeometry(for feature: Feature, geometry: Geometry?) async {
            guard let featureTable else { return }
            
            do {
                feature.geometry = geometry
                try await featureTable.update(feature)
                _ = try await featureTable.serviceGeodatabase?.applyEdits()
                status = "Update geometry succeeded."
            } catch {
                status = "Error updating geometry."
            }
        }
        
        /// Deletes a feature from the table and applies edits to the service.
        /// - Parameter feature: The feature to delete.
        func delete(feature: Feature) async {
            guard let featureTable else { return }
            
            do {
                try await featureTable.delete(feature)
                _ = try await featureTable.serviceGeodatabase?.applyEdits()
                status = "Delete feature succeeded."
            } catch {
                status = "Error deleting feature."
            }
        }
    }
}

extension ManageFeaturesView {
    /// A value that describes the damage assessment value for a feature.
    enum DamageKind: String, CaseIterable {
        case inaccessible = "Inaccessible"
        case affected = "Affected"
        case minor = "Minor"
        case major = "Major"
        case destroyed = "Destroyed"
        
        /// The next damage kind to set on a feature.
        var next: Self {
            let allCases = Self.allCases
            let index = allCases.firstIndex(of: self)!
            let nextIndex = allCases.index(after: index)
            return allCases[nextIndex == allCases.count ? 0 : nextIndex]
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
                rawValue: attributeValue(forKey: Self.damageTypeFieldName) as? String ?? ""
            )
        } set {
            // Set the attribute value on the feature by converting the
            // DamageKind to a String value.
            setAttributeValue(newValue?.rawValue, forKey: Self.damageTypeFieldName)
        }
    }
}
