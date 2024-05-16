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
    /// A map with topographic basemap.
    @State private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        map.initialViewpoint = Viewpoint(latitude: 34.05, longitude: -118.25, scale: 8e6)
        return map
    }()
    
    /// The map view's grid, initially set to a lat-lon grid.
    @State private var grid: ArcGIS.Grid = LatitudeLongitudeGrid()
    
    /// A Boolean value indicating whether the settings view should be presented.
    @State private var showsGridSettingsView = false
    
    var body: some View {
        MapView(map: map)
            .grid(grid)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Grid Settings") {
                        showsGridSettingsView = true
                    }
                    .popover(isPresented: $showsGridSettingsView) {
                        NavigationStack {
                            GridSettingsView(grid: $grid)
                        }
                        .presentationDetents([.fraction(0.6), .large])
                        .frame(idealWidth: 350, idealHeight: 750)
                    }
                }
            }
    }
}

// MARK: - Settings View

private extension ShowGridView {
    struct GridSettingsView: View {
        /// The action to dismiss the sheet.
        @Environment(\.dismiss) private var dismiss
        
        /// The binding to the grid object.
        @Binding var grid: ArcGIS.Grid
        
        /// A Boolean value indicating whether the grid is visible.
        @State private var gridIsVisible = true
        
        /// A Boolean value indicating whether the grid labels are visible.
        @State private var labelsAreVisible = true
        
        /// The color of the grid lines.
        @State private var gridColor = Color(uiColor: .red)
        
        /// The color of the grid labels.
        @State private var labelsColor = Color(uiColor: .red)
        
        /// The kind of grid to display
        @State private var gridType: GridType = .latLon
        
        /// The positioning of the grid's labels.
        @State private var labelPosition: ArcGIS.Grid.LabelPosition = .allSides
        
        /// The format used for labeling the grid.
        @State private var labelFormat: LatitudeLongitudeGrid.LabelFormat = .decimalDegrees
        
        /// The units used for labeling the USNG grid.
        @State private var usngLabelUnit: USNGGrid.LabelUnit = .kilometersMeters
        
        /// The units used for labeling the MGRS grid.
        @State private var mgrsLabelUnit: MGRSGrid.LabelUnit = .kilometersMeters
        
