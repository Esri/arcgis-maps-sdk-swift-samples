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

struct FindClosestFacilityFromPointView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether a routing operation is in progress.
    @State private var isRouting = false
    
    /// A Boolean value indicating whether routing is currently disabled.
    @State private var routingIsDisabled = true
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapViewReader { mapViewProxy in
            MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
                .overlay(alignment: .center) {
                    if isRouting {
                        ProgressView("Routing...")
                            .padding()
                            .background(.ultraThickMaterial)
                            .cornerRadius(10)
                            .shadow(radius: 50)
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Solve Routes") {
                            Task {
                                do {
                                    isRouting = true
                                    defer { isRouting = false }
                                    
                                    try await model.solveRoutes()
                                    routingIsDisabled = true
                                } catch {
                                    self.error = error
                                }
                            }
                        }
                        .disabled(routingIsDisabled)
                        
                        Spacer()
                        
                        Button("Reset") {
                            model.graphicsOverlay.removeAllGraphics()
                            routingIsDisabled = false
                        }
                        .disabled(model.graphicsOverlay.graphics.isEmpty)
                    }
                }
                .task {
                    // Get the extents of the layers on the map.
                    await model.map.operationalLayers.load()
                    let layerExtents = model.map.operationalLayers.compactMap(\.fullExtent)
                    
                    // Zoom to the extents to view the layers' features.
                    guard let extent = GeometryEngine.combineExtents(of: layerExtents) else { return }
                    await mapViewProxy.setViewpointGeometry(extent, padding: 30)
                }
        }
        .task {
            // Set up the closest facility parameters when the sample loads.
            do {
                try await model.configureClosestFacilityParameters()
                routingIsDisabled = false
            } catch {
                self.error = error
            }
        }
        .errorAlert(presentingError: $error)
    }
}

private extension FindClosestFacilityFromPointView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A map with a streets relief basemap.
        let map = Map(basemapStyle: .arcGISStreetsRelief)
        
        /// The graphics overlay for the route graphics.
        let graphicsOverlay = GraphicsOverlay()
        
        /// The blue line symbol for the route graphics.
        private let routeSymbol = SimpleLineSymbol(
            style: .solid,
            color: UIColor(red: 0, green: 0, blue: 1, alpha: 77 / 255),
            width: 5
        )
        
        /// The task for finding the closest facility.
        private let closestFacilityTask = ClosestFacilityTask(url: .sanDiegoNetworkAnalysis)
        
        /// The parameters to be passed to the closest facility task.
        private var closestFacilityParameters: ClosestFacilityParameters?
        
        init() {
            // Create the feature layers and add them to the map.
            addFeatureLayer(tableURL: .facilitiesLayer, imageURL: .fireStationImage)
            addFeatureLayer(tableURL: .incidentsLayer, imageURL: .fireImage)
        }
        
        /// Creates the closest facility parameters and adds the facilities and incidents from the feature layers.
        func configureClosestFacilityParameters() async throws {
            // Create the default parameters from the closest facility task.
            async let parameters = try closestFacilityTask.makeDefaultParameters()
            
            // Get the feature layers on the map.
            await map.operationalLayers.load()
            let facilitiesLayer = map.operationalLayers.first(
                where: { $0.name == "sandiegofacilities" }
            ) as? FeatureLayer
            let incidentsLayer = map.operationalLayers.first(
                where: { $0.name == "sandiegoincidents" }
            ) as? FeatureLayer
            
            // Get the feature tables from the feature layers.
            guard let facilitiesTable = facilitiesLayer?.featureTable as? ArcGISFeatureTable,
                  let incidentsTable = incidentsLayer?.featureTable as? ArcGISFeatureTable
            else { return }
            
            // Create query parameters that will return all the features.
            let queryParameters = QueryParameters()
            queryParameters.whereClause = "1=1"
            
            // Set the parameters' facilities and incidents using the tables.
            try await parameters.setFacilities(
                fromFeaturesIn: facilitiesTable,
                queryParameters: queryParameters
            )
            try await parameters.setIncidents(
                fromFeaturesIn: incidentsTable,
                queryParameters: queryParameters
            )
            closestFacilityParameters = try await parameters
        }
        
        /// Finds the closest facility routes for the incidents.
        func solveRoutes() async throws {
            guard let closestFacilityParameters else { return }
            
            // Get the closest facility result from the task using the parameters.
            let closestFacilityResult = try await closestFacilityTask.solveClosestFacility(
                using: closestFacilityParameters
            )
            
            // Create a route graphic for each incident in the result.
            let incidentsIndices = closestFacilityResult.incidents.indices
            let routeGraphics = incidentsIndices.compactMap { incidentIndex -> Graphic? in
                // Get the index for the facility closest to the given incident and facility route.
                guard let closestFacilityIndex = closestFacilityResult.rankedIndexesOfFacilities(
                    forIncidentAtIndex: incidentIndex
                ).first,
                      let closestFacilityRoute = closestFacilityResult.route(
                        toFacilityAtIndex: closestFacilityIndex,
                        fromIncidentAtIndex: incidentIndex
                      ) else {
                    return nil
                }
                
                // Create a graphic using the route's geometry.
                return Graphic(geometry: closestFacilityRoute.routeGeometry, symbol: routeSymbol)
            }
            
            graphicsOverlay.addGraphics(routeGraphics)
        }
        
        /// Creates and adds a feature layer to the map.
        /// - Parameters:
        ///   - tableURL: The URL to the feature table to create the feature layer from.
        ///   - imageURL: The URL to the image to use as the layer's renderer.
        private func addFeatureLayer(tableURL: URL, imageURL: URL) {
            // Create a layer from the feature table URL.
            let featureTable = ServiceFeatureTable(url: tableURL)
            let featureLayer = FeatureLayer(featureTable: featureTable)
            
            // Create a simple renderer from the image URL and add it to the layer.
            let markerSymbol = PictureMarkerSymbol(url: imageURL)
            markerSymbol.width = 30
            markerSymbol.height = 30
            featureLayer.renderer = SimpleRenderer(symbol: markerSymbol)
            
            map.addOperationalLayer(featureLayer)
        }
    }
}

private extension URL {
    /// The URL to a network analysis server for San Diego, CA, USA on ArcGIS Online.
    static var sanDiegoNetworkAnalysis: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/NetworkAnalysis/SanDiego/NAServer/ClosestFacility")!
    }
    
    /// The URL to a San Diego facilities feature layer on ArcGIS Online.
    static var facilitiesLayer: URL {
        URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/ArcGIS/rest/services/San_Diego_Facilities/FeatureServer/0")!
    }
    
    /// The URL to a San Diego facilities feature layer on ArcGIS Online.
    static var incidentsLayer: URL {
        URL(string: "https://services2.arcgis.com/ZQgQTuoyBrtmoGdP/ArcGIS/rest/services/San_Diego_Incidents/FeatureServer/0")!
    }
    
    /// The URL to an image of a fire station symbol on ArcGIS Online.
    static var fireStationImage: URL {
        URL(string: "https://static.arcgis.com/images/Symbols/SafetyHealth/FireStation.png")!
    }
    
    /// The URL to an image of a fire symbol on ArcGIS Online.
    static var fireImage: URL {
        URL(string: "https://static.arcgis.com/images/Symbols/SafetyHealth/esriCrimeMarker_56_Gradient.png")!
    }
}

#Preview {
    NavigationView {
        FindClosestFacilityFromPointView()
    }
}
