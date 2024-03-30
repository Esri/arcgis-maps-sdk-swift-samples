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
import CoreLocation
import SwiftUI

struct AugmentRealityToShowHiddenInfrastructureView: View {
    /// The view model for the map view in the sample.
    @StateObject private var model = MapModel()
    
    /// The status message in the overlay.
    @State private var statusMessage = "Tap the map to add pipe points."
    
    /// A Boolean value indicating whether there are graphics to be deleted.
    @State private var canDelete = false
    
    /// A Boolean value indicating whether the current geometry edits can be added as a pipe.
    @State private var canApplyEdits = false
    
    /// A Boolean value indicating whether the geometry editor can undo.
    @State private var geometryEditorCanUndo = false
    
    /// A Boolean value indicating whether the alert for entering an elevation offset is showing.
    @State private var elevationAlertIsPresented = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        NavigationView {
            MapView(map: model.map, graphicsOverlays: [model.pipesGraphicsOverlay])
                .locationDisplay(model.locationDisplay)
                .geometryEditor(model.geometryEditor)
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        toolbarButtons
                    }
                }
        }
        .overlay(alignment: .top) {
            instructionText
        }
        .elevationOffsetAlert(isPresented: $elevationAlertIsPresented) { elevationOffset in
            model.addPipe(elevationOffset: elevationOffset)
            canDelete = true
            
            if elevationOffset < 0 {
                statusMessage = "Pipe added \(elevationOffset.formatted()) meter(s) below surface."
            } else if elevationOffset.isZero {
                statusMessage = "Pipe added at ground level."
            } else {
                statusMessage = "Pipe added \(elevationOffset.formatted()) meter(s) above surface."
            }
            statusMessage.append("\nTap the camera to view the pipe(s) in AR.")
            
            model.geometryEditor.start(withType: Polyline.self)
        }
        .task {
            do {
                try await model.startLocationDisplay()
            } catch {
                self.error = error
            }
            
            // Start the geometry editor and listen for its geometry updates.
            model.geometryEditor.start(withType: Polyline.self)
            
            for await geometry in model.geometryEditor.$geometry {
                let polyline = geometry as? Polyline
                canApplyEdits = polyline?.parts.contains { $0.points.count >= 2 } ?? false
                if canApplyEdits {
                    statusMessage = "Tap the check mark to add the pipe."
                }
                
                geometryEditorCanUndo = model.geometryEditor.canUndo
            }
        }
        .errorAlert(presentingError: $error)
    }
    
    /// The buttons in the bottom toolbar.
    @ViewBuilder private var toolbarButtons: some View {
        Button {
            if geometryEditorCanUndo {
                model.geometryEditor.undo()
            } else {
                model.removeAllGraphics()
                canDelete = false
                statusMessage = "Tap the map to add pipe points."
            }
        } label: {
            Image(systemName: geometryEditorCanUndo ? "arrow.uturn.backward" : "trash")
        }
        .disabled(!geometryEditorCanUndo && !canDelete)
        Spacer()
        
        NavigationLink {
            ARPipesSceneView(model: model.sceneModel)
        } label: {
            Image(systemName: "camera")
        }
        .disabled(geometryEditorCanUndo || !canDelete)
        Spacer()
        
        Button("Done", systemImage: "checkmark") {
            elevationAlertIsPresented = true
        }
        .disabled(!canApplyEdits)
    }
    
    /// The instruction text in the overlay.
    private var instructionText: some View {
        Text(statusMessage)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(8)
            .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
    }
}

private extension AugmentRealityToShowHiddenInfrastructureView {
    // MARK: Map Model
    
    /// The view model for the map view in the sample.
    class MapModel: ObservableObject {
        /// A map with an imagery basemap style.
        let map = Map(basemapStyle: .arcGISImagery)
        
        /// The graphics overlay for the 2D pipe graphics.
        let pipesGraphicsOverlay: GraphicsOverlay = {
            let graphicsOverlay = GraphicsOverlay()
            let redLineSymbol = SimpleLineSymbol(style: .solid, color: .red, width: 2)
            graphicsOverlay.renderer = SimpleRenderer(symbol: redLineSymbol)
            return graphicsOverlay
        }()
        
