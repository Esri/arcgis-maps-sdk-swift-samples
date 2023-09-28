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

struct Animate3DGraphicView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        SceneView(scene: model.scene)
            .alert(isPresented: $model.isShowingErrorAlert, presentingError: model.error)
    }
}

private extension Animate3DGraphicView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A scene with an imagery basemap.
        let scene: ArcGIS.Scene = {
            let scene = Scene(basemapStyle: .arcGISImagery)
            
            // Set the scene's base surface with an elevation source.
            let surface = Surface()
            let elevationSource = ArcGISTiledElevationSource(url: .worldElevationService)
            surface.addElevationSource(elevationSource)
            scene.baseSurface = surface
            
            return scene
        }()
        
        /// A Boolean that indicates whether to show an error alert.
        @Published var isShowingErrorAlert = false
        
        /// The error shown in the alert.
        @Published var error: Error? {
            didSet { isShowingErrorAlert = error != nil }
        }
    }
}

private extension URL {
    /// A URL to world elevation service from Terrain3D ArcGIS REST service.
    static var worldElevationService: URL {
        URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!
    }
    
    /// A URL to the local Bristol 3D model files.
    static var bristol: URL {
        Bundle.main.url(forResource: "Bristol", withExtension: "dae", subdirectory: "Bristol")!
    }
    
    /// A URL to the local CSV file containing data for a route through the Grand Canyon.
    static var grandCanyon: URL {
        Bundle.main.url(forResource: "GrandCanyon", withExtension: "csv")!
    }
    
    /// A URL to the local CSV file containing data for a route in Hawaii.
    static var hawaii: URL {
        Bundle.main.url(forResource: "Hawaii", withExtension: "csv")!
    }
    
    /// A URL to the local CSV file containing data for a route through the Pyrenees.
    static var pyrenees: URL {
        Bundle.main.url(forResource: "Pyrenees", withExtension: "csv")!
    }
    
    /// A URL to the local CSV file containing data for a route near Mount Snowdon.
    static var snowdon: URL {
        Bundle.main.url(forResource: "Snowdon", withExtension: "csv")!
    }
}
