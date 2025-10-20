// Copyright 2025 Esri
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

extension QueryDynamicEntitiesView {
    /// The view model for this sample.
    @MainActor
    @Observable
    final class Model {
        /// A map with a topographic basemap.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            map.initialViewpoint = Viewpoint(center: .phoenixAirport, scale: 1_266_500)
            return map
        }()
        
        /// The graphics overlay for displaying the phoenix airport buffer graphic.
        let graphicsOverlay = GraphicsOverlay()
        
        /// The data source containing the dynamic dynamic entities to query.
        private let dataSource: CustomDynamicEntityDataSource = {
            // Creates the metadata for the data source.
            let fields = PlaneAttributeKey.allCases.map { attribute in
                Field(type: attribute.fieldType, name: attribute.rawValue, alias: "")
            }
            let info = DynamicEntityDataSourceInfo(entityIDFieldName: "flight_number", fields: fields)
            info.spatialReference = .wgs84
            
            // Creates a custom data source using the data feed.
            return CustomDynamicEntityDataSource(info: info, makeFeed: PlaneFeed.init)
        }()
        
        /// The layer displaying the dynamic entities on the map.
        private let dynamicEntityLayer: DynamicEntityLayer
        
        /// A geometry representing a 15 mile buffer around the Phoenix airport.
        private let phoenixAirportBuffer = GeometryEngine.geodeticBuffer(
            around: .phoenixAirport,
            distance: 15,
            distanceUnit: .miles,
            maxDeviation: .nan,
            curveType: .geodesic
        )!
        
        init() {
            dynamicEntityLayer = DynamicEntityLayer(dataSource: dataSource)
            setUpDynamicEntityLayer()
            setUpGraphicsOverlay()
        }
        
        /// Queries the dynamic entities on the data source.
        /// - Parameter type: The type of query to perform.
        /// - Returns: The result of the query operation.
        func queryDynamicEntities(type: QueryType) async -> Result<[DynamicEntity], any Error> {
            let parameters = DynamicEntityQueryParameters()
            
            switch type {
            case .geometry:
                // Sets the parameters' geometry and spatial relationship to query within the buffer.
                parameters.geometry = phoenixAirportBuffer
                parameters.spatialRelationship = .intersects
                
                graphicsOverlay.isVisible = true
            case .attributes:
                // Sets the parameters' where clause to query the entities' attributes.
                parameters.whereClause = "status = 'In flight' AND arrival_airport = 'PHX'"
            case .trackID(let id):
                // Adds a track ID to query for to the parameters.
                parameters.addTrackID(id)
            }
            
            return await Result {
                // Performs a dynamic entities query on the data source.
                let queryResult = try await dataSource.queryDynamicEntities(using: parameters)
                
                // Gets the entities from the query result and selects them on the layer.
                let entities = Array(queryResult.entities())
                dynamicEntityLayer.selectDynamicEntities(entities)
                
                return entities
            }
        }
        
        /// Clears selected dynamic entities and hides the graphics overlay.
        func resetDisplay() {
            dynamicEntityLayer.clearSelection()
            graphicsOverlay.isVisible = false
        }
        
        /// Sets up the dynamic entity layer's properties and adds it to the map.
        private func setUpDynamicEntityLayer() {
            // Sets display tracking properties on the layer.
            let trackDisplayProperties = dynamicEntityLayer.trackDisplayProperties
            trackDisplayProperties.showsPreviousObservations = true
            trackDisplayProperties.showsTrackLine = true
            trackDisplayProperties.maximumObservations = 20
            
            // Creates a label definition to display the entities' flight numbers.
            let labelDefinition = LabelDefinition(
                labelExpression: SimpleLabelExpression(simpleExpression: "[flight_number]"),
                textSymbol: .init(color: .red, size: 12)
            )
            labelDefinition.placement = .pointAboveCenter
            
            dynamicEntityLayer.addLabelDefinition(labelDefinition)
            dynamicEntityLayer.labelsAreEnabled = true
            
            map.addOperationalLayer(dynamicEntityLayer)
        }
        
        /// Creates a phoenix airport buffer graphic and adds it to the overlay.
        private func setUpGraphicsOverlay() {
            let blackLineSymbol = SimpleLineSymbol(style: .solid, color: .black, width: 1)
            let redFillSymbol = SimpleFillSymbol(
                color: .red.withAlphaComponent(0.1),
                outline: blackLineSymbol
            )
            
            let bufferGraphic = Graphic(geometry: phoenixAirportBuffer, symbol: redFillSymbol)
            graphicsOverlay.addGraphic(bufferGraphic)
            
            // Hides the graphics overlay initially.
            graphicsOverlay.isVisible = false
        }
    }
    
    /// A plane that can be decoded from JSON.
    fileprivate struct Plane {
        /// The location of the plane.
        let point: Point
        /// The attributes of the plane.
        let attributes: [String: any Sendable]
    }
    
    /// A custom dynamic entity feed that emits events representing planes.
    private struct PlaneFeed: CustomDynamicEntityFeed {
        /// The feed's stream of events.
        let events = URL.phoenixAirTrafficJSON.lines.map { line in
            // Delays the next observation to simulate live data.
            try await Task.sleep(for: .seconds(0.1))
            
            // Decodes the plane from the line and uses it to create a new observation.
            let plane = try JSONDecoder().decode(Plane.self, from: .init(line.utf8))
            return CustomDynamicEntityFeedEvent.newObservation(
                geometry: plane.point,
                attributes: plane.attributes
            )
        }
    }
    
    /// A type of dynamic entities query.
    enum QueryType: Hashable, Identifiable {
        case geometry, attributes, trackID(String)
        
        var id: Self { self }
    }
    
    /// The keys for decoding `Plane.attributes`.
    enum PlaneAttributeKey: String, CodingKey, CaseIterable {
        case aircraft
        case altitudeFeet = "altitude_feet"
        case arrivalAirport = "arrival_airport"
        case flightNumber = "flight_number"
        case heading
        case speed
        case status
        
        /// The type used to decode the attribute.
        fileprivate var decodeType: (Decodable & Sendable).Type {
            isNumeric ? Double.self : String.self
        }
        
        /// The type used to create a field for the attribute.
        fileprivate var fieldType: FieldType {
            isNumeric ? .float64 : .text
        }
        
        /// A Boolean value indicating whether the attribute has a numeric value.
        private var isNumeric: Bool {
            switch self {
            case .heading, .altitudeFeet, .speed:
                true
            default:
                false
            }
        }
    }
}

extension QueryDynamicEntitiesView.Plane: Decodable {
    private enum CodingKeys: CodingKey {
        case geometry, attributes
    }
    
    private typealias AttributeKeys = QueryDynamicEntitiesView.PlaneAttributeKey
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        point = try container.decode(Point.self, forKey: .geometry)
        
        let attributesDecoder = try container.superDecoder(forKey: .attributes)
        let attributesContainer = try attributesDecoder.container(keyedBy: AttributeKeys.self)
        attributes = try AttributeKeys.allCases.reduce(into: [:]) { attributes, key in
            let attribute = try attributesContainer.decodeIfPresent(key.decodeType, forKey: key)
            attributes[key.rawValue] = attribute
        }
    }
}

private extension Geometry {
    /// The location of the phoenix airport.
    static var phoenixAirport: Point { .init(latitude: 33.4352, longitude: -112.0101) }
}

private extension URL {
    /// The URL to a JSON file containing mock air traffic data around the Phoenix Sky Harbor International Airport.
    static var phoenixAirTrafficJSON: URL {
        Bundle.main.url(forResource: "phx_air_traffic", withExtension: "json")!
    }
}
