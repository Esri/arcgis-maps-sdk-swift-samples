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
        // Input text fields.
        VStack {
            CoordinateTextField(
                title: "Decimal Degrees",
                text: $model.latLongDDTextField
            )
            .onSubmit {
                model.updateMapPoint(
                    point: CoordinateFormatter.point(
                        fromLatitudeLongitudeString: model.latLongDDTextField,
                        spatialReference: model.mapPoint.spatialReference
                    )!)
            }
            CoordinateTextField(
                title: "Degrees, Minutes, Seconds",
                text: $model.latLongDMSTextField
            )
            .onSubmit {
                model.updateMapPoint(
                    point: CoordinateFormatter.point(
                        fromLatitudeLongitudeString: model.latLongDMSTextField,
                        spatialReference: model.mapPoint.spatialReference
                    )!)
            }
            CoordinateTextField(
                title: "UTM",
                text: $model.utmTextField
            )
            .onSubmit {
                model.updateMapPoint(
                    point: CoordinateFormatter.point(
                        fromUTMString: model.utmTextField,
                        spatialReference: model.mapPoint.spatialReference,
                        conversionMode: .latitudeBandIndicators
                    )!)
            }
            CoordinateTextField(
                title: "USNG",
                text: $model.usngTextField
            )
            .onSubmit {
                model.updateMapPoint(
                    point: CoordinateFormatter.point(
                        fromUSNGString: model.usngTextField,
                        spatialReference: model.mapPoint.spatialReference
                    )!)
            }
            
            // Create a map view to display the map.
            MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
                .onSingleTapGesture { _, mapPoint in
                    model.updateMapPoint(point: mapPoint)
                }
        }
    }
}

struct CoordinateTextField: View {
    /// The title string.
    var title: String
    
    /// The text string.
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
    class Model: ObservableObject {
        /// A map with an imagery basemap.
        var map = Map(basemapStyle: .arcGISImageryStandard)
        
        /// The graphics overlay for the point graphic.
        lazy var graphicsOverlay = GraphicsOverlay(graphics: [pointGraphic])
        
        /// A yellow cross graphic for the map point.
        private var pointGraphic: Graphic = {
            let yellowCrossSymbol = SimpleMarkerSymbol(style: .cross, color: .yellow, size: 20)
            return Graphic(symbol: yellowCrossSymbol)
        }()
        
        /// The point on the map.
        @Published var mapPoint: Point!
        
        /// The decimal degrees text.
        @Published var latLongDDTextField = ""
        
        /// The degree minute seconds text.
        @Published var latLongDMSTextField = ""
        
        /// The UTM text.
        @Published var utmTextField = ""
        
        /// the USNG text.
        @Published var usngTextField = ""
        
        init() {
            updateMapPoint(point: Point(latitude: 0, longitude: 0))
        }
        
        /// Updates the mapPoint, its graphic, and the corresponding coordinates.
        /// - Parameter point: A `Point` used to update the mapPoint.
        func updateMapPoint(point: Point) {
            mapPoint = point
            pointGraphic.geometry = point
            updateCoordinateFields()
        }
        
        /// Generates strings for mapPoint using 'CoordinateFormatter'.
        private func updateCoordinateFields() {
            latLongDDTextField = CoordinateFormatter.latitudeLongitudeString(
                from: mapPoint,
                format: .decimalDegrees,
                decimalPlaces: 4
            )
            
            latLongDMSTextField = CoordinateFormatter.latitudeLongitudeString(
                from: mapPoint,
                format: .degreesMinutesSeconds,
                decimalPlaces: 1)
            
            utmTextField = CoordinateFormatter.utmString(
                from: mapPoint,
                conversionMode: .latitudeBandIndicators,
                addSpaces: true)
            
            usngTextField = CoordinateFormatter.usngString(
                from: mapPoint,
                precision: 4,
                addSpaces: true)
        }
    }
}
