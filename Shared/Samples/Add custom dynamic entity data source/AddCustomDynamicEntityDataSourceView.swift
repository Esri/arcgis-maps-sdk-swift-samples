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

struct AddCustomDynamicEntityDataSourceView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The point on the screen the user tapped.
    @State private var tappedScreenPoint: CGPoint?
    
    /// The placement of the callout.
    @State private var calloutPlacement: CalloutPlacement?
    
    /// A dynamic entity observation that was selected on the screen.
    @State private var selectedObservation: DynamicEntityObservation?
    
    var body: some View {
        MapViewReader { proxy in
            MapView(map: model.map)
                .onSingleTapGesture { screenPoint, _  in
                    tappedScreenPoint = screenPoint
                    
                    // Hides the callout.
                    calloutPlacement = nil
                }
                .callout(placement: $calloutPlacement.animation(.default.speed(2))) { _ in
                    let attributes = selectedObservation!.attributes
                    VStack(alignment: .leading) {
                        // Display all the attributes in the callout.
                        ForEach(Array(attributes.sorted(by: { $0.key < $1.key })), id: \.key) { item in
                            Text("\(item.key): \(item.value as? String ?? "")")
                        }
                    }
                }
                .task(id: tappedScreenPoint) {
                    guard let tappedScreenPoint = tappedScreenPoint,
                          let identifyResult = try? await proxy.identify(
                            on: model.dynamicEntityLayer,
                            screenPoint: tappedScreenPoint,
                            tolerance: 2
                          ),
                          let firstObservation = identifyResult.geoElements.first as? DynamicEntityObservation else { return }
                    
                    // Set the callout placement to the observation that was tapped on.
                    calloutPlacement = .geoElement(firstObservation)
                    selectedObservation = firstObservation
                }
        }
    }
}
