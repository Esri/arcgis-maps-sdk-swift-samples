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
                text: $model.latLongDDString
            )
            .onSubmit {
                model.updateMapPoint(
                    point: CoordinateFormatter.point(
                        fromLatitudeLongitudeString: model.latLongDDString,
                        spatialReference: model.mapPoint.spatialReference
                    )!)
            }
            CoordinateTextField(
                title: "Degrees, Minutes, Seconds",
                text: $model.latLongDMSString
            )
            .onSubmit {
                model.updateMapPoint(
                    point: CoordinateFormatter.point(
                        fromLatitudeLongitudeString: model.latLongDMSString,
                        spatialReference: model.mapPoint.spatialReference
                    )!)
            }
            CoordinateTextField(
                title: "UTM",
                text: $model.utmString
            )
            .onSubmit {
                model.updateMapPoint(
                    point: CoordinateFormatter.point(
                        fromUTMString: model.utmString,
                        spatialReference: model.mapPoint.spatialReference,
                        conversionMode: .latitudeBandIndicators
                    )!)
            }
            CoordinateTextField(
                title: "USNG",
                text: $model.usngString
            )
            .onSubmit {
                model.updateMapPoint(
                    point: CoordinateFormatter.point(
                        fromUSNGString: model.usngString,
                        spatialReference: model.mapPoint.spatialReference
                    )!)
            }
            
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
        var map: Map
        
        /// The graphics overlay for the point graphic.
        let graphicsOverlay: GraphicsOverlay
        
        /// A yellow cross graphic for the map point.
        private let pointGraphic: Graphic
        
        /// The point on the map.
        @Published var mapPoint: Point!
        
        /// The decimal degrees text.
        @Published var latLongDDString = ""
        
        /// The degree minute seconds text.
        @Published var latLongDMSString = ""
        
        /// The UTM text.
        @Published var utmString = ""
        
        /// the USNG text.
        @Published var usngString = ""
        
        init() {
            map = Map(basemapStyle: .arcGISImageryStandard)
            pointGraphic = Graphic(symbol: SimpleMarkerSymbol(style: .cross, color: .yellow, size: 20))
            graphicsOverlay = GraphicsOverlay(graphics: [pointGraphic])
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
            latLongDDString = CoordinateFormatter.latitudeLongitudeString(
                from: mapPoint,
                format: .decimalDegrees,
                decimalPlaces: 4
            )
            
            latLongDMSString = CoordinateFormatter.latitudeLongitudeString(
                from: mapPoint,
                format: .degreesMinutesSeconds,
                decimalPlaces: 1)
            
            utmString = CoordinateFormatter.utmString(
                from: mapPoint,
                conversionMode: .latitudeBandIndicators,
                addSpaces: true)
            
            usngString = CoordinateFormatter.usngString(
                from: mapPoint,
                precision: 4,
                addSpaces: true)
        }
    }
}
