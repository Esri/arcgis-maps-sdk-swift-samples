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

struct FindRouteInTransportNetworkView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The current travel mode selection of the picker.
    @State private var travelModeSelection: TravelModeOption = .fastest
    
    /// A Boolean value indicating whether the user is currently long pressing on the map.
    @State private var longPressing = false
    
    /// A Boolean value indicating whether the reset button is currently disabled.
    @State private var resetDisabled = true
    
    var body: some View {
        MapView(
            map: model.map,
            graphicsOverlays: [model.routeGraphicsOverlay, model.stopGraphicsOverlay]
        )
        .onSingleTapGesture { _, mapPoint in
            // Add a route stop when the on single tap.
            model.addRouteStop(at: mapPoint)
            resetDisabled = false
        }
        .onLongPressAndDragGesture { mapPoint in
            // Add and update a route stop on long press.
            model.addRouteStop(at: mapPoint, replacingLast: longPressing)
            longPressing = true
            resetDisabled = false
        } onEnded: {
            longPressing = false
        }
        .overlay(alignment: .top) {
            Text(model.routeInfo.label ?? "Tap to add a point.")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(8)
                .background(.thinMaterial, ignoresSafeAreaEdges: .horizontal)
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Spacer()
                
                Picker("Travel Mode", selection: $travelModeSelection) {
                    Text("Fastest").tag(TravelModeOption.fastest)
                    Text("Shortest").tag(TravelModeOption.shortest)
                }
                .pickerStyle(.segmented)
                .onChange(of: travelModeSelection) { newMode in
                    model.updateTravelMode(to: newMode)
                }
                
                Spacer()
                
                Button("Reset") {
                    model.reset()
                    resetDisabled = true
                }
                .disabled(resetDisabled)
            }
        }
        .task {
            // Load the default route parameters from the route task when the sample loads.
            model.routeParameters = try? await model.routeTask.makeDefaultParameters()
        }
    }
}

private extension MapView {
    /// Sets a closure to perform when the map view recognizes a long press and drag gesture.
    /// - Parameters:
    ///   - action: The closure to perform when the gesture is recognized.
    ///   - onEnded: The closure to perform when the gesture ends.
    /// - Returns: A new `View` object.
    func onLongPressAndDragGesture(
        perform action: @escaping (Point) -> Void,
        onEnded: @escaping () -> Void
    ) -> some View {
        self
            .onLongPressGesture { _, mapPoint in
                action(mapPoint)
            }
            .gesture(
                LongPressGesture()
                    .simultaneously(with: DragGesture())
                    .onEnded { _ in
                        onEnded()
                    }
            )
    }
}
