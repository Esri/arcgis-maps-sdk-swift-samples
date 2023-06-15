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

struct DisplayMapFromPortalItemView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    @State private var isShowingMapsSheet = false
    
    var body: some View {
        MapView(map: model.map)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Maps") {
                        isShowingMapsSheet = true
                    }
                }
            }
            .sheet(isPresented: $isShowingMapsSheet, detents: [.medium], dragIndicatorVisibility: .visible) {
                List {
                    ForEach(model.mapOptions, id: \.portalID) { mapOption in
                        Button {
                            model.map = Map(url: mapOption.url!)!
                        } label: {
                            Text(mapOption.title)
                        }
                    }
                }
            }
            .alert(isPresented: $model.isShowingAlert, presentingError: model.error)
    }
}

private extension DisplayMapFromPortalItemView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A map of the Santa Barbara Botanic Garden.
        var map: Map
        
        let mapOptions: [MapAtURL] = [
            MapAtURL(title: "Terrestrial Ecosystems of the World",
                     thumbnailImage: UIImage(named: "OpenMapURLThumbnail1")!,
                     portalID: "5be0bc3ee36c4e058f7b3cebc21c74e6"),
            MapAtURL(title: "Recent Hurricanes, Cyclones and Typhoons",
                     thumbnailImage: UIImage(named: "OpenMapURLThumbnail2")!,
                     portalID: "064f2e898b094a17b84e4a4cd5e5f549"),
            MapAtURL(title: "Geology of United States",
                     thumbnailImage: UIImage(named: "OpenMapURLThumbnail3")!,
                     portalID: "92ad152b9da94dee89b9e387dfe21acd")
        ]
        
        /// A Boolean value indicating whether to show an alert.
        @Published var isShowingAlert = false
        
        /// The error shown in the alert.
        @Published var error: Error? {
            didSet { isShowingAlert = error != nil }
        }
        
        init() {
            map = Map(url: mapOptions.first!.url!)!
        }
    }
    
    /// A model for the maps the user may toggle between.
    struct MapAtURL {
        var title: String
        var thumbnailImage: UIImage
        var portalID: String
        
        var url: URL? {
            return URL(string: "https://www.arcgis.com/home/item.html?id=\(portalID)")
        }
    }
}
