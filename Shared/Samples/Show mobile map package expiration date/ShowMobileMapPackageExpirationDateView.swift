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
    
    /// The mobile map package created from a URL to a local mobile map package file.
    @State private var mapPackage = MobileMapPackage(fileURL: .lothianRiversAnno)
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        ZStack {
            MapView(map: map)
                .task {
                    do {
                        // Set the map to the first map in the mobile map package.
                        try await mapPackage.load()
                        if let map = mapPackage.maps.first {
                            self.map = map
                        }
                    } catch {
                        self.error = error
                    }
                }
            
            // Display the expiration message and date if the map package is expired.
            if let expiration = mapPackage.expiration, expiration.isExpired {
                VStack {
                    Text(expiration.message)
                    Text("Expiration date: \(expiration.date?.formatted() ?? "N/A")")
                        .padding(.top)
                }
                .multilineTextAlignment(.center)
                .padding()
                .background(.thinMaterial)
            }
        }
        .errorAlert(presentingError: $error)
    }
}

private extension URL {
    /// The URL to the local Lothian Rivers Anno mobile map package file.
    static var lothianRiversAnno: URL {
        Bundle.main.url(forResource: "LothianRiversAnno", withExtension: "mmpk")!
    }
}
