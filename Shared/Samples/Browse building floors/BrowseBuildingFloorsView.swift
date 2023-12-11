// Copyright 2022 Esri
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
import ArcGISToolkit
import SwiftUI

struct BrowseBuildingFloorsView: View {
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The current viewpoint of the map.
    @State private var viewpoint: Viewpoint?
    
    /// A Boolean value indicating whether the map is being navigated.
    @State private var isMapNavigating = false
    
    /// A Boolean value indicating whether the map is loaded.
    @State private var isMapLoaded = false
    
    /// A floor-aware web map of Building L on the Esri Redlands campus.
    @State private var map = Map(
        item: PortalItem(
            portal: .arcGISOnline(connection: .anonymous),
            id: .esriBuildingL
        )
    )
    
    var body: some View {
        MapView(map: map)
            .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
            .onNavigatingChanged { isMapNavigating = $0 }
            .errorAlert(presentingError: $error)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .overlay(alignment: .bottomTrailing) {
                if isMapLoaded,
                   let floorManager = map.floorManager {
                    FloorFilter(
                        floorManager: floorManager,
                        alignment: .bottomTrailing,
                        viewpoint: $viewpoint,
                        isNavigating: $isMapNavigating
                    )
                    .frame(
                        maxWidth: 400,
                        maxHeight: 400
                    )
                    .padding(.toolkitDefault)
                    .padding(.bottom, 27)
                }
            }
            .task {
                do {
                    try await map.load()
                    isMapLoaded = true
                } catch {
                    self.error = error
                }
            }
    }
}

private extension PortalItem.ID {
    /// A portal item of Building L's floors on the Esri Redlands campus.
    static var esriBuildingL: Self { Self("f133a698536f44c8884ad81f80b6cfc7")! }
}

#Preview {
    BrowseBuildingFloorsView()
}
