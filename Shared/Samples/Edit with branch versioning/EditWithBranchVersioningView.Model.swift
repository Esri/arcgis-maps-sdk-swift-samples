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
import Foundation

extension EditWithBranchVersioningView {
    /// The view model for the sample.
    @MainActor
    final class Model: ObservableObject {
        /// The names of the versions added by the user.
        ///
        /// - Note: To get a full list of versions, use `ServiceGeodatabase.versions`.
        /// In this sample, only the default version and versions created in current session are shown.
        @Published private(set) var existingVersionNames: [String] = []
        
        /// The text representing the current state of the model.
        @Published private(set) var statusText = ""
        
        /// A map with a streets basemap.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISStreets)
            
            // Initially centers the map's viewpoint on Naperville, IL, USA.
            map.initialViewpoint = Viewpoint(
                center: Point(x: -9811970, y: 5127180, spatialReference: .webMercator),
                scale: 4e3
            )
            return map
        }()
        
        /// A geodatabase connected to the damage assessment feature service.
        private let serviceGeodatabase = ServiceGeodatabase(url: .damageAssessmentFeatureService)
        
        /// The feature layer for displaying the damaged building features.
        private(set) var featureLayer: FeatureLayer!
        
        /// The feature currently selected by the user.
        private(set) var selectedFeature: Feature?
        
        /// A Boolean value indicating whether the geodatabase's current version it's default version.
        var onDefaultVersion: Bool {
            serviceGeodatabase.versionName == serviceGeodatabase.defaultVersionName
        }
        
        /// Sets up the service geodatabase and feature layer.
        func setUp() async throws {
            // Adds the credential to access the feature service for the service geodatabase.
            try await ArcGISEnvironment.authenticationManager.arcGISCredentialStore.add(.publicSample)
            
            statusText = "Loading service geodatabase…"
            try await serviceGeodatabase.load()
            
            existingVersionNames.append(serviceGeodatabase.defaultVersionName)
            statusText = "Version: \(serviceGeodatabase.defaultVersionName)"
            
            // Creates a feature layer from the geodatabase and adds it to the map.
            let serviceFeatureTable = serviceGeodatabase.table(withLayerID: 0)!
            featureLayer = FeatureLayer(featureTable: serviceFeatureTable)
            map.addOperationalLayer(featureLayer)
        }
        
        /// Creates a new version in the service using given parameters.
        /// - Parameter parameters: The properties of the new version.
        func makeVersion(parameters: ServiceVersionParameters) async throws {
            let versionInfo = try await serviceGeodatabase.makeVersion(parameters: parameters)
            existingVersionNames.append(versionInfo.name)
            statusText = "Created Version: \(versionInfo.name)"
        }
        
        /// Switches the geodatabase version to a version with a given name.
        /// - Parameter versionName: The name of the version to connect to.
        func switchToVersion(named versionName: String) async throws {
            if onDefaultVersion {
                // Discards the local edits when on the default branch.
                // Making edits on default branch is disabled, but this is left here for parity.
                try await serviceGeodatabase.undoLocalEdits()
            } else {
                // Applies the local edits when on a user created branch.
                _ = try await serviceGeodatabase.applyEdits()
            }
            clearSelection()
            
            try await serviceGeodatabase.switchToVersion(named: versionName)
            statusText = "Version: \(serviceGeodatabase.versionName)"
        }
        
        /// Selects a feature on the feature layer.
        func selectFeature(_ feature: Feature) {
            featureLayer.selectFeature(feature)
            selectedFeature = feature
        }
        
        /// Clears the selected feature.
        func clearSelection() {
            featureLayer?.clearSelection()
            selectedFeature = nil
        }
        
        /// Updates the selected feature in it's feature table.
        func updateFeature() async throws {
            guard let selectedFeature,
                  let table = selectedFeature.table else {
                return
            }
            try await table.update(selectedFeature)
            
            clearSelection()
        }
    }
}

private extension URL {
    /// The URL to the damage assessment feature server.
    static var damageAssessmentFeatureService: URL {
        URL(string: "https://sampleserver7.arcgisonline.com/server/rest/services/DamageAssessment/FeatureServer")!
    }
}

private extension ArcGISCredential {
    /// The public credentials for the data in this sample.
    /// - Note: Never hardcode login information in a production application. This is done solely for the sake of the sample.
    static var publicSample: ArcGISCredential {
        get async throws {
            try await TokenCredential.credential(
                for: .damageAssessmentFeatureService,
                username: "editor01",
                password: "S7#i2LWmYH75"
            )
        }
    }
}
