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
import SwiftUI

struct ShowGridView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The current viewpoint of the geo views.
    @State private var viewpoint = Viewpoint(latitude: 34.05, longitude: -118.25, scale: 8e6)
    
    /// A Boolean value indicating whether the settings view should be presented.
    @State private var showsGridSettingsView = false
    
    var body: some View {
        Group {
            if model.geoViewType == .mapView {
                MapView(map: model.map, viewpoint: viewpoint)
                    .grid(model.grid)
                    .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
            } else {
                SceneView(scene: model.scene, viewpoint: viewpoint)
                    .grid(model.grid)
                    .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Grid Settings") {
                    showsGridSettingsView = true
                }
                .popover(isPresented: $showsGridSettingsView) {
                    NavigationStack {
                        GridSettingsView(model: model)
                    }
                    .presentationDetents([.fraction(0.6), .large])
                    .frame(idealWidth: 350, idealHeight: 480)
                }
                
                Picker("Geo View", selection: $model.geoViewType) {
                    Text("Map View").tag(GeoViewType.mapView)
                    Text("Scene View").tag(GeoViewType.sceneView)
                }
            }
        }
    }
}

private extension ShowGridView {
    // MARK: - Model
    
    /// The view model for the sample.
    final class Model: ObservableObject {
        /// A map with a topographic basemap.
        let map = Map(basemapStyle: .arcGISTopographic)
        
        /// A scene with elevation and a topographic basemap.
        let scene: ArcGIS.Scene = {
            let scene = Scene(basemapStyle: .arcGISTopographic)
            let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
            scene.baseSurface.addElevationSource(elevationSource)
            return scene
        }()
        
        /// The type of geo view that is showing.
        @Published var geoViewType = GeoViewType.mapView {
            didSet { grid = makeGrid(type: gridType) }
        }
        
        /// The geo view's grid, initially set to a Lat-Lon grid.
        @Published var grid: ArcGIS.Grid = LatitudeLongitudeGrid()
        
        /// The kind of grid to display.
        @Published var gridType: GridType = .latitudeLongitude {
            didSet { grid = makeGrid(type: gridType) }
        }
        
        /// The format used for labeling the grid.
        @Published var labelFormat: LatitudeLongitudeGrid.LabelFormat = .decimalDegrees
        
        /// The units used for labeling the USNG grid.
        @Published var usngLabelUnit: USNGGrid.LabelUnit = .kilometersMeters
        
        /// The units used for labeling the MGRS grid.
        @Published var mgrsLabelUnit: MGRSGrid.LabelUnit = .kilometersMeters
        
        /// A Boolean value indicating whether the current grid only supports `LabelPosition.geographic`.
        var gridOnlySupportsGeographic: Bool {
            geoViewType == .sceneView && gridType != .latitudeLongitude
        }
        
        /// Creates a new grid of a given type.
        /// - Parameter gridType: The kind of grid to make.
        /// - Returns: A new `Grid` object.
        private func makeGrid(type gridType: GridType) -> ArcGIS.Grid {
            let newGrid: ArcGIS.Grid
            switch gridType {
            case .latitudeLongitude:
                let latitudeLongitudeGrid = LatitudeLongitudeGrid()
                latitudeLongitudeGrid.labelFormat = labelFormat
                newGrid = latitudeLongitudeGrid
            case .mgrs:
                let mgrsGrid = MGRSGrid()
                mgrsGrid.labelUnit = mgrsLabelUnit
                newGrid = mgrsGrid
            case .usng:
                let usngGrid = USNGGrid()
                usngGrid.labelUnit = usngLabelUnit
                newGrid = usngGrid
            case .utm:
                newGrid = UTMGrid()
            }
            
            newGrid.isVisible = grid.isVisible
            newGrid.labelsAreVisible = grid.labelsAreVisible
            newGrid.linesColor = grid.linesColor
            newGrid.labelsColor = grid.labelsColor
            newGrid.labelPosition = gridOnlySupportsGeographic ? .geographic : grid.labelPosition
            
            return newGrid
        }
    }
    
    /// A type of `GeoView`.
    enum GeoViewType {
        case mapView, sceneView
    }
    
    // MARK: - Settings View
    
    struct GridSettingsView: View {
        /// The action to dismiss the sheet.
        @Environment(\.dismiss) private var dismiss
        
        /// The view model for the sample.
        @ObservedObject var model: Model
        
