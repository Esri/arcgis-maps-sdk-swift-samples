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

import SwiftUI
import ArcGIS
import ArcGISToolkit

struct SetUpLocationDrivenGeotriggersView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    
    var body: some View {
        MapView(map: model.map)
    }

private extension ShowLineOfSightBetweenPointsView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A map of the Santa Barbara Botanic Garden.
        let map = Map(item: PortalItem(
            portal: .arcGISOnline(connection: .anonymous),
            id: .santaBarbaraBotanicGardenMap
        ))
    }
}
