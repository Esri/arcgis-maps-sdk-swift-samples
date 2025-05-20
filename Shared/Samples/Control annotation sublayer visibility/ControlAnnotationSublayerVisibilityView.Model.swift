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

extension ControlAnnotationSublayerVisibilityView {
    /// The view model for this sample.
    @MainActor
    class Model: ObservableObject {
        /// A map from the mobile map package.
        @Published private(set) var map = Map()
        
        /// The mobile map package.
        private var mobileMapPackage: MobileMapPackage!
        
        /// The annotation layer in the map.
        private var annotationLayer: AnnotationLayer {
            map.operationalLayers.first(where: { $0 is AnnotationLayer }) as! AnnotationLayer
        }
        
        /// The closed annotation sublayer.
        private var closedSublayer: AnnotationSublayer {
            annotationLayer.subLayerContents[0] as! AnnotationSublayer
        }
        
        /// The open annotation sublayer.
        private var openSublayer: AnnotationSublayer {
            annotationLayer.subLayerContents[1] as! AnnotationSublayer
        }
        
        /// A Boolean value indicating whether to show the closed annotation sublayer.
        @Published var showsClosedSublayer = true
        
        /// A Boolean value indicating whether to show the open annotation sublayer.
        @Published var showsOpenSublayer = true
        
        /// A Boolean value indicating whether the open annotation sublayer is visible at the current extent.
        @Published var visibleAtCurrentExtent = false
        
        /// The min scale of the open annotation sublayer.
        private var minScale: Double?
        
        /// The max scale of the open annotation sublayer.
        private var maxScale: Double?
        
        /// The current scale of the map.
        var currentScale: Double = .zero {
            didSet {
                formatCurrentScaleText()
                guard minScale != nil && maxScale != nil else { return }
                visibleAtCurrentExtent = openSublayer.isVisible(atScale: currentScale)
            }
        }
        
        /// The map's current scale value in text.
        @Published var currentScaleText = ""
        
        /// The min and max scale of the open annotation layer in text.
        @Published var minMaxScaleText = ""
        
        /// Loads a local mobile map package.
        func loadMobileMapPackage() async throws {
            mobileMapPackage = MobileMapPackage(fileURL: .gasDevicePackage)
            try await mobileMapPackage.load()
            guard let map = mobileMapPackage.maps.first else { return }
            self.map = map
        }
        
        /// Sets the visibility of the closed annotation sublayer.
        /// - Parameter visibility: The visibility of the sublayer.
        func setClosedSublayerVisibility(_ visibility: Bool) {
            closedSublayer.isVisible = visibility
        }
        
        /// Sets the visibility of the open annotation sublayer.
        /// - Parameter visibility: The visibility of the sublayer.
        func setOpenSublayerVisibility(_ visibility: Bool) {
            openSublayer.isVisible = visibility
        }
        
        /// Sets the min and max scale and formats the min-max scale text.
        func setScaleText() {
            minScale = openSublayer.minScale
            maxScale = openSublayer.maxScale
            
            formatMinMaxScaleText()
        }
        
        /// Formats the current scale text.
        private func formatCurrentScaleText() {
            currentScaleText = "1:\(currentScale.formatted(.decimal))"
        }
        
        /// Formats the min-max scale text.
        private func formatMinMaxScaleText() {
            guard let minScale, let maxScale else { return }
            minMaxScaleText = "Open (1:\(minScale.formatted(.decimal)) - 1:\(maxScale.formatted(.decimal)))"
        }
    }
}

private extension FormatStyle where Self == FloatingPointFormatStyle<Double> {
    /// Formats the double with zero decimals places of precision.
    static var decimal: Self {
        Self.number.precision(.fractionLength(0))
    }
}

private extension URL {
    /// The URL to the local Gas Device Annotation mobile map package file.
    static var gasDevicePackage: URL {
        Bundle.main.url(forResource: "GasDeviceAnno", withExtension: "mmpk")!
    }
}
