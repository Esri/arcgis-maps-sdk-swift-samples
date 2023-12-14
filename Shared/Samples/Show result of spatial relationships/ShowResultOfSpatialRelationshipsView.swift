// Copyright 2022 Esri
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

struct ShowResultOfSpatialRelationshipsView: View {
    /// The error shown in the error alert.
    @State private var error: Error?
    
    /// The point indicating where to identify a graphic.
    @State private var identifyPoint: CGPoint?
    
    /// The map point where the map was tapped.
    @State private var mapPoint: Point?
    
    /// A location callout placement.
    @State private var calloutPlacement: CalloutPlacement?
    
    /// The relationships for the selected graphic.
    @State private var relationships: [Relationship] = []
    
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// Shows the relationships for the selected graphic.
    /// - Parameter graphic: The graphic to show all spatial relationships for.
    private func showRelationships(for graphic: Graphic) {
        guard let selectedGeometry = graphic.geometry else {
            return
        }
        // Updates the relationships.
        relationships = model.allRelationships(for: selectedGeometry)
        guard !relationships.isEmpty else {
            return
        }
        // Updates the location callout placement.
        calloutPlacement = mapPoint.map { CalloutPlacement.location($0) }
    }
    
    var body: some View {
        MapViewReader { mapView in
            MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
                .onSingleTapGesture { screenPoint, mapPoint in
                    identifyPoint = screenPoint
                    self.mapPoint = mapPoint
                }
                .callout(placement: $calloutPlacement.animation(.default.speed(2))) { _ in
                    VStack(alignment: .leading) {
                        ForEach(relationships, id: \.relationshipWithLabel) { relationship in
                            Text(relationship.relationshipWithLabel)
                                .font(.headline)
                            VStack(alignment: .leading) {
                                ForEach(relationship.spatialRelationships, id: \.self) { spatialRelationship in
                                    Text(spatialRelationship)
                                }
                            }
                            .padding(.bottom, 5)
                        }
                    }
                    .padding(8)
                }
                .task(id: identifyPoint) {
                    guard let identifyPoint = identifyPoint else { return }
                    // Clears the selection.
                    model.graphicsOverlay.clearSelection()
                    
                    if calloutPlacement == nil {
                        do {
                            // Identifies the graphic at the given screen point.
                            let results = try await mapView.identify(
                                on: model.graphicsOverlay,
                                screenPoint: identifyPoint,
                                tolerance: 12,
                                maximumResults: 1
                            )
                            
                            if let identifiedGraphic = results.graphics.first {
                                // Selects the identified graphic.
                                model.graphicsOverlay.selectGraphics([identifiedGraphic])
                                // Shows the graphic's relationships.
                                showRelationships(for: identifiedGraphic)
                            }
                        } catch {
                            self.error = error
                        }
                    } else {
                        // Hides the callout.
                        calloutPlacement = nil
                    }
                }
                .overlay(alignment: .top) {
                    Text("Tap on the map to select the graphic.")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
                }
                .errorAlert(presentingError: $error)
        }
    }
}

private extension ShowResultOfSpatialRelationshipsView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    class Model: ObservableObject {
        /// A map with a topographic basemap style and an initial viewpoint.
        let map: Map = {
            let map = Map(basemapStyle: .arcGISTopographic)
            map.initialViewpoint = Viewpoint(center: Graphic.point.geometry as! Point, scale: 1e8)
            return map
        }()
        
        /// A graphics overlay consisting of a polygon, polyline, and point.
        let graphicsOverlay = GraphicsOverlay(graphics: [.polygon, .polyline, .point])
        
        /// The polygon graphic.
        private var polygonGraphic: Graphic { graphicsOverlay.graphics[0] }
        /// The polyline graphic.
        private var polylineGraphic: Graphic { graphicsOverlay.graphics[1] }
        /// The point graphic.
        private var pointGraphic: Graphic { graphicsOverlay.graphics[2] }
        
        /// Returns the relevant spatial relationships for a given geometry with all other geometries in this sample.
        /// - Parameter geometry: The geometry to find all spatial relationships for.
        /// - Returns: An array of relationships between the given geometry and all other geometries.
        func allRelationships(for geometry: Geometry) -> [Relationship] {
            let pointGeometry = pointGraphic.geometry!
            let polylineGeometry = polylineGraphic.geometry!
            let polygonGeometry = polygonGraphic.geometry!
            
            switch geometry {
            case is Point:
                return [
                    Relationship(between: pointGeometry, and: polylineGeometry),
                    Relationship(between: pointGeometry, and: polygonGeometry)
                ]
            case is Polyline:
                return [
                    Relationship(between: polylineGeometry, and: pointGeometry),
                    Relationship(between: polylineGeometry, and: polygonGeometry)
                ]
            case is ArcGIS.Polygon:
                return [
                    Relationship(between: polygonGeometry, and: pointGeometry),
                    Relationship(between: polygonGeometry, and: polylineGeometry)
                ]
            default:
                return []
            }
        }
    }
}

