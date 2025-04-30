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
        // Make a new map with an oceans basemap style.
        let map = Map(basemapStyle: .arcGISOceans)
        
        // Make the hurricanes feature layer with no offset.
        let noOffsetLayer = FeatureLayer(featureTable: ServiceFeatureTable(url: .hurricanesService))
        
        // Apply a blue dot renderer to distinguish hurricanes without offset.
        noOffsetLayer.renderer = SimpleRenderer(symbol: SimpleMarkerSymbol(style: .circle, color: .blue, size: 10))
        
        // Add the non-offset layer to the map.
        map.addOperationalLayer(noOffsetLayer)
        
        // Make the offset hurricanes feature layer.
        let withOffsetLayer = FeatureLayer(featureTable: ServiceFeatureTable(url: .hurricanesService))
        
        // Apply a red dot renderer to distinguish the hurricanes with an offset.
        withOffsetLayer.renderer = SimpleRenderer(symbol: SimpleMarkerSymbol(style: .circle, color: .red, size: 10))
        
        // Set the time offset on the layer.
        withOffsetLayer.timeOffset = TimeValue(duration: 10.0, unit: .days)
        
        // Add the offset layer to the map.
        map.addOperationalLayer(withOffsetLayer)
        
        // Set the initial viewpoint of the map.
        map.initialViewpoint = Viewpoint(
            latitude: 45.0,
            longitude: -45.0,
            scale: 9e7
        )
        
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
        Calendar.current.dateComponents(
            [.day],
            from: Date.august4th2000,
            to: Date.october22nd2000
        ).day!
    )
    
    /// The format style used to display the extent dates.
    private let dateFormat = Date.FormatStyle(date: .numeric, time: .omitted)
    
    var body: some View {
        VStack {
            MapView(map: map, timeExtent: $timeExtent)
            Text("Red hurricanes offset 10 days")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.red)
            Text("Blue hurricanes not offset")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            Slider(value: $sliderValue, in: 0...sliderMaxValue, step: 1)
                .padding(.leading)
                .padding(.trailing)
            Text("\(timeExtent?.startDate?.formatted(dateFormat) ?? "") - \(timeExtent?.endDate?.formatted(dateFormat) ?? "")")
        }
        .onChange(of: sliderValue) {
            // Calculate a new time extent when the slider value changes.
            guard let newStartDate = Calendar.current.date(byAdding: .day, value: Int(sliderValue), to: .august4th2000),
                  let newEndDate = Calendar.current.date(byAdding: .day, value: 10, to: newStartDate) else {
                return
            }
            timeExtent = TimeExtent(startDate: newStartDate, endDate: newEndDate)
        }
    }
}

private extension URL {
    static let hurricanesService = URL(
        string: "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Hurricanes/MapServer/0"
    )!
}

extension Date {
    static let august4th2000 = Calendar.current.date(from: DateComponents(year: 2000, month: 8, day: 4))!
    static let october22nd2000 = Calendar.current.date(from: DateComponents(year: 2000, month: 10, day: 22))!
}

#Preview {
    AddFeatureLayerWithTimeOffsetView()
}
