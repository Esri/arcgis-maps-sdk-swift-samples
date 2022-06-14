// Copyright 2022 Esri
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

import SwiftUI
import ArcGIS

struct DisplayFeatureLayersView: View {
    /// A Boolean value indicating whether to show an alert.
    @State private var showAlert = false
    
    /// The error shown in the alert.
    @State private var error: Error?
    
    /// The feature layer source that is displayed.
    @State private var selectedFeatureLayerSource = FeatureLayerSource.serviceFeatureTable
    
    /// The current viewpoint of the map view.
    @State private var viewpoint: Viewpoint?
    
    /// A map with a topographic basemap style.
    @StateObject private var map = Map(basemapStyle: .arcGISTopographic)
    
    /// An authentication model to handle credentials for the service feature table.
    private let authenticationModel = AuthenticationModel()
    
    /// Loads the geodatabase and geopackage.
    private func loadGeoSources() async {
        do {
            try await Geodatabase.laTrails.load()
            try await GeoPackage.auroraCO.load()
        } catch {
            self.error = error
            showAlert = true
        }
    }
    
    /// Updates the feature layer to reflect the source chosen by the user.
    private func updateFeatureLayer() async {
        do {
            switch selectedFeatureLayerSource {
            case .serviceFeatureTable:
                // Sets the feature layer to the damage assessment feature layer.
                try await setFeatureLayer(.damageAssessment, viewpoint: .damageAssessment)
            case .portalItem:
                // Sets the feature layer to the trees of Portland feature layer.
                try await setFeatureLayer(.treesOfPortland, viewpoint: .treesOfPortland)
            case .geodatabase:
                // Sets the feature layer to the LA trails feature layer.
                try await setFeatureLayer(.laTrails, viewpoint: .laTrails)
            case .geoPackage:
                // Sets the feature layer to the Aurora, CO, feature layer.
                try await setFeatureLayer(.auroraCO, viewpoint: .auroraCO)
            case .shapefile:
                // Sets the feature layer to the reserve boundaries feature layer.
                try await setFeatureLayer(.reserveBoundaries, viewpoint: .reserveBoundaries)
            }
        } catch {
            // Updates the error and shows an alert if any failures occur.
            self.error = error
            showAlert = true
        }
    }
    
    /// Sets the map's operational layer to the given feature layer and updates the current viewpoint.
    private func setFeatureLayer(_ featureLayer: FeatureLayer, viewpoint: Viewpoint) async throws {
        // Loads the feature layer.
        if featureLayer.loadStatus != .loaded {
            try await featureLayer.load()
        }
        
        // Updates the map's operational layers.
        map.removeAllOperationalLayers()
        map.addOperationalLayer(featureLayer)
        
        // Updates the current viewpoint.
        self.viewpoint = viewpoint
    }
    
    var body: some View {
        VStack {
            MapView(map: map, viewpoint: viewpoint)
                .task {
                    // Loads the geodatabase and geopackage.
                    await loadGeoSources()
                    // Updates the feature layer.
                    await updateFeatureLayer()
                }
            
            Menu("Feature Layer Sources") {
                Picker("Feature Layer", selection: $selectedFeatureLayerSource) {
                    ForEach(FeatureLayerSource.allCases, id: \.self) { source in
                        Text(source.label)
                    }
                }
            }
            .onChange(of: selectedFeatureLayerSource) { _ in
                Task {
                    // Loads the selected feature layer.
                    await updateFeatureLayer()
                }
            }
            .padding()
        }
        .alert(isPresented: $showAlert, presentingError: error)
        .onAppear {
            // Updates the URL session challenge handler to use the
            // specified credentials and tokens for any challenges.
            ArcGISURLSession.challengeHandler = authenticationModel
        }
        .onDisappear {
            // Resets the URL session challenge handler to use default handling.
            ArcGISURLSession.challengeHandler = nil
        }
    }
}

