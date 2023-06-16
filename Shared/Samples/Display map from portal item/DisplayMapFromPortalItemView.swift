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
    
    /// A Boolean indicating whether to show the map options sheet.
    @State private var isShowingMapOptions = false

    var body: some View {
        MapView(map: model.map)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Maps") {
                        isShowingMapOptions = true
                    }
                }
            }
            .sheet(isPresented: $isShowingMapOptions, detents: [.medium], dragIndicatorVisibility: .visible) {
                List {
                    ForEach(model.mapOptions) { mapOption in
                        Button {
                            model.currentMap = mapOption
                            model.map = Map(item: mapOption.portalItem)
                        } label: {
                            ZStack {
                                HStack {
                                    Image(uiImage: mapOption.thumbnailImage)
                                    Text(mapOption.title)
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .opacity(model.currentMap == mapOption ? 1 : 0)
                                }
                            }
                        }
                        .foregroundColor(.black)
                    }
                }
            }
    }
}

private extension DisplayMapFromPortalItemView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// TODO: rename images
        let mapOptions = [
            PortalItemMap(title: "Terrestrial Ecosystems of the World",
                          thumbnailImage: "OpenMapURLThumbnail1",
                          portalID: .terrestrialEcosystems),
            PortalItemMap(title: "Recent Hurricanes, Cyclones and Typhoons",
                          thumbnailImage: "OpenMapURLThumbnail2",
                          portalID: .hurricanesCyclonesTyphoons),
            PortalItemMap(title: "Geology of United States",
                          thumbnailImage: "OpenMapURLThumbnail3",
                          portalID: .usGeology)
        ]
        
        /// The map at URL of the current map.
        @Published var currentMap: PortalItemMap
        
        /// A map to display on the screen.
        @Published var map: Map
        
        init() {
            currentMap = mapOptions.first!
            map = Map(item: mapOptions.first!.portalItem)
        }
    }
    /// A model for the maps the user may toggle between.
    struct PortalItemMap: Equatable, Identifiable {
        let id = UUID()
        let title: String
        let thumbnailImage: UIImage
        let portalItem: PortalItem
        
        init(title: String, thumbnailImage: String, portalID: PortalItem.ID) {
            self.title = title
            self.thumbnailImage = UIImage(named: thumbnailImage)!
            self.portalItem = PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                id: portalID
            )
        }
        
        /// <#Description#>
        /// - Parameters:
        ///   - lhs: <#lhs description#>
        ///   - rhs: <#rhs description#>
        /// - Returns: <#description#>
        static func ==(lhs: PortalItemMap, rhs: PortalItemMap) -> Bool {
            return lhs.id == rhs.id
        }
    }
}

private extension PortalItem.ID {
    /// The portal item ID of the Terrestrial Ecosystems of the World map.
    static var terrestrialEcosystems: Self { Self("5be0bc3ee36c4e058f7b3cebc21c74e6")! }
    
    /// The portal item ID of the Recent Hurricanes, Cyclones and Typhoons map.
    static var hurricanesCyclonesTyphoons: Self { Self("064f2e898b094a17b84e4a4cd5e5f549")! }
    
    /// The portal item ID of the Geology of United States map.
    static var usGeology: Self { Self("92ad152b9da94dee89b9e387dfe21acd")! }
}