private extension ShowResultOfSpatialRelationshipsView {
    /// The relationship between one geometry and another geometry.
    struct Relationship {
        /// The input geometry to be compared.
        private let geometryOne: Geometry
        /// The input geometry to be compared against.
        private let geometryTwo: Geometry
        
        /// - Parameters:
        ///   - geometryOne: The input geometry to be compared.
        ///   - geometryTwo: The input geometry to be compared against.
        init(between geometryOne: Geometry, and geometryTwo: Geometry) {
            self.geometryOne = geometryOne
            self.geometryTwo = geometryTwo
        }
        
        /// The spatial relationships between geometry one and two.
        var spatialRelationships: [String] {
            geometryOne.getSpatialRelationships(with: geometryTwo)
        }
        
        /// A description of what geometry type `geometryOne` is compared against.
        var relationshipWithLabel: String {
            "Relationship with \(geometryTwo.type)"
        }
    }
}

private extension Geometry {
    /// Checks the different relationships between two geometries and returns the result as an array of strings.
    /// - Parameter geometry: The input geometry to be compared against.
    /// - Returns: An array of strings representing a relationship.
    func getSpatialRelationships(with geometry: Geometry) -> [String] {
        var relationships: [String] = []
        if GeometryEngine.isGeometry(self, crossing: geometry) {
            relationships.append("Crosses")
        }
        if GeometryEngine.doesGeometry(self, contain: geometry) {
            relationships.append("Contains")
        }
        if GeometryEngine.isGeometry(self, disjointWith: geometry) {
            relationships.append("Disjoint")
        }
        if GeometryEngine.isGeometry(self, intersecting: geometry) {
            relationships.append("Intersects")
        }
        if GeometryEngine.isGeometry(self, overlapping: geometry) {
            relationships.append("Overlaps")
        }
        if GeometryEngine.isGeometry(self, touching: geometry) {
            relationships.append("Touches")
        }
        if GeometryEngine.isGeometry(self, within: geometry) {
            relationships.append("Within")
        }
        return relationships
    }
    
    /// The type of the geometry.
    var type: String {
        switch self {
        case is Point: return "Point"
        case is Polyline: return "Polyline"
        case is ArcGIS.Polygon: return "Polygon"
        default: return "Unknown"
        }
    }
}

private extension Graphic {
    /// A green polygon with a forward diagonal style.
    static var polygon: Graphic {
        let polygon = Polygon(
            points: [
                Point(x: -5991501.677830, y: 5599295.131468),
                Point(x: -6928550.398185, y: 2087936.739807),
                Point(x: -3149463.800709, y: 1840803.011362),
                Point(x: -1563689.043184, y: 3714900.452072),
                Point(x: -3180355.516764, y: 5619889.608838)
            ],
            spatialReference: .webMercator
        )
        let lineSymbol = SimpleLineSymbol(style: .solid, color: .green, width: 2)
        let fillSymbol = SimpleFillSymbol(style: .forwardDiagonal, color: .green, outline: lineSymbol)
        return Graphic(geometry: polygon, symbol: fillSymbol)
    }
    
    /// A red, dashed polyline.
    static var polyline: Graphic {
        let polyline = Polyline(
            points: [
                Point(x: -4354240.726880, y: -609939.795721),
                Point(x: -3427489.245210, y: 2139422.933233),
                Point(x: -2109442.693501, y: 4301843.057130),
                Point(x: -1810822.771630, y: 7205664.366363)
            ],
            spatialReference: .webMercator
        )
        let lineSymbol = SimpleLineSymbol(style: .dash, color: .red, width: 4)
        return Graphic(geometry: polyline, symbol: lineSymbol)
    }
    
    /// A blue point.
    static var point: Graphic {
        let point = Point(x: -4487263.495911, y: 3699176.480377, spatialReference: .webMercator)
        let markerSymbol = SimpleMarkerSymbol(color: .blue, size: 10)
        return Graphic(geometry: point, symbol: markerSymbol)
    }
}

#if DEBUG
private extension ShowResultOfSpatialRelationshipsView.Model {
    typealias Relationship = ShowResultOfSpatialRelationshipsView.Relationship
}

#Preview {
    ShowResultOfSpatialRelationshipsView()
}
#endif
