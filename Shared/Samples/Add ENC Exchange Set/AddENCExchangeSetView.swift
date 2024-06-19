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


struct AddENCExchangeSetView: View {
    @State private var isLoading = false
    @StateObject private var model = Model()
    
    var body: some View {
        MapViewReader { mapProxy in
            MapView(map: model.map)
                .overlay(alignment: .center) {
                    if isLoading {
                        ProgressView("Loading...")
                            .padding()
                            .background(.ultraThickMaterial)
                            .cornerRadius(10)
                            .shadow(radius: 50)
                    }
                }
                .task {
                    do {
                        try await model.addENCExchangeSet()
                    } catch {
                        print(error)
                    }
                }
        }
    }
}

private extension AddENCExchangeSetView {
    @MainActor
    class Model: ObservableObject {
        /// A map with viewpoint set to Amberg, Germany.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISOceans)
            map.initialViewpoint = Viewpoint(
                latitude: -32.5,
                longitude: 60.95,
                scale: 125_00
            )
            return map
        }()
        
        func addENCExchangeSet() async throws {
            print(URL.exchangeSet.absoluteString)
            let exchangeSet = ENCExchangeSet(fileURLs: [.exchangeSet])
            try await exchangeSet.load()
            let result = exchangeSet.loadStatus
            switch result {
            case .loaded:
                print(exchangeSet.datasets)
                
            case .failed:
                print("failed")
            case .notLoaded:
                print("not loaded")
            case .loading:
                print("loading")
            }
        }
    }
}

private extension URL {
    static let exchangeSet = Bundle.main.url(forResource: "CATALOG", withExtension: "031", subdirectory: "ExchangeSetwithoutUpdates/ExchangeSetwithoutUpdates/ENC_ROOT")!
}

#Preview {
    AddENCExchangeSetView()
}
