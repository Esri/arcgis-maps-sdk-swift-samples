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
import AVFoundation
import Combine

extension NavigateRouteWithReroutingView {
    /// The view model for the sample.
    @MainActor
    class Model: ObservableObject {
        // MARK: Properties
        
        /// The text representing the current status of the route.
        @Published private(set) var statusMessage: String = .initialInstructions
        
        /// A Boolean value indicating whether the route is being navigated.
        @Published private(set) var isNavigating = false
        
        /// The viewpoint of the map.
        @Published var viewpoint: Viewpoint?
        
        /// A map with a navigation basemap.
        let map = Map(basemapStyle: .arcGISNavigation)
        
        /// The graphics overlay for the route and stop graphics.
        let graphicsOverlay: GraphicsOverlay = {
            // Create a graphic for the start location.
            let greenCrossSymbol = SimpleMarkerSymbol(style: .cross, color: .green, size: 25)
            let startGraphic = Graphic(geometry: .startLocation, symbol: greenCrossSymbol)
            
            // Create a graphic for the destination location.
            let redXSymbol = SimpleMarkerSymbol(style: .x, color: .red, size: 20)
            let destinationGraphic = Graphic(geometry: .destinationLocation, symbol: redXSymbol)
            
            // Create a graphics overlay with the graphics.
            return GraphicsOverlay(graphics: [startGraphic, destinationGraphic])
        }()
        
        /// The map's location display.
        let locationDisplay = LocationDisplay()
        
        /// The route tracker for tracking the status and progress of the route navigation.
        private(set) var routeTracker: RouteTracker!
        
        /// The parameters for enabling automatic rerouting on the route tracker.
        private var reroutingParameters: ReroutingParameters!
        
        /// The route result solved by the route task.
        private var routeResult: RouteResult!
        
        /// The data source containing the simulated locations.
        private let simulatedDataSource = SimulatedLocationDataSource()
        
        /// A speech synthesizer for text to speech.
        private let speechSynthesizer = AVSpeechSynthesizer()
        
        /// The graphic representing the route ahead.
        private let remainingRouteGraphic: Graphic = {
            let dashedPurpleLineSymbol = SimpleLineSymbol(style: .dash, color: .systemPurple, width: 5)
            return Graphic(symbol: dashedPurpleLineSymbol)
        }()
        
        /// The graphic representing the route that's been traveled.
        private let traversedRouteGraphic: Graphic = {
            let solidBlueLineSymbol = SimpleLineSymbol(style: .solid, color: .systemBlue, width: 3)
            return Graphic(symbol: solidBlueLineSymbol)
        }()
        
        /// A builder to make a polyline for the traversed route graphic.
        private let traversedRouteBuilder = PolylineBuilder(spatialReference: .wgs84)
        
        init() {
            // Add the route graphics to the graphics overlay.
            graphicsOverlay.addGraphics([remainingRouteGraphic, traversedRouteGraphic])
        }
        
        // MARK: Methods
        
        /// Sets up the route related properties.
        func setUp() async throws {
            // Create a route task from a local geodatabase to solve a route.
            let routeTask = RouteTask(
                pathToDatabaseURL: .sanDiegoGeodatabase,
                networkName: "Streets_ND"
            )
            
            // Create the route parameters.
            let routeParameters = try await routeTask.makeDefaultParameters()
            routeParameters.returnsDirections = true
            routeParameters.returnsStops = true
            routeParameters.outputSpatialReference = .wgs84
            
            // Sets the start and destination stops for the route.
            let startStop = Stop(point: .startLocation)
            startStop.name = "San Diego Convention Center"
            
            let destinationStop = Stop(point: .destinationLocation)
            destinationStop.name = "RH Fleet Aerospace Museum"
            
            routeParameters.setStops([startStop, destinationStop])
            
            // Solve the route using the parameters and task.
            routeResult = try await routeTask.solveRoute(using: routeParameters)
            
            // Create the rerouting parameters using the route task and parameters.
            reroutingParameters = ReroutingParameters(
                routeTask: routeTask,
                routeParameters: routeParameters
            )
            
            // Set up the data source's locations using a local JSON file.
            let jsonData = try Data(contentsOf: .sanDiegoTourPath)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
            let routePolyline = try Polyline.fromJSON(jsonString)
            simulatedDataSource.setSimulatedLocations(with: routePolyline)
            
            try await initializeNavigation()
        }
        
        /// Starts the navigation.
        func start() async throws {
            try await locationDisplay.dataSource.start()
            locationDisplay.autoPanMode = .navigation
            
            isNavigating = true
        }
        
        /// Stops the navigation.
        func stop() async {
            // Stop any current speech.
            speechSynthesizer.stopSpeaking(at: .immediate)
            
            // Stop the location display.
            locationDisplay.autoPanMode = .off
            await locationDisplay.dataSource.stop()
            
            isNavigating = false
        }
        
        /// Resets the navigation.
        func reset() async throws {
            await stop()
            
            // Reset the graphics.
            statusMessage = .initialInstructions
            traversedRouteGraphic.geometry = nil
            traversedRouteBuilder.replaceGeometry(with: nil)
            
            // Reset the navigation.
            simulatedDataSource.currentLocationIndex = 0
            try await initializeNavigation()
        }
        