        /// The location display for showing the user's current location.
        let locationDisplay: LocationDisplay = {
            let locationDisplay = LocationDisplay(dataSource: SystemLocationDataSource())
            locationDisplay.autoPanMode = .recenter
            locationDisplay.initialZoomScale = 1000
            return locationDisplay
        }()
        
        /// The geometry editor for creating polylines representing pipes.
        let geometryEditor = GeometryEditor()
        
        /// The view model for scene view in the sample.
        let sceneModel = SceneModel()
        
        /// Starts the location display to show user's location on the map.
        func startLocationDisplay() async throws {
            // Request location permission if it has not yet been determined.
            let locationManager = CLLocationManager()
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
            
            // Start the location display to zoom to the user's current location.
            try await locationDisplay.dataSource.start()
        }
        
        /// Adds pipe graphics to the map and scene using the current geometry editor edits.
        /// - Parameter elevationOffset: The elevation to offset the pipe with in the scene.
        func addPipe(elevationOffset: Double) {
            guard let polyline = geometryEditor.stop() as? Polyline else { return }
            
            let pipeGraphic = Graphic(geometry: polyline)
            pipesGraphicsOverlay.addGraphic(pipeGraphic)
            
            Task {
                await sceneModel.addGraphics(for: polyline, elevationOffset: elevationOffset)
            }
        }
        
        /// Removes the graphics from the map and scene graphics overlays.
        func removeAllGraphics() {
            pipesGraphicsOverlay.removeAllGraphics()
            
            sceneModel.pipeGraphicsOverlay.removeAllGraphics()
            sceneModel.shadowGraphicsOverlay.removeAllGraphics()
            sceneModel.leaderGraphicsOverlay.removeAllGraphics()
        }
    }
    
    // MARK: Elevation Alert
    
    /// An alert that allows the user to enter an elevation offset for a pipe.
    struct ElevationOffsetAlert: ViewModifier {
        /// A binding to a Boolean value that determines whether to present the alert.
        @Binding var isPresented: Bool
        
        /// The action to perform when the user presses "Done".
        let action: (Double) -> Void
        
        /// The text in the text field.
        @State private var text = ""
        
        /// A Boolean value indicating whether the invalid elevation alert is showing.
        @State private var invalidAlertIsPresented = false
        
        func body(content: Content) -> some View {
            content
                .alert("Enter an Elevation", isPresented: $isPresented) {
                    TextField("Enter elevation", text: $text)
                        .keyboardType(.numbersAndPunctuation)
                    
                    Button("Cancel", role: .cancel, action: {})
                    
                    Button("Done") {
                        if let elevationOffset = Double(text),
                           -10...10 ~= elevationOffset {
                            action(elevationOffset)
                            text.removeAll()
                        } else {
                            invalidAlertIsPresented = true
                        }
                    }
                } message: {
                    Text("Enter a pipe elevation offset in meters between -10 and 10.")
                }
                .alert("Invalid Elevation", isPresented: $invalidAlertIsPresented) {
                    Button("OK") {
                        isPresented = true
                    }
                } message: {
                    Text("\"\(text)\" is not a valid elevation offset.\nEnter a value between -10 and 10.")
                }
        }
    }
}

private extension View {
    /// Presents an alert that allows the user to enter an elevation offset for a pipe.
    /// - Parameters:
    ///   - isPresented: A binding to a Boolean value that determines whether to present the alert.
    ///   - action: The action to perform when the user presses "Done".
    /// - Returns: A new `View`.
    func elevationOffsetAlert(
        isPresented: Binding<Bool>,
        action: @escaping (Double) -> Void
    ) -> some View {
        self.modifier(
            AugmentRealityToShowHiddenInfrastructureView.ElevationOffsetAlert(
                isPresented: isPresented,
                action: action
            )
        )
    }
}
