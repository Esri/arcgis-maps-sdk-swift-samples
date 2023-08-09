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

extension AddCustomDynamicEntityDataSourceView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    class Model: ObservableObject {
        /// A map with an ArcGIS oceans basemap style.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISOceans)
            map.initialViewpoint = Viewpoint(
                latitude: 47.984,
                longitude: -123.657,
                scale: 3e6
            )
            return map
        }()
        
        /// The dynamic entity layer that is displaying our custom data.
        let dynamicEntityLayer: DynamicEntityLayer
        
        init() {
            // The meta data for the custom dynamic entity data source.
            let info = DynamicEntityDataSourceInfo(
                entityIDFieldName: Vessel.Attributes.CodingKeys.mmsi.rawValue,
                fields: .vesselFields
            )
            
            info.spatialReference = .wgs84
            
            /// Makes the vessel feed that emits the events to the custom dynamic entity data source.
            /// - Returns: The vessel feed.
            func makeFeed() throws -> VesselFeed {
                // All of the JSON as a string.
                let contents = try String(contentsOf: .selectedVesselsDataSource, encoding: .utf8)
                
                // An array of the individual JSON strings.
                let lines = contents.split(separator: "\n")
                
                let decoder = JSONDecoder()
                
                // The feed events that the feed will emit.
                let feedEvents = lines
                    .compactMap { jsonString -> CustomDynamicEntityFeedEvent? in
                        guard let decodable = try? decoder.decode(
                            Vessel.self,
                            from: jsonString.data(using: .utf8)!
                        ) else { return nil }
                        
                        // The geometry that was decoded from the JSON.
                        let geometry = decodable.geometry
                        
                        // We successfully decoded the vessel JSON so we should
                        // add that vessel as a new observation.
                        return .newObservation(
                            geometry: Point(x: geometry.x, y: geometry.y, spatialReference: .wgs84),
                            attributes: decodable.attributes.makeDictionary()
                        )
                    }
                
                return VesselFeed(events: feedEvents)
            }
            
            let customDataSource = CustomDynamicEntityDataSource(info: info) { try makeFeed() }
            
            dynamicEntityLayer = DynamicEntityLayer(dataSource: customDataSource)
            
            let trackDisplayProperties = dynamicEntityLayer.trackDisplayProperties
            trackDisplayProperties.showsPreviousObservations = true
            trackDisplayProperties.showsTrackLine = true
            trackDisplayProperties.maximumObservations = 20
            
            let labelDefinition = LabelDefinition(
                labelExpression: SimpleLabelExpression(simpleExpression: "[VesselName]"),
                textSymbol: TextSymbol(color: .red, size: 12)
            )
            labelDefinition.placement = .pointAboveCenter
            
            dynamicEntityLayer.addLabelDefinition(labelDefinition)
            dynamicEntityLayer.labelsAreEnabled = true
            
            map.addOperationalLayer(dynamicEntityLayer)
        }
    }
}

private extension Array where Element == Field {
    /// An array of fields that match the attributes of each observation in the data source.
    ///
    /// This schema is derived from the first row in the custom data source.
    static var vesselFields: [Field] = [
        Field(type: .text, name: "MMSI", alias: "MMSI", length: 256),
        Field(type: .float64, name: "SOG", alias: "SOG", length: 8),
        Field(type: .float64, name: "COG", alias: "COG", length: 8),
        Field(type: .text, name: "VesselName", alias: "VesselName", length: 256),
        Field(type: .text, name: "CallSign", alias: "CallSign", length: 256),
        Field(type: .text, name: "globalid", alias: "globalid", length: 256)
    ]
}

/// The vessel feed that is emitting custom dynamic entity events.
private struct VesselFeed: CustomDynamicEntityFeed {
    let events: AsyncPublisher<AnyPublisher<CustomDynamicEntityFeedEvent, Never>>
    
    /// Creates a feed that is receiving the events that are being passed in.
    ///
    /// The events will be emitted with a delay so it resembles live data.
    /// - Parameter events: The events that will be emitted by the feed
    init<S>(events: S) where S: Sequence, S.Element == CustomDynamicEntityFeedEvent {
        self.events = events.publisher
            .delay(for: 1, scheduler: RunLoop.main)
            .eraseToAnyPublisher()
            .values
    }
}

private extension URL {
    /// The URL to the selected vessels JSON data.
    static var selectedVesselsDataSource: URL {
        Bundle.main.url(
            forResource: "AIS_MarineCadastre_SelectedVessels_CustomDataSource",
            withExtension: "json"
        )!
    }
}
