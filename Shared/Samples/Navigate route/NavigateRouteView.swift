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
import AVFoundation
import SwiftUI

struct NavigateRouteView: View {
    /// The view model for this sample.
    @StateObject private var model = Model()
    
    var body: some View {
        MapView(
            map: model.map,
            viewpoint: model.viewpoint,
            graphicsOverlays: model.graphicsOverlays
        )
        .onViewpointChanged(kind: .centerAndScale) { model.viewpoint = $0 }
        .locationDisplay(model.locationDisplay)
        .errorAlert(presentingError: $model.error)
        .overlay(alignment: .top) {
            Text(model.statusText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
        }
        .task {
            // Solves the route and sets the navigation.
            await model.solveRoute()
            model.setNavigation()
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Navigate") {
                    model.isNavigatingRoute = true
                }
                .task(id: model.isNavigatingRoute) {
                    guard model.isNavigatingRoute else { return }
                    await model.startNavigation()
                }
                .disabled(model.isNavigateDisabled || model.isNavigatingRoute)
                
                Spacer()
                
                Button("Recenter") {
                    model.autoPanMode = .navigation
                }
                .disabled(!model.isNavigatingRoute || model.autoPanMode == .navigation)
                
                Spacer()
                
                Button("Reset") {
                    Task {
                        await model.resetNavigation()
                        model.isNavigatingRoute = false
                    }
                }
                .disabled(model.isResettingRoute)
            }
        }
    }
}

private extension NavigateRouteView {
    /// A view model for this sample.
    @MainActor
    class Model: ObservableObject {
        /// A Boolean value indicating whether the navigate button is disabled.
        @Published var isNavigateDisabled = true
        
        /// A Boolean value indicating whether the sample is navigating the route.
        @Published var isNavigatingRoute = false
        
        /// A Boolean value indicating whether navigation is being reset.
        @Published var isResettingRoute = false
        
        /// The error shown in the error alert.
        @Published var error: Error?
        
        /// The viewpoint of the map.
        @Published var viewpoint: Viewpoint?
        
        /// The current auto-pan mode.
        @Published var autoPanMode: LocationDisplay.AutoPanMode {
            didSet {
                locationDisplay.autoPanMode = autoPanMode
            }
        }
        
        /// The status text to display to the user.
        @Published var statusText: String = defaultStatus
        
        /// A map with a navigation basemap style.
        let map = Map(basemapStyle: .arcGISNavigation)
        
        /// The map's location display.
        let locationDisplay = LocationDisplay()
        
        /// The default status to display when not navigating.
        static let defaultStatus = "Directions are shown here."
        
        /// The route task.
        private let routeTask = RouteTask(url: .routeTask)
        
        /// The route result.
        private var routeResult: RouteResult?
        
        /// The route tracker.
        private var routeTracker: RouteTracker!
        
        /// The directions for the route.
        private var directions: [DirectionManeuver] = []
        
        /// An AVSpeechSynthesizer for text to speech.
        private let speechSynthesizer = AVSpeechSynthesizer()
        
        /// The graphics overlay for the stops.
        private let stopGraphicsOverlay: GraphicsOverlay
        
        /// The graphics overlay for the route.
        private let routeGraphicsOverlay: GraphicsOverlay
        
        /// Formats the time remaining for display.
        private let timeFormatter: DateComponentsFormatter = {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .full
            return formatter
        }()
        
        /// The map's graphics overlays.
        var graphicsOverlays: [GraphicsOverlay] {
            return [stopGraphicsOverlay, routeGraphicsOverlay]
        }
        
        /// A graphic of the route remaining.
        private let routeRemainingGraphic: Graphic
        
        /// A graphic of the route traversed.
        private let routeTraversedGraphic: Graphic
        
        init() {
            autoPanMode = .off
            
            // Creates the graphics for each stop.
            let stopGraphics = Self.stops.map {
                Graphic(
                    geometry: $0.geometry,
                    symbol: SimpleMarkerSymbol(style: .diamond, color: .orange, size: 20)
                )
            }
            
            // Creates the graphics for the route remaining and traversed.
            routeRemainingGraphic = Graphic(symbol: SimpleLineSymbol(style: .dash, color: .systemPurple, width: 5))
            routeTraversedGraphic = Graphic(symbol: SimpleLineSymbol(style: .solid, color: .systemBlue, width: 3))
            
            // Creates the graphics overlay for the stops and route.
            stopGraphicsOverlay = GraphicsOverlay(graphics: stopGraphics)
            routeGraphicsOverlay = GraphicsOverlay(graphics: [routeRemainingGraphic, routeTraversedGraphic])
        }
        
        /// Solves the route.
        func solveRoute() async {
            do {
                // Creates the default parameters from the route task.
                let parameters = try await routeTask.makeDefaultParameters()
                
                // Configures the parameters.
                parameters.returnsDirections = true
                parameters.returnsStops = true
                parameters.returnsRoutes = true
                parameters.outputSpatialReference = .wgs84
                
                // Sets the stops on the parameters.
                parameters.setStops(Self.stops)
                
                // Solves the route based on the parameters.
                routeResult = try await routeTask.solveRoute(using: parameters)
                
                // Enables the navigate button.
                isNavigateDisabled = false
            } catch {
                self.error = error
            }
        }
        
