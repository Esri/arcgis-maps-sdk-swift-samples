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

extension AddCustomDynamicEntityDataSourceView {
    /// A marine vessel that can be decoded from the vessel JSON.
    struct Vessel {
        /// A geometry that gives the location of the vessel.
        struct Geometry: Decodable { // swiftlint:disable:this nesting
            /// The x coordinate of the geometry.
            let x: Double
            /// The y coordinate of the geometry.
            let y: Double
        }
        
        /// The location of the vessel.
        let geometry: Geometry
        /// The attributes of the vessel.
        let attributes: [String: Any]
    }
}

extension AddCustomDynamicEntityDataSourceView.Vessel: Decodable {
    private enum CodingKeys: CodingKey {
        case geometry
        case attributes
    }
    
    init(from decoder: Decoder) throws {
        /// The attributes that define meta data for the vessel.
        struct Attributes: Decodable {
            enum CodingKeys: String, CodingKey { // swiftlint:disable:this nesting
                case mmsi = "MMSI"
                case sog = "SOG"
                case cog = "COG"
                case vesselName = "VesselName"
                case callSign = "CallSign"
            }
            
            let mmsi: String
            let sog: Double
            let cog: Double
            let vesselName: String
            let callSign: String
        }
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let geometry = try container.decode(Geometry.self, forKey: .geometry)
        let attributes: [String: Any] = try {
            let attributes = try container.decode(Attributes.self, forKey: .attributes)
            return [
                Attributes.CodingKeys.mmsi.rawValue: attributes.mmsi,
                Attributes.CodingKeys.sog.rawValue: attributes.sog,
                Attributes.CodingKeys.cog.rawValue: attributes.cog,
                Attributes.CodingKeys.vesselName.rawValue: attributes.vesselName,
                Attributes.CodingKeys.callSign.rawValue: attributes.callSign
            ]
        }()
        self.init(geometry: geometry, attributes: attributes)
    }
}
