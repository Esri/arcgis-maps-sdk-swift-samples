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

import Foundation
import SwiftUI
import ArcGIS

extension ChangeMapViewBackgroundView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    class Model: ObservableObject {
        /// A map with a single feature layer representing world time zones.
        let map: Map = {
            let featureServiceTable = ServiceFeatureTable(item: .worldTimeZones)
            let featureLayer = FeatureLayer(featureTable: featureServiceTable)

            let map = Map()
            map.addOperationalLayer(featureLayer)
            return map
        }()
        
        /// The background grid for the map.
        let backgroundGrid = BackgroundGrid(backgroundColor: .black, lineColor: .white, lineWidth: 2, size: 32)
        
        // The line width range.
        // Used by Slider, which requires CGFloat values.
        let lineWidthRange = CGFloat(0)...CGFloat(10)
        
        // The grid size range.
        // Used by Slider, which requires CGFloat values.
        let sizeRange = CGFloat(2)...CGFloat(50)
        
        /// The background color of the grid.
        @Published var color: Color {
            didSet {
                backgroundGrid.backgroundColor = UIColor(color)
            }
        }
        
        /// The color of the grid lines.
        @Published var lineColor: Color {
            didSet {
                backgroundGrid.lineColor = UIColor(lineColor)
            }
        }
        
        /// The width of the grid lines in device-independent pixels (DIP).
        @Published var lineWidth: CGFloat {
            didSet {
                backgroundGrid.lineWidth = lineWidth
            }
        }
        
        /// The size of each grid square in device-independent pixels (DIP).
        @Published var size: CGFloat {
            didSet {
                backgroundGrid.size = size
            }
        }
        
        init() {
            // Initializes properties from the background grid.
            color = Color(uiColor: backgroundGrid.backgroundColor)
            lineColor = Color(uiColor: backgroundGrid.lineColor)
            lineWidth = backgroundGrid.lineWidth
            size = backgroundGrid.size
        }
    }
}

private extension Item {
    /// A portal item representing world time zones.
    static let worldTimeZones = PortalItem(
        url: URL(string: "https://www.arcgis.com/home/item.html?id=312cebfea2624e108e234220b04460b8")!
    )!
}
