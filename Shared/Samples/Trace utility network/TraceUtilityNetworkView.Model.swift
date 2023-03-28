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
import Foundation

extension TraceUtilityNetworkView {
    /// The model used to manage the state of the trace view.
    class Model: ObservableObject {
        /// The parameters for the pending trace.
        ///
        /// Important trace information like the trace type, starting points, and barriers is contained
        /// within this value.
        @Published var pendingTraceParameters: UtilityTraceParameters?
        
        /// The map contains the utility network and operational layers on which trace results will
        /// be selected.
        let map = {
            let map = Map(item: PortalItem.napervilleElectricalNetwork)
            map.basemap = Basemap(style: .arcGISStreetsNight)
            return map
        }()
        
        /// The graphics overlay on which starting point and barrier symbols will be drawn.
        var points: GraphicsOverlay = {
            let overlay = GraphicsOverlay()
            let barrierUniqueValue = UniqueValue(
                symbol: SimpleMarkerSymbol.barrier,
                values: [PointType.barrier.rawValue]
            )
            overlay.renderer = UniqueValueRenderer(
                fieldNames: [String(describing: PointType.self)],
                uniqueValues: [barrierUniqueValue],
                defaultSymbol: SimpleMarkerSymbol.startingLocation
            )
            return overlay
        }()
    }
}

private extension PortalItem {
    /// A portal item for the electrical network in this sample.
    static var napervilleElectricalNetwork: PortalItem {
        .init(
            portal: .arcGISOnline(connection: .authenticated),
            id: .init("471eb0bf37074b1fbb972b1da70fb310")!
        )
    }
}

private extension SimpleMarkerSymbol {
    /// The symbol for barrier elements.
    static var barrier: SimpleMarkerSymbol {
        .init(style: .x, color: .red, size: 20)
    }
    
    /// The symbol for starting location elements.
    static var startingLocation: SimpleMarkerSymbol {
        .init(style: .cross, color: .green, size: 20)
    }
}