        /// Updates the status message and route graphics using the progress from a given tracking status.
        /// - Parameter status: The `TrackingStatus`.
        func updateProgress(using status: TrackingStatus) async {
            // Update the route graphics.
            remainingRouteGraphic.geometry = status.routeProgress.remainingGeometry
            
            if let currentPosition = locationDisplay.location?.position {
                traversedRouteBuilder.add(currentPosition)
                traversedRouteGraphic.geometry = traversedRouteBuilder.toGeometry()
            }
            
            // Update the status message.
            switch status.destinationStatus {
            case .approaching, .notReached:
                // Format the route's remaining distance and time.
                let distanceRemainingText = status.routeProgress.remainingDistance.distance.formatted()
                
                let dateInterval = DateInterval(start: .now, duration: status.routeProgress.remainingTime)
                let dateRange = dateInterval.start..<dateInterval.end
                let timeRemainingText = dateRange.formatted(
                    .components(style: .abbreviated, fields: [.day, .hour, .minute, .second])
                )
                
                statusMessage = """
                Distance remaining: \(distanceRemainingText)
                Time remaining: \(timeRemainingText)
                """
                
                // Get the next direction from the route's direction maneuvers.
                let nextManeuverIndex = status.currentManeuverIndex + 1
                if let route = routeResult.routes.first,
                   route.directionManeuvers.indices.contains(nextManeuverIndex) {
                    let nextDirection = route.directionManeuvers[nextManeuverIndex].text
                    statusMessage.append("\nNext direction: \(nextDirection)")
                }
                
            case .reached:
                if status.remainingDestinationCount > 1 {
                    statusMessage = "Intermediate stop reached, continue to next stop."
                    try? await routeTracker.switchToNextDestination()
                } else {
                    await stop()
                    statusMessage = "Destination reached."
                }
                
            @unknown default:
                break
            }
        }
        
        /// Speaks a given voice guidance.
        /// - Parameter voiceGuidance: The `VoiceGuidance`.
        func speakVoiceGuidance(_ voiceGuidance: VoiceGuidance) {
            guard !voiceGuidance.text.isEmpty else { return }
            
            let utterance = AVSpeechUtterance(string: voiceGuidance.text)
            speechSynthesizer.stopSpeaking(at: .word)
            speechSynthesizer.speak(utterance)
        }
        
        /// Initializes the route tracker, location display, and route graphic.
        private func initializeNavigation() async throws {
            // Make the route tracker.
            routeTracker = try await makeRouteTracker(
                routeResult: routeResult,
                reroutingParameters: reroutingParameters
            )
            
            // Create a route tracker location data source to snap the location display to the route.
            let routeTrackerLocationDataSource = RouteTrackerLocationDataSource(
                routeTracker: routeTracker,
                locationDataSource: simulatedDataSource
            )
            
            // Set location display's data source.
            locationDisplay.dataSource = routeTrackerLocationDataSource
            
            // Update the remaining route graphic and center the map's viewpoint on it.
            guard let routeGeometry = routeResult.routes.first?.geometry else { return }
            remainingRouteGraphic.geometry = routeGeometry
            viewpoint = Viewpoint(center: routeGeometry.extent.center, scale: 23e3, rotation: 0)
        }
        
        /// Makes a route tracker that supports rerouting.
        /// - Parameters:
        ///   - routeResult: A `RouteResult` generated from a route task solve.
        ///   - reroutingParameters: The `ReroutingParameters` used to enable automatic rerouting.
        /// - Returns: A new `RouteTracker`.
        private func makeRouteTracker(
            routeResult: RouteResult,
            reroutingParameters: ReroutingParameters
        ) async throws -> RouteTracker {
            // Make the route tracker using the route result.
            let routeTracker = RouteTracker(
                routeResult: routeResult,
                routeIndex: 0,
                skipsCoincidentStops: true
            )!
            
            // Enable automatic rerouting on the tracker.
            try await routeTracker.enableRerouting(using: reroutingParameters)
            
            // Update the tracker's voice guidance unit system to the current locale's.
            routeTracker.voiceGuidanceUnitSystem = Locale.current.usesMetricSystem ? .metric : .imperial
            
            return routeTracker
        }
    }
}

// MARK: Extensions

private extension String {
    /// The text with initial instructions for the sample.
    static let initialInstructions = "Press play to start navigating."
}

private extension Geometry {
    /// The starting location of the route, the San Diego Convention Center.
    static var startLocation: Point {
        Point(latitude: 32.706608, longitude: -117.160386727)
    }
    
    /// The destination location of the route, the Fleet Science Center.
    static var destinationLocation: Point {
        Point(latitude: 32.730351, longitude: -117.146679)
    }
}

private extension URL {
    /// A URL to the local geodatabase file of San Diego, CA, USA.
    static var sanDiegoGeodatabase: URL {
        Bundle.main.url(
            forResource: "sandiego",
            withExtension: "geodatabase",
            subdirectory: "san_diego_offline_routing"
        )!
    }
    
    /// A URL to the local "SanDiegoTourPath" JSON file containing the simulated path.
    static var sanDiegoTourPath: URL {
        Bundle.main.url(forResource: "SanDiegoTourPath", withExtension: "json")!
    }
}
