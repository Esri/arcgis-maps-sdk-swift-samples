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
import SwiftUI

struct DisplayMapFromMobileMapPackageView: View {
    /// A Boolean value indicating whether to show an alert.
    @State private var isShowingAlert = false
    
    /// The error shown in the alert.
    @State private var error: Error? {
        didSet { isShowingAlert = error != nil }
    }
    
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        MapView(map: model.map)
            .task {
                do {
                    try await model.loadMobileMapPackage()
                } catch {
                    // Presents an error message if the map fails to load.
                    self.error = error
                }
            }
            .alert(isPresented: $isShowingAlert, presentingError: error)
    }
}

extension DisplayMapFromMobileMapPackageView {
    private class Model: ObservableObject {
        /// A map with no specified style.
        var map = Map()
        
        /// The mobile map package.
        private var mobileMapPackage: MobileMapPackage!
        
        /// Loads a local mobile map package.
        func loadMobileMapPackage() async throws {
            // Loads the local mobile map package.
            let yellowstoneURL = Bundle.main.url(forResource: "Yellowstone", withExtension: "mmpk")!
            mobileMapPackage = MobileMapPackage(fileURL: yellowstoneURL)
            try await mobileMapPackage.load()
            // Gets the first map in the mobile map package.
            guard let map = mobileMapPackage.maps.first else { return }
            self.map = map
        }
    }
}
