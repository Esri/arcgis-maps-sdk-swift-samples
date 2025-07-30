// Copyright 2024 Esri
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

extension StyleGeometryTypesWithSymbolsView {
    /// Controls for editing the symbols contained in a given model.
    struct SymbolsEditor: View {
        /// The view model for the sample containing the symbols to edit.
        @ObservedObject var model: Model
        
        /// The type of geometry currently being edited.
        @State private var selectedGeometryType: GeometryType = .point
        
        var body: some View {
            Form {
                Section {
                    EnumerationPicker("Geometry", selection: $selectedGeometryType)
                        .pickerStyle(.segmented)
                        .animation(.default, value: selectedGeometryType)
                }
                
                switch selectedGeometryType {
                case .point:
                    SimpleMarkerSymbolEditor(symbol: model.pointSymbol)
                case .polyline:
                    SimpleLineSymbolEditor(symbol: model.polylineSymbol)
                case .polygon:
                    SimpleFillSymbolEditor(symbol: model.polygonSymbol)
                }
            }
        }
    }
    
    /// The types of the geometries supported by this sample.
    private enum GeometryType: CaseIterable, LabeledEnumeration {
        case point, polyline, polygon
        
        /// A human-readable label for the geometry type.
        var label: String {
            switch self {
            case .point: "Point"
            case .polyline: "Polyline"
            case .polygon: "Polygon"
            }
        }
    }
}

/// Controls for editing a simple marker symbol's properties.
private struct SimpleMarkerSymbolEditor: View {
    /// The simple marker symbol to edit.
    let symbol: SimpleMarkerSymbol
    
    /// The symbol's style selected by the picker.
    @State private var selectedStyle: SimpleMarkerSymbol.Style = .circle
    
    /// The symbol's color selected by the picker.
    @State private var selectedColor: Color = .clear
    
    /// The symbol's size selected by the stepper.
    @State private var selectedSize: Int = .zero
    
    var body: some View {
        EnumerationPicker("Style", selection: $selectedStyle)
            .onChange(of: selectedStyle) {
                symbol.style = selectedStyle
            }
        
        ColorPicker("Color", selection: $selectedColor)
            .onChange(of: selectedColor) {
                symbol.color = UIColor(selectedColor)
            }
        
        Stepper("Size: \(selectedSize)", value: $selectedSize, in: 5...15)
            .onChange(of: selectedSize) {
                symbol.size = CGFloat(selectedSize)
            }
            .onAppear {
                selectedStyle = symbol.style
                selectedColor = Color(uiColor: symbol.color)
                selectedSize = Int(symbol.size)
            }
    }
}

/// Controls for editing a simple line symbol's properties.
private struct SimpleLineSymbolEditor: View {
    /// The simple line symbol to edit.
    let symbol: SimpleLineSymbol
    
    /// The symbol's style selected by the picker.
    @State private var selectedStyle: SimpleLineSymbol.Style = .noLine
    
    /// The symbol's color selected by the picker.
    @State private var selectedColor: Color = .clear
    
    /// The symbol's width selected by the stepper.
    @State private var selectedWidth: Int = .zero
    
    var body: some View {
        EnumerationPicker("Style", selection: $selectedStyle)
            .onChange(of: selectedStyle) {
                symbol.style = selectedStyle
            }
        
        ColorPicker("Color", selection: $selectedColor)
            .onChange(of: selectedColor) {
                symbol.color = UIColor(selectedColor)
            }
        
        Stepper("Width: \(selectedWidth)", value: $selectedWidth, in: 1...10)
            .onChange(of: selectedWidth) {
                symbol.width = CGFloat(selectedWidth)
            }
            .onAppear {
                selectedStyle = symbol.style
                selectedColor = Color(uiColor: symbol.color)
                selectedWidth = Int(symbol.width)
            }
    }
}

/// Controls for editing a simple fill symbol's properties.
private struct SimpleFillSymbolEditor: View {
    /// The simple fill symbol to edit.
    let symbol: SimpleFillSymbol
    
