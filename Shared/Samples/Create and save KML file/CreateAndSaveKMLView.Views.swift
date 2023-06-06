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

extension CreateAndSaveKMLView {
    /// The content of the main menu.
    var mainMenuContent: some View {
        VStack {
            Menu {
                pointStyleMenuContent
            } label: {
                Label("New Point", systemImage: "smallcircle.filled.circle")
            }
            
            Menu {
                polylineStyleMenuContent
            } label: {
                Label("New Line", systemImage: "line.diagonal")
            }
            
            Menu {
                polygonStyleMenuContent
            } label: {
                Label("New Area", systemImage: "skew")
            }
            
            Divider()
            
            Button(role: .destructive) {
                model.clearSavedSketches()
            } label: {
                Label("Clear Saved Sketches", systemImage: "trash")
            }
            .disabled(!model.canClearSavedSketches)
        }
    }
    
    /// The content of the editing menu.
    var editMenuContent: some View {
        VStack {
            Button(role: .destructive) {
                model.geometryEditor.clearGeometry()
            } label: {
                Label("Clear Current Sketch", systemImage: "trash")
            }
            .disabled(model.clearButtonIsDisabled)
            
            Divider()
            
            Button {
                model.save()
            } label: {
                Label("Save Sketch", systemImage: "square.and.arrow.down")
            }
            .disabled(!model.canSave)
            
            Button {
                model.stop()
            } label: {
                Label("Cancel Sketch", systemImage: "xmark")
            }
        }
    }
    
    /// The point style menu.
    var pointStyleMenuContent: some View {
        VStack {
            Button {
                model.kmlStyle = KMLStyle(iconURL: URL(string: "http://resources.esri.com/help/900/arcgisexplorer/sdk/doc/bitmaps/148cca9a-87a8-42bd-9da4-5fe427b6fb7b127.png")!)
                model.startGeometryEditor(withType: Point.self)
            } label: {
                Text("No Style")
            }
            
            Button {
                model.kmlStyle = KMLStyle(iconURL: URL(string: "https://static.arcgis.com/images/Symbols/Shapes/BlueStarLargeB.png")!)
                model.startGeometryEditor(withType: Point.self)
            } label: {
                Text("Star")
            }
            
            Button {
                model.kmlStyle = KMLStyle(iconURL: URL(string: "https://static.arcgis.com/images/Symbols/Shapes/BlueDiamondLargeB.png")!)
                model.startGeometryEditor(withType: Point.self)
            } label: {
                Text("Diamond")
            }
            
            Button {
                model.kmlStyle = KMLStyle(iconURL: URL(string: "https://static.arcgis.com/images/Symbols/Shapes/BlueCircleLargeB.png")!)
                model.startGeometryEditor(withType: Point.self)
            } label: {
                Text("Circle")
            }
            
            Button {
                model.kmlStyle = KMLStyle(iconURL: URL(string: "https://static.arcgis.com/images/Symbols/Shapes/BlueSquareLargeB.png")!)
                model.startGeometryEditor(withType: Point.self)
            } label: {
                Text("Square")
            }
            
            Button {
                model.kmlStyle = KMLStyle(iconURL: URL(string: "https://static.arcgis.com/images/Symbols/Shapes/BluePin1LargeB.png")!)
                model.startGeometryEditor(withType: Point.self)
            } label: {
                Text("Round pin")
            }
            
            Button {
                model.kmlStyle = KMLStyle(iconURL: URL(string: "https://static.arcgis.com/images/Symbols/Shapes/BluePin2LargeB.png")!)
                model.startGeometryEditor(withType: Point.self)
            } label: {
                Text("Square pin")
            }
        }
    }
    
    /// The polyline style menu.
    var polylineStyleMenuContent: some View {
        VStack {
            Button {
                model.kmlStyle = KMLStyle(lineColor: .red)
                model.startGeometryEditor(withType: Polyline.self)
            } label: {
                Text("Red")
            }
            
            Button {
                model.kmlStyle = KMLStyle(lineColor: .yellow)
                model.startGeometryEditor(withType: Polyline.self)
            } label: {
                Text("Yellow")
            }

            Button {
                model.kmlStyle = KMLStyle(lineColor: .white)
                model.startGeometryEditor(withType: Polyline.self)
            } label: {
                Text("White")
            }

            Button {
                model.kmlStyle = KMLStyle(lineColor: .purple)
                model.startGeometryEditor(withType: Polyline.self)
            } label: {
                Text("Purple")
            }

            Button {
                model.kmlStyle = KMLStyle(lineColor: .orange)
                model.startGeometryEditor(withType: Polyline.self)
            } label: {
                Text("Orange")
            }

            Button {
                model.kmlStyle = KMLStyle(lineColor: .magenta)
                model.startGeometryEditor(withType: Polyline.self)
            } label: {
                Text("Magenta")
            }
        }
    }
    
    /// The polygon style menu.
    var polygonStyleMenuContent: some View {
        VStack {
            Button {
                model.kmlStyle = KMLStyle(fillColor: .red)
                model.startGeometryEditor(withType: Polygon.self)
            } label: {
                Text("Red")
            }

            Button {
                model.kmlStyle = KMLStyle(fillColor: .yellow)
                model.startGeometryEditor(withType: Polygon.self)
            } label: {
                Text("Yellow")
            }

            Button {
                model.kmlStyle = KMLStyle(fillColor: .white)
                model.startGeometryEditor(withType: Polygon.self)
            } label: {
                Text("White")
            }

            Button {
                model.kmlStyle = KMLStyle(fillColor: .purple)
                model.startGeometryEditor(withType: Polygon.self)
            } label: {
                Text("Purple")
            }

            Button {
                model.kmlStyle = KMLStyle(fillColor: .orange)
                model.startGeometryEditor(withType: Polygon.self)
            } label: {
                Text("Orange")
            }

            Button {
                model.kmlStyle = KMLStyle(fillColor: .magenta)
                model.startGeometryEditor(withType: Polygon.self)
            } label: {
                Text("Magenta")
            }
        }
    }
}

private extension KMLStyle {
    /// Creates a KML style with an icon URL.
    /// - Parameter iconURL: The icon URL used with the KML icon style.
    convenience init(iconURL: URL) {
        let icon = KMLIcon(url: iconURL)
        
        self.init()
        self.iconStyle = KMLIconStyle(icon: icon)
    }
    
    /// Creates a KML style with a line color.
    /// - Parameter lineColor: The line color used with the KML line style.
    convenience init(lineColor: UIColor) {
        self.init()
        self.lineStyle = KMLLineStyle(color: lineColor, width: 1)
    }
    
    /// Creates a KML style with a fill color.
    /// - Parameter fillColor: The fill color used with the KML polygon style.
    convenience init(fillColor: UIColor) {
        self.init()
        
        let polygonStyle = KMLPolygonStyle(fillColor: fillColor)
        polygonStyle.isFilled = true
        polygonStyle.isOutlined = false
        
        self.polygonStyle = polygonStyle
    }
}
