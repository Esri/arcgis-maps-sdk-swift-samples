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

struct FindClosestFacilityToMultiplePointsView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The location on the map where the user tapped.
    @State private var tapLocation: Point?
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapView(
            map: model.map,
            graphicsOverlays: [model.facilityGraphicsOverlay, model.incidentGraphicsOverlay]
        )
        .onSingleTapGesture { _, mapPoint in
            tapLocation = mapPoint
        }
        .task(id: tapLocation) {
            // Add an incident at the tap location.
            guard let tapLocation else { return }
            
            do {
                try await model.updateIncident(to: tapLocation)
            } catch {
                self.error = error
            }
        }
        .task {
            // Set up the closest facility parameters when the sample loads.
            do {
                try await model.configureClosestFacilityParameters()
            } catch {
                self.error = error
            }
        }
        .errorAlert(presentingError: $error)
    }
}

private extension FindClosestFacilityToMultiplePointsView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A map with a streets basemap centered on San Diego, CA, USA.
        let map = {
            let map = Map(basemapStyle: .arcGISStreets)
            map.initialViewpoint = Viewpoint(latitude: 32.727, longitude: -117.175, scale: 144_400)
            return map
        }()
        
        /// The graphics overlay for the incident graphics.
        let incidentGraphicsOverlay = GraphicsOverlay()
        
        /// The graphics overlay for the facility graphics.
        let facilityGraphicsOverlay = GraphicsOverlay()
        
        /// The task for finding the closest facility.
        private let closestFacilityTask = ClosestFacilityTask(url: .sanDiegoNetworkAnalysis)
        
        /// The parameters to be passed to the task to find the closest facility.
        private var closestFacilityParameters: ClosestFacilityParameters?
        
        /// A list of facilities around San Diego, CA, USA.
        private let facilities = {
            let facilityPoints = [
                Point(x: -13_042_130, y: 3_860_128, spatialReference: .webMercator),
                Point(x: -13_042_193, y: 3_862_449, spatialReference: .webMercator),
                Point(x: -13_046_883, y: 3_862_705, spatialReference: .webMercator),
                Point(x: -13_040_540, y: 3_862_925, spatialReference: .webMercator),
                Point(x: -13_042_571, y: 3_858_982, spatialReference: .webMercator),
                Point(x: -13_039_785, y: 3_856_693, spatialReference: .webMercator),
                Point(x: -13_049_024, y: 3_861_994, spatialReference: .webMercator)
            ]
            return facilityPoints.map(Facility.init(point:))
        }()
        
        /// The graphic for the route.
        private let routeGraphic = Graphic(
            symbol: SimpleLineSymbol(style: .solid, color: .blue, width: 2.0)
        )
        
        /// The graphic for the incident.
        private let incidentGraphic = Graphic(
            symbol: SimpleMarkerSymbol(style: .cross, color: .black, size: 20)
        )
        
        init() {
            // Add the incident graphics to the graphics overlay.
            incidentGraphicsOverlay.addGraphics([routeGraphic, incidentGraphic])
            
            // Create graphics for all the facilities and add them to the graphics overlay.
            let facilitySymbol = PictureMarkerSymbol(url: .hospitalImage)
            facilitySymbol.height = 30
            facilitySymbol.width = 30
            
            let facilityGraphics = facilities.map {
                Graphic(geometry: $0.geometry, symbol: facilitySymbol)
            }
            facilityGraphicsOverlay.addGraphics(facilityGraphics)
        }
        
        /// Creates the closest facility parameters from the closest facility task and the facilities list.
        func configureClosestFacilityParameters() async throws {
            let parameters = try await closestFacilityTask.makeDefaultParameters()
            parameters.setFacilities(facilities)
            closestFacilityParameters = parameters
        }
        
        /// Updates the incident to a given point and routes to the closest facility accordingly.
        /// - Parameter mapPoint: The point on the map at which to add the incident.
        func updateIncident(to mapPoint: Point) async throws {
            // Update the incident graphic to the new point.
            incidentGraphic.geometry = mapPoint
            
            // Update the parameters with the new incident.
            guard let closestFacilityParameters else { return }
            
            let incident = Incident(point: mapPoint)
            closestFacilityParameters.setIncidents([incident])
            
            // Get the route to the closest facility.
            let closestFacilityRoute = try await routeToClosestFacility(
                using: closestFacilityParameters
            )
            
            // Update the route graphic using the result's geometry to display it on the map.
            routeGraphic.geometry = closestFacilityRoute?.routeGeometry
        }
        
        /// Gets the route to the closest facility to the incident.
        /// - Parameter closestFacilityParameters: The parameters to pass to the closest facility task.
        /// - Returns: The route to the closest facility.
        private func routeToClosestFacility(
            using closestFacilityParameters: ClosestFacilityParameters
        ) async throws -> ClosestFacilityRoute? {
            // Get the closest facility result from the task using the parameters.
            let closestFacilityResult = try await closestFacilityTask.solveClosestFacility(
                using: closestFacilityParameters
            )
            
            // Get the ranked list of the closest facility indexes from the result.
            let rankedFacilityIndexes = closestFacilityResult.rankedIndexesOfFacilities(
                forIncidentAtIndex: 0
            )
            
            // Get the facility index closest to the incident.
            guard let closestFacilityIndex = rankedFacilityIndexes.first else { return nil }
            
            // Get the route for the closest facility and the incident.
            return closestFacilityResult.route(
                toFacilityAtIndex: closestFacilityIndex,
                fromIncidentAtIndex: 0
            )
        }
    }
}

private extension URL {
    /// The URL to a network analysis server for San Diego, CA, USA on ArcGIS Online.
    static var sanDiegoNetworkAnalysis: URL {
        URL(string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/NetworkAnalysis/SanDiego/NAServer/ClosestFacility")!
    }
    
    /// The URL to an image of a hospital symbol on ArcGIS Online.
    static var hospitalImage: URL {
        URL(string: "https://static.arcgis.com/images/Symbols/SafetyHealth/Hospital.png")!
    }
}

#Preview {
    FindClosestFacilityToMultiplePointsView()
}