        var body: some View {
            Form {
                Section("Grid Line Settings") {
                    Picker("Grid Type", selection: $gridType) {
                        ForEach(GridType.allCases, id: \.self) { type in
                            Text(type.label)
                        }
                    }
                    .onChange(of: gridType) { _ in
                        grid = gridType.makeGrid()
                        updateUI()
                    }
                    
                    Toggle("Visible", isOn: $gridIsVisible)
                        .onChange(of: gridIsVisible) { _ in
                            grid.isVisible = gridIsVisible
                        }
                    
                    ColorPicker("Color", selection: $gridColor)
                        .onChange(of: gridColor) { _ in
                            changeGridColor(to: UIColor(gridColor))
                        }
                }
                
                Section("Labels Settings") {
                    Toggle("Visible", isOn: $labelsAreVisible)
                        .onChange(of: labelsAreVisible) { _ in
                            grid.labelsAreVisible = labelsAreVisible
                        }
                    
                    ColorPicker("Color", selection: $labelsColor)
                        .onChange(of: labelsColor) { _ in
                            changeLabelColor(to: UIColor(labelsColor))
                        }
                    
                    Picker("Position", selection: $labelPosition) {
                        ForEach(Grid.LabelPosition.allCases, id: \.self) { position in
                            Text(position.label)
                        }
                    }
                    .onChange(of: labelPosition) { _ in
                        grid.labelPosition = labelPosition
                    }
                    
                    if grid is LatitudeLongitudeGrid {
                        Picker("Format", selection: $labelFormat) {
                            ForEach(LatitudeLongitudeGrid.LabelFormat.allCases, id: \.self) { format in
                                Text(format.label)
                            }
                        }
                        .onChange(of: labelFormat) { _ in
                            (grid as! LatitudeLongitudeGrid).labelFormat = labelFormat
                        }
                    } else if grid is MGRSGrid {
                        Picker("Unit", selection: $mgrsLabelUnit) {
                            ForEach(MGRSGrid.LabelUnit.allCases, id: \.self) { unit in
                                Text(unit.label)
                            }
                        }
                        .onChange(of: mgrsLabelUnit) { _ in
                            (grid as! MGRSGrid).labelUnit = mgrsLabelUnit
                        }
                    } else if grid is USNGGrid {
                        Picker("Unit", selection: $usngLabelUnit) {
                            ForEach(USNGGrid.LabelUnit.allCases, id: \.self) { unit in
                                Text(unit.label)
                            }
                        }
                        .onChange(of: usngLabelUnit) { _ in
                            (grid as! USNGGrid).labelUnit = usngLabelUnit
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
            .onAppear {
                updateUI()
            }
        }
        
        /// Update states and UI based on grid properties.
        private func updateUI() {
            gridIsVisible = grid.isVisible
            if let lineSymbolColor = (grid.lineSymbols.first { $0 is LineSymbol } as? LineSymbol)?.color {
                gridColor = Color(uiColor: lineSymbolColor)
            }
            gridType = GridType(grid: grid)!
            labelsAreVisible = grid.labelsAreVisible
            if let textSymbolColor = (grid.textSymbols.first { $0 is TextSymbol } as? TextSymbol)?.color {
                labelsColor = Color(uiColor: textSymbolColor)
            }
            labelPosition = grid.labelPosition
            if grid is LatitudeLongitudeGrid {
                labelFormat = (grid as! LatitudeLongitudeGrid).labelFormat
            } else if grid is MGRSGrid {
                mgrsLabelUnit = (grid as! MGRSGrid).labelUnit
            } else if grid is USNGGrid {
                usngLabelUnit = (grid as! USNGGrid).labelUnit
            }
        }
        
        /// Changes the grid line color.
        /// - Parameter color: The color for the grid lines.
        private func changeGridColor(to color: UIColor) {
            for symbol in grid.lineSymbols where symbol is LineSymbol {
                let lineSymbol = symbol as! LineSymbol
                lineSymbol.color = color
            }
        }
        
        /// Changes the grid labels color.
        /// - Parameter color: The color for the text symbols.
        private func changeLabelColor(to color: UIColor) {
            for symbol in grid.textSymbols where symbol is TextSymbol {
                let textSymbol = symbol as! TextSymbol
                textSymbol.color = color
            }
        }
    }
}

// MARK: - Helper Extensions

private extension ShowGridView {
    /// The kinds of grid to show in a map view.
    enum GridType: CaseIterable {
        case latLon, mgrs, usng, utm
        
        init?(grid: ArcGIS.Grid) {
            switch grid {
            case is LatitudeLongitudeGrid: self = .latLon
            case is MGRSGrid: self = .mgrs
            case is USNGGrid: self = .usng
            case is UTMGrid: self = .utm
            default: return nil
            }
        }
        
        var label: String {
            switch self {
            case .latLon: "Latitude-Longitude"
            case .mgrs: "MGRS"
            case .usng: "USNG"
            case .utm: "UTM"
            }
        }
        
        func makeGrid() -> ArcGIS.Grid {
            switch self {
            case .latLon: LatitudeLongitudeGrid()
            case .mgrs: MGRSGrid()
            case .usng: USNGGrid()
            case .utm: UTMGrid()
            }
        }
    }
}

private extension ArcGIS.Grid.LabelPosition {
    static var allCases: [Self] = [
        .allSides,
        .center,
        .topLeft,
        .topRight,
        .bottomLeft,
        .bottomRight,
        .geographic
    ]
    
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
    static var allCases: [Self] = [.decimalDegrees, .degreesMinutesSeconds]
    
    var label: String {
        switch self {
        case .decimalDegrees: "Decimal Degrees"
        case .degreesMinutesSeconds: "Degrees, Minutes, Seconds"
        @unknown default: fatalError("Unknown Lat-Lon grid label format")
        }
    }
}

private extension MGRSGrid.LabelUnit {
    static var allCases: [Self] = [.kilometersMeters, .meters]
    
    var label: String {
        switch self {
        case .kilometersMeters: "Kilometers or Meters"
        case .meters: "Meters"
        @unknown default: fatalError("Unknown MGRS grid label unit")
        }
    }
}

private extension USNGGrid.LabelUnit {
    static var allCases: [Self] = [.kilometersMeters, .meters]
    
    var label: String {
        switch self {
        case .kilometersMeters: "Kilometers or Meters"
        case .meters: "Meters"
        @unknown default: fatalError("Unknown USNG grid label unit")
        }
    }
}

// MARK: - Preview

#Preview {
    ShowGridView()
}
