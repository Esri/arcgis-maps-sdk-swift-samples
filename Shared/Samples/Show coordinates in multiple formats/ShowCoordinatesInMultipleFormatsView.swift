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

struct ShowCoordinatesInMultipleFormatsView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        VStack {
            // Different coordinate format text fields.
            CoordinateTextField(
                title: "Decimal Degrees",
                text: $model.latLongDDTextField)
            CoordinateTextField(
                title: "Degrees, Minutes, Seconds",
                text: $model.latLongDMSTextField)
            CoordinateTextField(
                title: "UTM",
                text: $model.utmTextField)
            CoordinateTextField(
                title: "USNG",
                text: $model.usngTextField)
            
            // Create a map view to display the map.
            MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
                .onSingleTapGesture { _, mapPoint in
                    model.mapPoint = mapPoint
                    model.pointGraphic.geometry = mapPoint
                    model.updateCoordinateFieldsForPoint()
                }
        }
    }
}

struct CoordinateTextField: View {
    /// The TextField title.
    var title: String
    
    /// The TextField text.
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .padding([.leading, .top], 8)
                .padding(.bottom, -5)
            TextField("", text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .textFieldStyle(.roundedBorder)
                .padding([.leading, .trailing, .bottom], 8)
        }
    }
}

private extension ShowCoordinatesInMultipleFormatsView {
    // The view model for the sample.
    private class Model: ObservableObject {
        /// A map with an imagery basemap.
        var map = Map(basemapStyle: .arcGISImageryStandard)
        
        /// The GraphicsOverlay for the point graphic.
        lazy var graphicsOverlay = GraphicsOverlay(graphics: [pointGraphic])
        
        /// The yellow cross Graphic for the map point.
        lazy var pointGraphic: Graphic = {
            let yellowCrossSymbol = SimpleMarkerSymbol(style: .cross, color: .yellow, size: 20)
            return Graphic(geometry: mapPoint, symbol: yellowCrossSymbol)
        }()
        
        /// The point on the map.
        @Published var mapPoint = Point(latitude: 0, longitude: 0)
        
        ///
        @Published var latLongDDTextField = ""
        
        ///
        @Published var latLongDMSTextField = ""
        
        ///
        @Published var utmTextField = ""
        
        ///
        @Published var usngTextField = ""
        
        init() {
            updateCoordinateFieldsForPoint()
        }
        
        // Use CoordinateFormatter to generate a string for the given point.
        func updateCoordinateFieldsForPoint() {
            latLongDDTextField = CoordinateFormatter.latitudeLongitudeString(from: mapPoint, format: .decimalDegrees, decimalPlaces: 4)
            
            latLongDMSTextField = CoordinateFormatter.latitudeLongitudeString(from: mapPoint, format: .degreesMinutesSeconds, decimalPlaces: 1)
            
            utmTextField = CoordinateFormatter.utmString(from: mapPoint, conversionMode: .latitudeBandIndicators, addSpaces: true)
            
            usngTextField = CoordinateFormatter.usngString(from: mapPoint, precision: 4, addSpaces: true)
        }
    }
}
