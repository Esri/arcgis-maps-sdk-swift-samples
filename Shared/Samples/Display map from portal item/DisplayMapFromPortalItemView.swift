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
    /// The current portal item map.
    @State private var currentMap = mapOptions.first!
    
    /// A map to display on the screen.
    @State private var map = Map(item: mapOptions.first!.portalItem)
    
    /// The different map options the user can choose from.
    private static let mapOptions = [
        PortalItemMap(
            title: "Terrestrial Ecosystems of the World",
            id: .terrestrialEcosystems
        ),
        PortalItemMap(
            title: "Recent Hurricanes, Cyclones and Typhoons",
            id: .hurricanesCyclonesTyphoons
        ),
        PortalItemMap(
            title: "Geology of United States",
            id: .usGeology
        )
    ]
    
    var body: some View {
        MapView(map: map)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Menu("Maps") {
                        Picker("Portal Item Map", selection: $currentMap) {
                            ForEach(DisplayMapFromPortalItemView.mapOptions) { mapOption in
                                Text(mapOption.title).tag(mapOption)
                            }
                        }
                        .onChange(of: currentMap) { _ in
                            map = Map(item: currentMap.portalItem)
                        }
                    }
                }
            }
    }
}

private extension DisplayMapFromPortalItemView {
    /// A model for the maps the user may toggle between.
    struct PortalItemMap: Hashable, Identifiable {
        /// The text title of the map.
        let title: String
        
        /// The portal item id for the map.
        let id: PortalItem.ID
        
        /// The portal item used to create the map.
        let portalItem: PortalItem
        
        init(title: String, id: PortalItem.ID) {
            self.title = title
            self.id = id
            
            // Create portal item from portal item id.
            self.portalItem = PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                id: id
            )
        }
        
        /// Compares two portal item map objects together to conform to `Equatable`.
        /// - Parameters:
        ///   - lhs: The left hand side `PortalItemMap`.
        ///   - rhs: The right hand side `PortalItemMap`.
        /// - Returns: A `Bool` indicating whether the object were equal.
        static func == (lhs: PortalItemMap, rhs: PortalItemMap) -> Bool {
            return lhs.id == rhs.id
        }
        
        /// Specifies to hash using the id to conform to `Hashable`.
        /// - Parameter hasher: The `Hasher`.
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
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

#Preview {
    NavigationView {
        DisplayMapFromPortalItemView()
    }
}
