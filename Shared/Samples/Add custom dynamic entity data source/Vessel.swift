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

/// A marine vessel that can be decoded from the vessel JSON.
struct Vessel: Decodable {
    /// A geometry that gives the location of the vessel.
    struct Geometry: Decodable {
        /// The x coordinate of the geometry.
        let x: Double
        /// The y coordinate of the geometry.
        let y: Double
    }
    
    /// The attributes that define meta data for the vessel.
    struct Attributes: Decodable {
        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case mmsi = "MMSI"
            case sog = "SOG"
            case cog = "COG"
            case vesselName = "VesselName"
            case callSign = "CallSign"
            case globalID = "globalid"
        }
        
        private let mmsi: String
        private let sog: Double
        private let cog: Double
        private let vesselName: String
        private let callSign: String
        private let globalID: String
        
        /// Makes an attributes dictionary that can be used to create a new observation.
        ///
        /// The value type of the attributes is `String` so the attributes are easier to display in a callout.
        /// - Returns: The attributes dictionary
        func makeDictionary() -> [String: String] {
            var attributes: [String: String] = [:]
            attributes[CodingKeys.mmsi.rawValue] = mmsi
            attributes[CodingKeys.sog.rawValue] = String(format: "%.2f", sog)
            attributes[CodingKeys.cog.rawValue] = String(format: "%.2f", cog)
            attributes[CodingKeys.vesselName.rawValue] = vesselName
            attributes[CodingKeys.callSign.rawValue] = callSign
            attributes[CodingKeys.globalID.rawValue] = globalID
            return attributes
        }
    }
    
    /// The location of the vessel.
    let geometry: Geometry
    /// The attributes of the vessel.
    let attributes: Attributes
}
