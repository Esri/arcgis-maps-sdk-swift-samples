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

struct AddFeaturesWithContingentValuesView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapView(map: model.map)
            .errorAlert(presentingError: $error)
    }
}

private extension AddFeaturesWithContingentValuesView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A map with a topographic basemap.
        let map = Map(basemapStyle: .arcGISTopographic)
    }
}

private extension URL {
    /// A URL to the local "Contingent Values Bird Nests" geodatabase.
    static var contingentValuesBirdNests: URL {
        Bundle.main.url(forResource: "ContingentValuesBirdNests", withExtension: "geodatabase")!
    }
    
    /// A URL to the local "Fillmore Topographic Map" vector tile package.
    static var fillmoreTopographicMap: URL {
        Bundle.main.url(forResource: "FillmoreTopographicMap", withExtension: "vtpk")!
    }
}

#Preview {
    AddFeaturesWithContingentValuesView()
}
