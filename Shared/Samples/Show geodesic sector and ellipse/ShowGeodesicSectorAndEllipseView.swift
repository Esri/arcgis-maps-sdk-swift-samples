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

struct ShowGeodesicSectorAndEllipseView: View {
    /// The error shown in the error alert.
    @State private var error: Error?
    @State private var model = Model()
    
    var body: some View {
        MapView(map: model.map)
            .onSingleTapGesture { _, mapPoint in
                
            }
            .errorAlert(presentingError: $error)
    }
    
}

private extension ShowGeodesicSectorAndEllipseView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    class Model: ObservableObject {
        @State var map = Map(basemapStyle: .arcGISImageryStandard)
        @State var sectorParameters : GeodesicSectorParameters? = nil
        @State var ellipseParameters : GeodesicEllipseParameters? = nil
        @State var overlay = GraphicsOverlay()
        
        init() {
            //                let geometry = GeometryEngine.geodesicEllipse(parameters: model.ellipseParameters!)
            //                let overlay = GraphicsOverlay(graphics: [Graphic(geometry: geometry)])
        }
    }
}

#Preview {
    ShowGeodesicSectorAndEllipseView()
}
