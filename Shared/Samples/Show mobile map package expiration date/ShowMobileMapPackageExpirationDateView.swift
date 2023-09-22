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

struct ShowMobileMapPackageExpirationDateView: View {
    /// A map with no specified style.
    @State private var map = Map()
    
    /// The mobile map package.
    @State private var mobileMapPackage: MobileMapPackage!
    
    var body: some View {
        MapView(map: map)
            .task {
                // Load the local mobile map package from a URL.
                mobileMapPackage = MobileMapPackage(fileURL: .lothianRiversAnno)
                try? await mobileMapPackage.load()
                
                // Gets the first map in the mobile map package.
                if let map = mobileMapPackage.maps.first {
                    self.map = map
                }
            }
    }
}

private extension URL {
    /// The URL to the local Lothian Rivers Anno mobile map package file.
    static var lothianRiversAnno: URL {
        Bundle.main.url(forResource: "LothianRiversAnno", withExtension: "mmpk")!
    }
}