/// The feature layers used in this sample.
private extension FeatureLayer {
    /// Created using a service feature table.
    /// Displays the damage to commercial buildings in Naperville, Illinois.
    static let damageAssessment = FeatureLayer(featureTable: ServiceFeatureTable(url: .damageAssessment))
    /// Created using a portal item.
    /// Displays a collection of public street trees in Portland, Oregon.
    static let treesOfPortland = FeatureLayer(
        item: PortalItem(
            portal: .arcGISOnline(isLoginRequired: false),
            id: .treesOfPortland
        )
    )
    /// Created using a geodatabase.
    /// Displays trailhead points within Los Angeles, California.
    static let laTrails = FeatureLayer(
        featureTable: Geodatabase
            .laTrails
            .getGeodatabaseFeatureTable(tableName: "Trailheads")!
    )
    /// Created using a GeoPackage.
    /// Displays public art (points), bike trails (lines), subdivisions (polygons),
    /// airport noise (raster), and liquor license density (raster) in Aurora, Colorado.
    static let auroraCO = FeatureLayer(
        featureTable: GeoPackage
            .auroraCO
            .geoPackageFeatureTables
            .first!
    )
    /// Created using a shapefile.
    /// Displays the wildlife reserve boundaries managed by the Scottish Wildlife Trust.
    static let reserveBoundaries = FeatureLayer(featureTable: ShapefileFeatureTable.reserveBoundaries)
}

private extension Item.ID {
    /// The ID used in the trees of Portland portal item.
    static let treesOfPortland = Self("1759fd3e8a324358a0c58d9a687a8578")!
}

private extension Geodatabase {
    /// The LA trails geodatabase.
    static let laTrails = Geodatabase(fileURL: .laTrails)
}

private extension GeoPackage {
    /// The Aurora, CO, GeoPackage.
    static let auroraCO = GeoPackage(fileURL: .auroraCO)
}

private extension ShapefileFeatureTable {
    /// The reserve boundaries shapefile feature table.
    static let reserveBoundaries = ShapefileFeatureTable(fileURL: .reserveBoundaries)
}

/// The viewpoints for each feature layer source.
private extension Viewpoint {
    /// The viewpoint for Naperville, IL.
    static let damageAssessment = Viewpoint(latitude: 41.773519, longitude: -88.143104, scale: 4e3)
    /// The viewpoint for Portland, OR.
    static let treesOfPortland = Viewpoint(latitude: 45.5266, longitude: -122.6219, scale: 6e3)
    /// The viewpoint for Los Angeles, CA.
    static let laTrails = Viewpoint(latitude: 34.0772, longitude: -118.7989, scale: 6e5)
    /// The viewpoint for Aurora, CO.
    static let auroraCO = Viewpoint(latitude: 39.7294, longitude: -104.8319, scale: 5e5)
    /// The viewpoint for Scotland.
    static let reserveBoundaries = Viewpoint(latitude: 56.641344, longitude: -3.889066, scale: 6e6)
}

/// The URLs for each feature layer source.
private extension URL {
    static let damageAssessment = URL(string: "https://sampleserver7.arcgisonline.com/server/rest/services/DamageAssessment/FeatureServer/0")!
    static let laTrails = Bundle.main.url(forResource: "LA_Trails", withExtension: "geodatabase")!
    static let auroraCO = Bundle.main.url(forResource: "AuroraCO", withExtension: "gpkg")!
    static let reserveBoundaries = Bundle.main.url(forResource: "ScottishWildlifeTrust_ReserveBoundaries_20201102", withExtension: "shp")!
}

private extension DisplayFeatureLayersView {
    /// The various feature layer sources.
    enum FeatureLayerSource: CaseIterable {
        case shapefile, geoPackage, geodatabase, portalItem, serviceFeatureTable
        
        /// A human-readable label for each feature layer source.
        var label: String {
            switch self {
            case .serviceFeatureTable: return "Service Feature Table"
            case .portalItem: return "Portal Item"
            case .geodatabase: return "Geodatabase"
            case .geoPackage: return "GeoPackage"
            case .shapefile: return "Shapefile"
            }
        }
    }
}

/// The authentication model used to handle challenges and credentials.
private class AuthenticationModel: AuthenticationChallengeHandler {
    func handleArcGISChallenge(
        _ challenge: ArcGISAuthenticationChallenge
    ) async throws -> ArcGISAuthenticationChallenge.Disposition {
        return .useCredential(
            // NOTE: Never hardcode login information in a production application.
            // This is done solely for the sake of the sample.
            try await .token(challenge: challenge, username: "viewer01", password: "I68VGU^nMurF")
        )
    }
}
