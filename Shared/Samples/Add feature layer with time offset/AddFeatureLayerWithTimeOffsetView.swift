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

struct AddFeatureLayerWithTimeOffsetView: View {
    /// A map with an oceans basemap and hurricane layers.
    @State private var map: Map = {
        // Makes a new map with an oceans basemap style.
        let map = Map(basemapStyle: .arcGISOceans)
        
        // Makes the hurricanes feature layer with no offset.
        let noOffsetLayer = FeatureLayer(featureTable: ServiceFeatureTable(url: .hurricanesService))
        
        // Applies a blue dot renderer to distinguish hurricanes without offset.
        noOffsetLayer.renderer = SimpleRenderer(symbol: SimpleMarkerSymbol(style: .circle, color: .blue, size: 10))
        
        // Makes the offset hurricanes feature layer.
        let withOffsetLayer = FeatureLayer(featureTable: ServiceFeatureTable(url: .hurricanesService))
        
        // Applies a red dot renderer to distinguish the hurricanes with an offset.
        withOffsetLayer.renderer = SimpleRenderer(symbol: SimpleMarkerSymbol(style: .circle, color: .red, size: 10))
        
        // Sets the time offset on the layer.
        withOffsetLayer.timeOffset = TimeValue(duration: 10.0, unit: .days)
        
        // Adds the layers to the map.
        map.addOperationalLayers([noOffsetLayer, withOffsetLayer])
        
        // Sets the initial viewpoint of the map.
        map.initialViewpoint = Viewpoint(latitude: 45.0, longitude: -45.0, scale: 9e7)
        
        return map
    }()
    
    /// The time extent of the map view.
    @State private var timeExtent: TimeExtent? = TimeExtent(
        startDate: .august4th2000,
        endDate: Calendar.current.date(byAdding: .day, value: 10, to: .august4th2000)
    )
    
    /// The value of the slider.
    @State private var sliderValue = 0.0
    
    /// The maximum value of the slider.
    private let sliderMaxValue = Double(
        Calendar.current.dateComponents([.day], from: Date.august4th2000, to: Date.october22nd2000).day!
    )
    
    /// The format style used to display the extent dates.
    private let dateFormat = Date.FormatStyle(date: .numeric, time: .omitted)
    
    var body: some View {
        MapView(map: map, timeExtent: $timeExtent)
            .overlay(alignment: .topTrailing) {
                VStack(alignment: .leading) {
                    Text("Hurricane Data Offset:")
                    LabeledContent {
                        Text("10 days")
                    } label: {
                        Text("Red").foregroundStyle(.red)
                    }
                    LabeledContent {
                        Text("No offset")
                    } label: {
                        Text("Blue").foregroundStyle(.blue)
                    }
                }
                .fixedSize()
                .padding()
                .background(.thinMaterial)
                .clipShape(.rect(cornerRadius: 10))
                .shadow(radius: 50)
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    VStack {
                        Slider(value: $sliderValue, in: 0...sliderMaxValue, step: 1)
                            .padding(.horizontal)
                            .onChange(of: sliderValue) {
                                // Calculates a new time extent when the slider value changes.
                                guard let newStartDate = Calendar.current.date(
                                        byAdding: .day,
                                        value: Int(sliderValue),
                                        to: .august4th2000
                                      ),
                                      let newEndDate = Calendar.current.date(
                                        byAdding: .day,
                                        value: 10,
                                        to: newStartDate
                                      ) else {
                                    return
                                }
                                timeExtent = TimeExtent(startDate: newStartDate, endDate: newEndDate)
                            }
                        Text(
                            """
                            \(timeExtent?.startDate?.formatted(dateFormat) ?? "") - \
                            \(timeExtent?.endDate?.formatted(dateFormat) ?? "")
                            """
                        )
                    }
                }
            }
    }
}

private extension URL {
    static let hurricanesService = URL(
        string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Hurricanes/MapServer/0"
    )!
}

private extension Date {
    static let august4th2000 = Calendar.current.date(from: DateComponents(year: 2000, month: 8, day: 4))!
    static let october22nd2000 = Calendar.current.date(from: DateComponents(year: 2000, month: 10, day: 22))!
}

#Preview {
    AddFeatureLayerWithTimeOffsetView()
}