        var body: some View {
            Form {
                Section("Grid Line Settings") {
                    Picker("Grid Type", selection: $model.gridType) {
                        ForEach(GridType.allCases, id: \.self) { type in
                            Text(type.label)
                        }
                    }
                    
                    Toggle("Visible", isOn: $model.grid.isVisible)
                    
                    ColorPicker("Color", selection: $model.grid.linesColor)
                }
                
                Section("Labels Settings") {
                    Toggle("Visible", isOn: $model.grid.labelsAreVisible)
                    
                    ColorPicker("Color", selection: $model.grid.labelsColor)
                    
                    Picker("Position", selection: $model.grid.labelPosition) {
                        ForEach(Grid.LabelPosition.allCases, id: \.self) { position in
                            Text(position.label)
                        }
                    }
                    .disabled(model.gridOnlySupportsGeographic)
                    
                    if let latitudeLongitudeGrid = model.grid as? LatitudeLongitudeGrid {
                        Picker("Format", selection: $model.labelFormat) {
                            ForEach(LatitudeLongitudeGrid.LabelFormat.allCases, id: \.self) { format in
                                Text(format.label)
                            }
                        }
                        .onChange(of: model.labelFormat) { newLabelFormat in
                            latitudeLongitudeGrid.labelFormat = newLabelFormat
                        }
                    } else if let mgrsGrid = model.grid as? MGRSGrid {
                        Picker("Unit", selection: $model.mgrsLabelUnit) {
                            ForEach(MGRSGrid.LabelUnit.allCases, id: \.self) { unit in
                                Text(unit.label)
                            }
                        }
                        .onChange(of: model.mgrsLabelUnit) { newMGRSLabelUnit in
                            mgrsGrid.labelUnit = newMGRSLabelUnit
                        }
                    } else if let usngGrid = model.grid as? USNGGrid {
                        Picker("Unit", selection: $model.usngLabelUnit) {
                            ForEach(USNGGrid.LabelUnit.allCases, id: \.self) { unit in
                                Text(unit.label)
                            }
                        }
                        .onChange(of: model.usngLabelUnit) { newUSNGLabelUnit in
                            usngGrid.labelUnit = newUSNGLabelUnit
                        }
                    }
                }
            }
            .navigationTitle("Grid Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Helper Extensions

private extension ArcGIS.Grid {
    /// The color of the grid lines.
    var linesColor: Color {
        get {
            let lineSymbol = lineSymbols.first(where: { $0 is LineSymbol }) as! LineSymbol
            return Color(uiColor: lineSymbol.color)
        }
        set {
            for symbol in lineSymbols where symbol is LineSymbol {
                let lineSymbol = symbol as! LineSymbol
                lineSymbol.color = UIColor(newValue)
            }
        }
    }
    
    /// The color of the grid labels.
    var labelsColor: Color {
        get {
            let textSymbol = textSymbols.first(where: { $0 is TextSymbol }) as! TextSymbol
            return Color(uiColor: textSymbol.color)
        }
        set {
            for symbol in textSymbols where symbol is TextSymbol {
                let textSymbol = symbol as! TextSymbol
                textSymbol.color = UIColor(newValue)
            }
        }
    }
}

private extension ShowGridView {
    /// The kinds of grid to show on the geo view.
    enum GridType: CaseIterable {
        case latitudeLongitude, mgrs, usng, utm
        
        var label: String {
            switch self {
            case .latitudeLongitude: "Latitude-Longitude"
            case .mgrs: "MGRS"
            case .usng: "USNG"
            case .utm: "UTM"
            }
        }
    }
}

private extension ArcGIS.Grid.LabelPosition {
    static var allCases: [Self] {
        return [
            .allSides,
            .center,
            .topLeft,
            .topRight,
            .bottomLeft,
            .bottomRight,
            .geographic
        ]
    }
    
    var label: String {
        switch self {
        case .geographic: "Geographic"
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .center: "Center"
        case .allSides: "All Sides"
        @unknown default: fatalError("Unknown grid label position")
        }
    }
}

private extension LatitudeLongitudeGrid.LabelFormat {
    static var allCases: [Self] { [.decimalDegrees, .degreesMinutesSeconds] }
    
    var label: String {
        switch self {
        case .decimalDegrees: "Decimal Degrees"
        case .degreesMinutesSeconds: "Degrees, Minutes, Seconds"
        @unknown default: fatalError("Unknown Lat-Lon grid label format")
        }
    }
}

private extension MGRSGrid.LabelUnit {
    static var allCases: [Self] { [.kilometersMeters, .meters] }
    
    var label: String {
        switch self {
        case .kilometersMeters: "Kilometers or Meters"
        case .meters: "Meters"
        @unknown default: fatalError("Unknown MGRS grid label unit")
        }
    }
}

private extension USNGGrid.LabelUnit {
    static var allCases: [Self] { [.kilometersMeters, .meters] }
    
    var label: String {
        switch self {
        case .kilometersMeters: "Kilometers or Meters"
        case .meters: "Meters"
        @unknown default: fatalError("Unknown USNG grid label unit")
        }
    }
}

private extension URL {
    /// A web URL to the Terrain3D image server on ArcGIS REST.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
}

// MARK: - Preview

#Preview {
    ShowGridView()
}