    /// The symbol's style selected by the picker.
    @State private var selectedStyle: SimpleFillSymbol.Style = .noFill
    
    /// The symbol's color selected by the picker.
    @State private var selectedColor: Color = .clear
    
    var body: some View {
        EnumerationPicker("Style", selection: $selectedStyle)
            .onChange(of: selectedStyle) {
                symbol.style = selectedStyle
            }
        
        ColorPicker("Color", selection: $selectedColor)
            .onChange(of: selectedColor) {
                symbol.color = UIColor(selectedColor)
            }
        
        Section("Outline") {
            SimpleLineSymbolEditor(symbol: symbol.outline as! SimpleLineSymbol)
        }
        .onAppear {
            selectedStyle = symbol.style
            selectedColor = Color(uiColor: symbol.color)
        }
    }
}

/// A picker for selecting a value from an enumeration's cases.
private struct EnumerationPicker<T: LabeledEnumeration>: View {
    /// The title of the picker.
    private let title: String
    
    /// A binding to a property that determines the currently-selected style.
    @Binding private var selection: T
    
    init(_ title: String, selection: Binding<T>) {
        self.title = title
        self._selection = selection
    }
    
    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(T.allCases, id: \.self) { style in
                Text(style.label)
            }
        }
#if targetEnvironment(macCatalyst)
        // Workaround for bug where the picker selection doesn't update when the
        // binding value changes on Mac Catalyst.
        .id(selection)
#endif
    }
}

// MARK: LabeledEnumeration

/// A protocol describing an enumeration with labels.
private protocol LabeledEnumeration: Hashable {
    static var allCases: [Self] { get }
    var label: String { get }
}

extension SimpleMarkerSymbol.Style: LabeledEnumeration {
    fileprivate static var allCases: [Self] {
        return [.circle, .cross, .diamond, .square, .triangle, .x]
    }
    
    /// A human-readable label for the simple marker symbol style.
    fileprivate var label: String {
        switch self {
        case .circle: "Circle"
        case .cross: "Cross"
        case .diamond: "Diamond"
        case .square: "Square"
        case .triangle: "Triangle"
        case .x: "X"
        @unknown default: "Unknown"
        }
    }
}

extension SimpleLineSymbol.Style: LabeledEnumeration {
    fileprivate static var allCases: [Self] {
        return [.dash, .dashDot, .dashDotDot, .dot, .longDash, .longDashDot, .noLine, .shortDash, .shortDashDot, .shortDashDotDot, .shortDot, .solid]
    }
    
    /// A human-readable label for the simple line symbol style.
    fileprivate var label: String {
        switch self {
        case .dash: "Dash"
        case .dashDot: "Dash Dot"
        case .dashDotDot: "Dash Dot Dot"
        case .dot: "Dot"
        case .longDash: "Long Dash"
        case .longDashDot: "Long Dash Dot"
        case .noLine: "No Line"
        case .shortDash: "Short Dash"
        case .shortDashDot: "Short Dash Dot"
        case .shortDashDotDot: "Short Dash Dot Dot"
        case .shortDot: "Short Dot"
        case .solid: "Solid"
        @unknown default: "Unknown"
        }
    }
}

extension SimpleFillSymbol.Style: LabeledEnumeration {
    fileprivate static var allCases: [Self] {
        return [.backwardDiagonal, .cross, .diagonalCross, .forwardDiagonal, .horizontal, .noFill, .solid, .vertical]
    }
    
    /// A human-readable label for the simple fill symbol style.
    fileprivate var label: String {
        switch self {
        case .backwardDiagonal: "Backward Diagonal"
        case .cross: "Cross"
        case .diagonalCross: "Diagonal Cross"
        case .forwardDiagonal: "Forward Diagonal"
        case .horizontal: "Horizontal"
        case .noFill: "No Fill"
        case .solid: "Solid"
        case .vertical: "Vertical"
        @unknown default: "Unknown"
        }
    }
}
