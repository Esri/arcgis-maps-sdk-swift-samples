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
import Combine
import Foundation

extension AddDynamicEntityLayerView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    class Model: ObservableObject {
        /// A map with a streets basemap style.
        let map = Map(basemapStyle: .arcGISStreets)
        
        /// The data source for the dynamic entity layer.
        let streamService: ArcGISStreamService = {
            let streamService = ArcGISStreamService(url: .streamService)
            
            let filter = ArcGISStreamServiceFilter()
            filter.whereClause = "speed > 0"
            streamService.filter = filter
            
            streamService.purgeOptions.maximumDuration = TimeInterval(5 * 60)
            return streamService
        }()
        
        /// The layer displaying the dynamic entities on the map.
        let dynamicEntityLayer: DynamicEntityLayer
        
        /// A Boolean value indicating whether track lines should be displayed.
        @Published var showsTrackLine: Bool {
            didSet {
                dynamicEntityLayer.trackDisplayProperties.showsTrackLine = showsTrackLine
            }
        }
        
        /// A Boolean value indicating whether previous observations should be displayed.
        @Published var showsPreviousObservations: Bool {
            didSet {
                dynamicEntityLayer.trackDisplayProperties.showsPreviousObservations = showsPreviousObservations
            }
        }
        
        /// The maximum number of previous observations to display.
        @Published var maximumObservations: CGFloat {
            didSet {
                dynamicEntityLayer.trackDisplayProperties.maximumObservations = Int(maximumObservations)
            }
        }
        
        /// The maximum observations range.
        /// Used by slider, which requires `CGFloat` values.
        let maxObservationRange = CGFloat(1)...CGFloat(16)
        
        /// The stream service connection status.
        @Published var connectionStatus: String
        
        init() {
            // Creates the dynamic entity layer.
            dynamicEntityLayer = DynamicEntityLayer(dataSource: streamService)
            
            // Initializes properties from the dynamic entity layer and stream service.
            showsTrackLine = dynamicEntityLayer.trackDisplayProperties.showsTrackLine
            showsPreviousObservations = dynamicEntityLayer.trackDisplayProperties.showsPreviousObservations
            maximumObservations = CGFloat(dynamicEntityLayer.trackDisplayProperties.maximumObservations)
            connectionStatus = streamService.connectionStatus.description
            
            // Adds the dynamic entity layer to the map's operational layers.
            map.addOperationalLayer(dynamicEntityLayer)
        }
    }
}

private extension URL {
    static let streamService = URL(
        string: "https://realtimegis2016.esri.com:6443/arcgis/rest/services/SandyVehicles/StreamServer"
    )!
}

extension ConnectionStatus: CustomStringConvertible {
    /// A user-friendly string for `ConnectionStatus`.
    public var description: String {
        switch self {
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .disconnected:
            return "Disconnected"
        case .failed:
            return "Failed"
        @unknown default:
            return "Unknown"
        }
    }
}
