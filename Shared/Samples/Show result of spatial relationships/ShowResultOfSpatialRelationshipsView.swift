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

import SwiftUI
import ArcGIS

struct ShowResultOfSpatialRelationshipsView: View {
    /// A Boolean value indicating whether to show an alert.
    @State private var showAlert = false
    
    /// The error shown in the alert.
    @State private var error: Error?
    
    /// The point indicating where to identify a graphic.
    @State private var identifyPoint: CGPoint?
    
    /// The map point where the map was tapped.
    @State private var mapPoint: Point?
    
    /// A location callout placement.
    @State private var calloutPlacement: LocationCalloutPlacement?
    
    /// The relationships for the selected graphic.
    @State private var relationships: [Relationship] = []
    
    /// A map with a topographic basemap style and an initial viewpoint.
    @StateObject private var map: Map = {
        let map = Map(basemapStyle: .arcGISTopographic)
        if let point = Graphic.point.geometry as? Point {
            map.initialViewpoint = Viewpoint(center: point, scale: 1e8)
        }
        return map
    }()
    
    /// A graphics overlay consisting of a polygon, polyline, and point.
    @StateObject private var graphicsOverlay = GraphicsOverlay(graphics: [.polygon, .polyline, .point])
    
    /// The point graphic.
    private var pointGraphic: Graphic { graphicsOverlay.graphics.last! }
    /// The polyline graphic.
    private var polylineGraphic: Graphic { graphicsOverlay.graphics[1] }
    /// The polygon graphic.
    private var polygonGraphic: Graphic { graphicsOverlay.graphics.first! }
    
    private struct Relationship {
        let relationships: [String]
        let title: String
    }
    
    /// Shows the relationships for the selected graphic.
    private func showRelationships(for graphic: Graphic) {
        guard let selectedGeometry = graphic.geometry,
              let allRelationships = allRelationships(for: selectedGeometry),
              let mapPoint = mapPoint else {
            return
        }
        
        // Updates the relationships.
        relationships = allRelationships
        // Updates the location callout placement.
        calloutPlacement = LocationCalloutPlacement(location: mapPoint)
    }
    
    /// Returns the relevant relationships for a given geometry.
    private func allRelationships(for geometry: Geometry) -> [Relationship]? {
        guard let pointGeometry = pointGraphic.geometry,
              let polylineGeometry = polylineGraphic.geometry,
              let polygonGeometry = polygonGraphic.geometry else {
            return nil
        }
        
        switch geometry {
        case is Point:
            return [
                Relationship(
                    relationships: getSpatialRelationships(of: pointGeometry, with: polylineGeometry),
                    title: "Relationship With Polyline"
                ),
                Relationship(
                    relationships: getSpatialRelationships(of: pointGeometry, with: polygonGeometry),
                    title: "Relationship With Polygon"
                )
            ]
        case is Polyline:
            return [
                Relationship(
                    relationships: getSpatialRelationships(of: polylineGeometry, with: pointGeometry),
                    title: "Relationship With Point"
                ),
                Relationship(
                    relationships: getSpatialRelationships(of: polylineGeometry, with: polygonGeometry),
                    title: "Relationship With Polygon"
                )
            ]
        case is Polygon:
            return [
                Relationship(
                    relationships: getSpatialRelationships(of: polygonGeometry, with: pointGeometry),
                    title: "Relationship With Point"
                ),
                Relationship(
                    relationships: getSpatialRelationships(of: polygonGeometry, with: polylineGeometry),
                    title: "Relationship With Polyline"
                )
            ]
        default:
            return nil
        }
    }
    
    /// Checks the different relationships between two geometries and returns the result as an array of strings.
    /// - Parameters:
    ///   - geometry1: The input geometry to be compared.
    ///   - geometry2: The input geometry to be compared.
    /// - Returns: An array of strings representing relationship.
    private func getSpatialRelationships(of geometry1: Geometry, with geometry2: Geometry) -> [String] {
        var relationships = [String]()
        if GeometryEngine.isGeometry(geometry1, crossing: geometry2) {
            relationships.append("Crosses")
        }
        if GeometryEngine.doesGeometry(geometry1, contain: geometry2) {
            relationships.append("Contains")
        }
        if GeometryEngine.isGeometry(geometry1, disjointWith: geometry2) {
            relationships.append("Disjoint")
        }
        if GeometryEngine.isGeometry(geometry1, intersecting: geometry2) {
            relationships.append("Intersects")
        }
        if GeometryEngine.isGeometry(geometry1, overlapping: geometry2) {
            relationships.append("Overlaps")
        }
        if GeometryEngine.isGeometry(geometry1, touching: geometry2) {
            relationships.append("Touches")
        }
        if GeometryEngine.isGeometry(geometry1, within: geometry2) {
            relationships.append("Within")
        }
        return relationships
    }
    
    var body: some View {
        MapViewReader { mapView in
            MapView(map: map, graphicsOverlays: [graphicsOverlay])
                .onSingleTapGesture { screenPoint, mapPoint in
                    identifyPoint = screenPoint
                    self.mapPoint = mapPoint
                }
                .callout(placement: $calloutPlacement.animation(.default.speed(4))) { _ in
                    VStack(alignment: .leading) {
                        ForEach(relationships, id: \.title) { relationship in
                            Text(relationship.title)
                                .font(.headline)
                            VStack(alignment: .leading) {
                                ForEach(relationship.relationships, id: \.self) { relationship in
                                    Text(relationship)
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
                    graphicsOverlay.clearSelection()
                    
                    if calloutPlacement == nil {
                        do {
                            // Identifies the graphic at the given screen point.
                            let results = try await mapView.identify(
                                graphicsOverlay: graphicsOverlay,
                                screenPoint: identifyPoint,
                                tolerance: 12,
                                maximumResults: 1
                            )
                            
                            if let identifiedGraphic = results.graphics.first {
                                // Selects the identified graphic.
                                graphicsOverlay.selectGraphics([identifiedGraphic])
                                // Shows the graphic's relationships.
                                showRelationships(for: identifiedGraphic)
                            }
                        } catch {
                            self.error = error
                            showAlert = true
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
