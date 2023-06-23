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

import SwiftUI
import ArcGIS

extension SetVisibilityOfSubtypeSublayerView {
    /// The view model for this sample.
    class Model: ObservableObject {
        /// A map with a streets basemap style.
        let map = Map(basemapStyle: .arcGISStreetsNight)
        
        /// A feature table for the electrical network in this sample.
        private let featureTable = ServiceFeatureTable(url: .featureServiceURL)
        
        /// A subtype feature layer created from the service feature table.
        private let subtypeFeatureLayer: SubtypeFeatureLayer
        
        /// The subtype sublayer of the subtype feature layer in this sample.
        private var subtypeSublayer: SubtypeSublayer?
        
        /// The renderer of the subtype feature layer.
        private var originalRenderer: Renderer?
        
        /// The status text to display to the user.
        @Published var statusText = ""
        
        /// The  subtype sublayer's label definition.
        private var labelDefinition: LabelDefinition = {
            // Make and stylize the text symbol.
            let textSymbol = TextSymbol()
            textSymbol.backgroundColor = .clear
            textSymbol.outlineColor = .white
            textSymbol.color = .blue
            textSymbol.haloColor = .white
            textSymbol.haloWidth = 2
            textSymbol.size = 10.5
            // Make a label definition and adjust its properties.
            let labelExpression = SimpleLabelExpression(simpleExpression: "[nominalvoltage]")
            let labelDefinition = LabelDefinition(labelExpression: labelExpression, textSymbol: textSymbol)
            labelDefinition.placement = .pointAboveRight
            labelDefinition.usesCodedValues = true
            return labelDefinition
        }()
        
        // The formatter used to generate strings from scale values.
        private let scaleFormatter: NumberFormatter = {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            numberFormatter.maximumFractionDigits = 0
            return numberFormatter
        }()
        
        /// A Boolean value indicating whether the settings should be presented.
        @Published var isShowingSettings = false
        
        /// A Boolean value indicating whether to show the subtype sublayer.
        @Published var showsSublayer = true
        
        /// A Boolean value indicating whether to show the subtype sublayer's renderer.
        @Published var showsOriginalRenderer = true
        
        /// The current scale of the map.
        @Published var currentScale: Double = .zero
        
        /// The map's current scale value in text.
        @Published var currentScaleText: String = ""
        
        /// The subtype sublayer's minimum scale value in text.
        @Published var minimumScaleText: String = "Not Set"
        
        init() {
            map.initialViewpoint = .initialViewpoint
            subtypeFeatureLayer = SubtypeFeatureLayer(featureTable: featureTable)
            subtypeFeatureLayer.scalesSymbols = false
        }
        
        deinit {
            ArcGISEnvironment.authenticationManager.arcGISCredentialStore.removeAll()
        }
        
        /// Performs important tasks including adding credentials, loading and adding operational layers.
        @MainActor
        func setup() async {
            do {
                try await ArcGISEnvironment.authenticationManager.arcGISCredentialStore.add(.publicSample)
                try await subtypeFeatureLayer.load()
                map.addOperationalLayer(subtypeFeatureLayer)
                subtypeSublayer = subtypeFeatureLayer.sublayer(withSubtypeName: "Street Light")
                subtypeSublayer?.labelsAreEnabled = true
                originalRenderer = subtypeSublayer?.renderer
                subtypeSublayer?.addLabelDefinition(labelDefinition)
            } catch {
                statusText = error.localizedDescription
            }
        }
        
        func toggleSublayer() {
            subtypeSublayer?.isVisible = showsSublayer
        }
        
        func toggleRenderer() {
            if showsOriginalRenderer {
                subtypeSublayer?.renderer = originalRenderer
            } else {
                let symbol = SimpleMarkerSymbol(style: .diamond, color: .systemPink, size: 20)
                let alternativeRenderer = SimpleRenderer(symbol: symbol)
                subtypeSublayer?.renderer = alternativeRenderer
            }
        }
        
        func formatCurrentScaleText() {
            currentScaleText = String(format: "1:%@", scaleFormatter.string(from: currentScale as NSNumber)!)
        }
        
        func setMinimumScale() {
            minimumScaleText = currentScaleText
            subtypeSublayer?.minScale = currentScale
        }
    }
}

private extension ArcGISCredential {
    /// The public credentials for the data in this sample.
    /// - Note: Never hardcode login information in a production application. This is done solely
    /// for the sake of the sample.
    static var publicSample: ArcGISCredential {
        get async throws {
            try await TokenCredential.credential(
                for: URL.featureServiceURL,
                username: "viewer01",
                password: "I68VGU^nMurF"
            )
        }
    }
}

private extension URL {
    static var featureServiceURL: URL {
        URL(string: "https://sampleserver7.arcgisonline.com/server/rest/services/UtilityNetwork/NapervilleElectric/FeatureServer/0")!
    }
}

private extension Viewpoint {
    /// The initial viewpoint to be displayed when the sample is first opened.
    static var initialViewpoint: Viewpoint {
        .init(
            boundingGeometry: Envelope(
                xRange: (-9812691.11079696)...(-9812377.9447607),
                yRange: (5128687.20710657)...(5128865.36767282),
                spatialReference: .webMercator
            )
        )
    }
}
