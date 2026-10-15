// Copyright 2026 Esri
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

struct UpdateLabelsAndSymbolsToScaleForVisualAccessibilityView: View {
    /// The view model for the sample.
    @State private var model = Model()
    
    /// An error from identifying a restaurant, loading the layer or symbol,
    /// creating its swatch, or opening settings.
    @State private var error: (any Error)?
    
    /// The map height available above the bottom controls.
    @State private var mapHeight: CGFloat = 0
    
    /// The screen point to perform an identify operation.
    @State private var identifyScreenPoint: CGPoint?
    
    /// The selected restaurant whose details are shown in the callout, if any.
    @State private var selectedFeature: Feature?
    
    /// The placement of the restaurant details callout, or `nil` when hidden.
    @State private var calloutPlacement: CalloutPlacement?
    
    /// A scale factor relative to the default body text size.
    @ScaledMetric(relativeTo: .body) private var systemTextScale: CGFloat = 1
    
    var body: some View {
        VStack(spacing: 0) {
            mapContent
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.size.height
                } action: { height in
                    mapHeight = height
                }
            ScalingControlsView(model: model, error: $error)
        }
    }
    
    /// The map and its loading and selection interactions.
    private var mapContent: some View {
        MapViewReader { mapView in
            MapView(map: model.map)
                .callout(placement: $calloutPlacement) { _ in
                    if let selectedFeature {
                        RestaurantCalloutView(feature: selectedFeature, mapHeight: mapHeight)
                    }
                }
                .onSingleTapGesture { screenPoint, _ in
                    guard !model.isLoading, !model.map.operationalLayers.isEmpty else { return }
                    model.restaurantsLayer.clearSelection()
                    selectedFeature = nil
                    calloutPlacement = nil
                    identifyScreenPoint = screenPoint
                }
                .task(id: identifyScreenPoint) {
                    guard let identifyScreenPoint = identifyScreenPoint else { return }
                    do {
                        // Identify at most one restaurant near the tap.
                        let result = try await mapView.identify(
                            on: model.restaurantsLayer,
                            screenPoint: identifyScreenPoint,
                            tolerance: 12,
                            maximumResults: 1
                        )
                        // Don't show stale results after another tap
                        // or dismissal.
                        try Task.checkCancellation()
                        guard
                            let feature = result.geoElements.first as? Feature,
                            let location = feature.geometry as? Point
                        else {
                            return
                        }
                        model.restaurantsLayer.selectFeature(feature)
                        selectedFeature = feature
                        calloutPlacement = .geoElement(
                            feature,
                            tapLocation: location
                        )
                    } catch {
                        if !Task.isCancelled {
                            self.error = error
                        }
                    }
                }
                .task {
                    do {
                        try await model.load()
                    } catch {
                        if !Task.isCancelled {
                            self.error = error
                        }
                    }
                }
                .onChange(of: systemTextScale, initial: true) { _, newValue in
                    model.applySystemTextScale(newValue)
                }
                .overlay {
                    if model.isLoading {
                        ProgressView("Loading restaurants…")
                            .padding()
                            .background(.regularMaterial)
                    }
                }
                .overlay(alignment: .top) {
                    TextSizeHelpView(error: $error)
                }
        }
    }
}

extension UpdateLabelsAndSymbolsToScaleForVisualAccessibilityView.Model.RestaurantSymbolError: LocalizedError {
    var errorDescription: String? {
        "The web style did not return a restaurant point symbol."
    }
}

#Preview {
    NavigationStack {
        UpdateLabelsAndSymbolsToScaleForVisualAccessibilityView()
    }
}
