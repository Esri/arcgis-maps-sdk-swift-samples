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

struct FindClosestFacilityToMultiplePointsView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        MapView(map: model.map)
            .alert(isPresented: $model.isShowingErrorAlert, presentingError: model.error)
    }
}

private extension FindClosestFacilityToMultiplePointsView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A map with a topographic basemap.
        let map = Map(basemapStyle: .arcGISTopographic)
        
        /// A Boolean value indicating whether to show an error alert.
        @Published var isShowingErrorAlert = false
        
        /// The error shown in the error alert.
        @Published var error: Error? {
            didSet { isShowingErrorAlert = error != nil }
        }
    }
}
