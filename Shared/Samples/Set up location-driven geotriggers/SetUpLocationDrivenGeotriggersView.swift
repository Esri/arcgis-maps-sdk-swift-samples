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

struct SetUpLocationDrivenGeotriggersView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        // Create a map view to display the map.
        MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
    }
}

private extension SetUpLocationDrivenGeotriggersView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A 'Map'
        var map: Map
        
        ///
        let graphicsOverlay = GraphicsOverlay()
        
        /// A simulated location data source for demo purposes.
        var simulatedLocationDataSource: SimulatedLocationDataSource!
        
        
        init() {
            map = makeMap()
        }
        
        
        
        /// Create a map.
        func makeMap() -> Map {
            // Load a map with predefined tile basemap, feature styles, and labels.
            let map = Map(item: PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                id: Item.ID(rawValue: "6ab0e91dc39e478cae4f408e1a36a308")!
            ))
            map.load { [weak self] _ in
                guard let self = self else { return }
                
                // Set up location display with a simulated location data source.
                let locationDataSource = self.makeDataSource(polylineJSONString: Self.walkingTourPolylineJSON)
                self.simulatedLocationDataSource = locationDataSource
                self.startDisplayingLocation(using: locationDataSource)
                
                // Get the service feature tables from the map's operational layers.
                if let operationalLayers = map.operationalLayers as? [FeatureLayer],
                   let gardenSectionsLayer = operationalLayers.first(where: { $0.item?.itemID == "1ba816341ea04243832136379b8951d9" }),
                   let gardenPOIsLayer = operationalLayers.first(where: { $0.item?.itemID == "7c6280c290c34ae8aeb6b5c4ec841167" }),
                   let gardenSections = gardenSectionsLayer.featureTable as? ServiceFeatureTable,
                   let gardenPOIs = gardenPOIsLayer.featureTable as? ServiceFeatureTable {
                    // Create geotriggers for each of the service feature tables.
                    let geotriggerFeed = LocationGeotriggerFeed(locationDataSource: locationDataSource)
                    self.startMonitoring(feed: geotriggerFeed, featureTable: gardenSections, bufferDistance: 0.0, fenceGeotriggerName: Self.sectionFenceGeotriggerName)
                    self.startMonitoring(feed: geotriggerFeed, featureTable: gardenPOIs, bufferDistance: 10.0, fenceGeotriggerName: Self.poiFenceGeotriggerName)
                }
            }
            return map
        }
        
        /// Create a simulated location data source from a GeoJSON.
        func makeDataSource(polylineJSONString: String) -> SimulatedLocationDataSource {
            let simulatedDataSource = SimulatedLocationDataSource()
            let jsonObject = try? JSONSerialization.jsonObject(with: polylineJSONString.data(using: .utf8)!)
            let routePolyline = try? Polyline.fromJSON(jsonObject! as! String) as? Polyline
            // Densify the polyline to control the simulation speed.
            
            let densifiedRoute = GeometryEngine.geodeticDensify(
                routePolyline!,
                maxSegmentLength: 5.0,
                lengthUnit: .meters,
                curveType: .geodesic
            ) as! Polyline
            simulatedDataSource.setSimulatedLocations(with: densifiedRoute)
            return simulatedDataSource
        }
    }
}


private extension PortalItem.ID {
    /// The .
    static var incidentsInSanFrancisco: Self { Self("fb788308ea2e4d8682b9c05ef641f273")! }
}