        /// Sets the route tracker and location display's data source with a solved route. Updates
        /// the list of directions, the route ahead graphic, and the map's viewpoint.
        func setNavigation() {
            guard let routeResult else { return }
            
            // Creates a route tracker from the route results.
            routeTracker = RouteTracker(routeResult: routeResult, routeIndex: 0, skipsCoincidentStops: true)
            guard let routeTracker else { return }
            
            routeTracker.voiceGuidanceUnitSystem = Locale.current.usesMetricSystem ? .metric : .imperial
            
            // Gets the route and its geometry from the route result.
            guard let firstRoute = routeResult.routes.first,
                  let routeGeometry = firstRoute.geometry else {
                return
            }
            
            // Updates the directions.
            directions = firstRoute.directionManeuvers
            
            // Creates the mock data source from the route's geometry.
            let densifiedRoute = GeometryEngine.geodeticDensify(
                routeGeometry,
                maxSegmentLength: 50,
                lengthUnit: .meters,
                curveType: .geodesic
            ) as! Polyline
            let mockDataSource = SimulatedLocationDataSource(polyline: densifiedRoute)
            
            // Creates a route tracker location data source.
            let routeTrackerLocationDataSource = RouteTrackerLocationDataSource(
                routeTracker: routeTracker,
                locationDataSource: mockDataSource
            )
            
            // Sets the location display's data source.
            locationDisplay.dataSource = routeTrackerLocationDataSource
            
            // Updates the graphics and viewpoint.
            routeRemainingGraphic.geometry = routeGeometry
            viewpoint = Viewpoint(boundingGeometry: routeGeometry, rotation: 0)
        }
        
        /// Starts monitoring multiple asynchronous streams of information.
        private func startTracking() async {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.trackAutoPanMode() }
                group.addTask { await self.trackStatus() }
                group.addTask { await self.trackVoiceGuidance() }
            }
        }
        
        /// Monitors the asynchronous stream of tracking statuses.
        ///
        /// When new statuses are delivered, update the route's traversed and remaining graphics.
        private func trackStatus() async {
            for await status in routeTracker.$trackingStatus {
                if let status {
                    routeTraversedGraphic.geometry = status.routeProgress.traversedGeometry
                    routeRemainingGraphic.geometry = status.routeProgress.remainingGeometry
                    
                    switch status.destinationStatus {
                    case .notReached, .approaching:
                        statusText = """
                        Distance remaining: \(status.routeProgress.remainingDistance.distanceRemainingText)
                        Time remaining: \(timeFormatter.string(from: status.routeProgress.remainingTime)!)
                        """
                        if status.currentManeuverIndex + 1 < directions.count {
                            statusText.append("\nNext direction: \(directions[status.currentManeuverIndex + 1].text)")
                        }
                    case .reached:
                        if status.remainingDestinationCount > 1 {
                            statusText = "Intermediate stop reached, continue to next stop."
                            try? await routeTracker.switchToNextDestination()
                        } else {
                            await locationDisplay.dataSource.stop()
                        }
                    @unknown default:
                        break
                    }
                }
            }
        }
        
        /// Monitors the asynchronous stream of voice guidances.
        private func trackVoiceGuidance() async {
            for try await voiceGuidance in routeTracker.voiceGuidances {
                speechSynthesizer.stopSpeaking(at: .word)
                speechSynthesizer.speak(AVSpeechUtterance(string: voiceGuidance.text))
            }
        }
        
        /// Monitors the asynchronous stream of auto-pan modes.
        ///
        /// Updates the current auto-pan mode if it does not match the location display's auto-pan
        /// mode.
        private func trackAutoPanMode() async {
            for await mode in locationDisplay.$autoPanMode {
                if autoPanMode != mode {
                    autoPanMode = mode
                }
            }
        }
        
        /// Starts navigating the route.
        func startNavigation() async {
            do {
                try await locationDisplay.dataSource.start()
                locationDisplay.autoPanMode = .navigation
                await startTracking()
            } catch {
                self.error = error
            }
        }
        
        /// Resets relevant stateful properties.
        func resetNavigation() async {
            guard !isResettingRoute else { return }
            isResettingRoute = true
            locationDisplay.autoPanMode = .off
            await locationDisplay.dataSource.stop()
            setNavigation()
            routeTraversedGraphic.geometry = nil
            speechSynthesizer.stopSpeaking(at: .immediate)
            statusText = Self.defaultStatus
            isResettingRoute = false
        }
    }
}

private extension NavigateRouteView.Model {
    /// The stops for this sample.
    static var stops: [Stop] {
        let one = Stop(point: Point(x: -117.160386727, y: 32.706608, spatialReference: .wgs84))
        one.name = "San Diego Convention Center"
        let two = Stop(point: Point(x: -117.173034, y: 32.712329, spatialReference: .wgs84))
        two.name = "USS San Diego Memorial"
        let three = Stop(point: Point(x: -117.147230, y: 32.730467, spatialReference: .wgs84))
        three.name = "RH Fleet Aerospace Museum"
        return [one, two, three]
    }
}

private extension TrackingDistance {
    var distanceRemainingText: String {
        "\(displayText) \(self.displayTextUnits.abbreviation)"
    }
}

private extension URL {
    /// The URL for the route task.
    static var routeTask: URL {
        URL(string: "http://sampleserver7.arcgisonline.com/server/rest/services/NetworkAnalysis/SanDiego/NAServer/Route")!
    }
}

#Preview {
    NavigationView {
        NavigateRouteView()
    }
}
