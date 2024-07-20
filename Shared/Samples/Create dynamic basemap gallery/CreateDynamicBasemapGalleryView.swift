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

struct CreateDynamicBasemapGalleryView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether the basemap gallery is showing.
    @State private var isShowingBasemapGallery = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        MapView(map: model.map)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Basemap") {
                        isShowingBasemapGallery.toggle()
                    }
                    .popover(isPresented: $isShowingBasemapGallery) {
                        NavigationStack {
                            BasemapGallery(model: model)
                                .navigationTitle("Basemap")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button("Done") { isShowingBasemapGallery = false }
                                    }
                                }
                        }
                        .presentationDetents([.fraction(0.5)])
                        .frame(idealWidth: 320, idealHeight: 380)
                    }
                }
            }
            .task {
                do {
                    try await model.loadStylesInfo()
                } catch {
                    self.error = error
                }
            }
            .errorAlert(presentingError: $error)
    }
}

extension CreateDynamicBasemapGalleryView {
    /// The view model for the sample.
    @MainActor
    final class Model: ObservableObject {
        /// The map shown in the map view.
        let map = Map()
        
        /// The basemap style of the map's basemap.
        @Published var basemapStyle = Basemap.Style.arcGISNavigation {
            didSet {
                guard basemapStyle != oldValue else { return }
                
                basemapStyleLanguage = .strategic(.default)
                worldviewCode = nil
                basemapStyleInfo = stylesInfo.first { $0.style == basemapStyle }
                
                updateBasemap()
            }
        }
        
        /// The basemap style language of the map's basemap.
        @Published var basemapStyleLanguage = BasemapStyleLanguage.strategic(.default) {
            didSet {
                guard basemapStyleLanguage != oldValue else { return }
                updateBasemap()
            }
        }
        
        /// The worldview code of the map's basemap.
        @Published var worldviewCode: String? {
            didSet {
                guard worldviewCode != oldValue else { return }
                updateBasemap()
            }
        }
        
        /// The basemap styles info from the basemap styles service.
        @Published private(set) var stylesInfo: [BasemapStyleInfo] = []
        
        /// The basemap style info for the basemap style.
        @Published private(set) var basemapStyleInfo: BasemapStyleInfo?
        
        /// The basemap style language strategy options for the basemap style info.
        var languageStrategies: [BasemapStyleLanguageStrategy] {
            return [.default] + (basemapStyleInfo?.languageStrategies ?? [])
        }
        
        /// The language options for the basemap style info.
        var languages: [Locale.Language] {
            basemapStyleInfo?.languages ?? []
        }
        
        /// The worldview options for the basemap style info.
        var worldviews: [Worldview?] {
            return [nil] + (basemapStyleInfo?.worldviews ?? [])
        }
        
        init() {
            map.basemap = Basemap(style: basemapStyle)
            map.initialViewpoint = Viewpoint(latitude: 52.3433, longitude: -1.5796, scale: 25e5)
        }
        
        /// Loads the styles info from the basemap styles service.
        func loadStylesInfo() async throws {
            let service = BasemapStylesService()
            try await service.load()
            
            guard let info = service.info else { return }
            stylesInfo = info.stylesInfo
            basemapStyleInfo = stylesInfo.first { $0.style == basemapStyle }
            
            // Loads the styles info thumbnails.
            await stylesInfo.compactMap(\.thumbnail).load()
        }
        
        /// Updates the map's basemap with the `basemapStyle`, `basemapStyleLanguage` and `worldviewCode`.
        private func updateBasemap() {
            let basemapStyleParameters = BasemapStyleParameters(language: basemapStyleLanguage)
            basemapStyleParameters.worldview = if let worldviewCode {
                Worldview(code: worldviewCode)
            } else {
                nil
            }
            
            map.basemap = Basemap(style: basemapStyle, parameters: basemapStyleParameters)
        }
    }
}

#Preview {
    NavigationStack {
        CreateDynamicBasemapGalleryView()
    }
}
