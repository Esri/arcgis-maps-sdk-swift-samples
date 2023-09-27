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

struct DisplayDimensionsView: View {
    /// A map with no specified style.
    @State private var map = Map()
    
    /// The mobile map package created from a URL to a local mobile map package file.
    @State private var mapPackage: MobileMapPackage!
    
    /// A Boolean that indicates whether to show an error alert.
    @State private var isShowingErrorAlert = false
    
    /// The error shown in the error alert.
    @State private var error: Error? {
        didSet { isShowingErrorAlert = error != nil }
    }
    
    var body: some View {
        MapView(map: map)
            .task {
                do {
                    // Load the local mobile map package using a URL.
                    mapPackage = MobileMapPackage(fileURL: .edinburghPylonDimensions)
                    try await mapPackage.load()
                    
                    // Set the map to the first map in the mobile map package.
                    if let map = mapPackage.maps.first {
                        self.map = map
                    } else {
                        fatalError("MMPK doesn't contain a map.")
                    }
                } catch {
                    self.error = error
                }
            }
            .alert(isPresented: $isShowingErrorAlert, presentingError: error)
    }
}

private extension URL {
    /// The URL to the local Edinburgh Pylon Dimensions mobile map package file.
    static var edinburghPylonDimensions: URL {
        Bundle.main.url(forResource: "Edinburgh_Pylon_Dimensions", withExtension: "mmpk")!
    }
}
