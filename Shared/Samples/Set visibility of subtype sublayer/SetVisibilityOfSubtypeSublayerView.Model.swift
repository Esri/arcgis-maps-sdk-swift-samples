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
import Foundation

extension SetVisibilityOfSubtypeSublayerView {
    /// The view model for this sample.
    @MainActor
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
        
        /// The  subtype sublayer's label definition.
        private let labelDefinition: LabelDefinition = {
            // Make and stylize the text symbol.
            let textSymbol = TextSymbol(color: .blue, size: 10.5)
            textSymbol.backgroundColor = .clear
            textSymbol.outlineColor = .white
            textSymbol.haloColor = .white
            textSymbol.haloWidth = 2
            // Make a label definition and adjust its properties.
            let labelExpression = SimpleLabelExpression(simpleExpression: "[nominalvoltage]")
            let labelDefinition = LabelDefinition(labelExpression: labelExpression, textSymbol: textSymbol)
            labelDefinition.placement = .pointAboveRight
            labelDefinition.usesCodedValues = true
            return labelDefinition
        }()
        
        /// The current scale of the map.
        var currentScale: Double = .zero
        
        /// The map's current scale value in text.
        @Published var currentScaleText: String = ""
        
        /// The subtype sublayer's minimum scale value in text.
        @Published private(set) var minimumScaleText: String = "Not Set"
        
        init() {
            map.initialViewpoint = .initialViewpoint
            subtypeFeatureLayer = SubtypeFeatureLayer(featureTable: featureTable)
            subtypeFeatureLayer.scalesSymbols = false
        }
        
        deinit {
            ArcGISEnvironment.authenticationManager.arcGISCredentialStore.removeAll()
        }
        
        /// Performs important tasks including adding credentials, loading and adding operational layers.
        func setup() async throws {
            try await ArcGISEnvironment.authenticationManager.arcGISCredentialStore.add(.publicSample)
            try await subtypeFeatureLayer.load()
            map.addOperationalLayer(subtypeFeatureLayer)
            guard let subtypeSublayer = subtypeFeatureLayer.sublayer(withSubtypeName: "Street Light") else {
                throw SetupError.cannotFindSublayer
            }
            subtypeSublayer.labelsAreEnabled = true
            originalRenderer = subtypeSublayer.renderer
            subtypeSublayer.addLabelDefinition(labelDefinition)
            self.subtypeSublayer = subtypeSublayer
        }
        
        func toggleSublayer(isVisible: Bool) {
            subtypeSublayer?.isVisible = isVisible
        }
        
        func toggleRenderer(showsOriginalRenderer: Bool) {
            if showsOriginalRenderer {
                subtypeSublayer?.renderer = originalRenderer
            } else {
                let symbol = SimpleMarkerSymbol(style: .diamond, color: .systemPink, size: 20)
                let alternativeRenderer = SimpleRenderer(symbol: symbol)
                subtypeSublayer?.renderer = alternativeRenderer
            }
        }
        
        func formatCurrentScaleText() {
            currentScaleText = "1:\(currentScale.formatted(.decimal))"
        }
        
        func setMinimumScale() {
            minimumScaleText = currentScaleText
            subtypeSublayer?.minScale = currentScale
        }
    }
}

extension SetVisibilityOfSubtypeSublayerView.Model {
    enum SetupError: LocalizedError {
        case cannotFindSublayer
        
        var errorDescription: String? {
            switch self {
            case .cannotFindSublayer:
                return NSLocalizedString(
                    "Cannot find subtype sublayer.",
                    comment: "Error thrown when subtype sublayer cannot be found."
                )
            }
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

private extension FormatStyle where Self == FloatingPointFormatStyle<Double> {
    /// Formats the double with zero decimals places of precision.
    static var decimal: Self {
        Self.number.precision(.fractionLength(0))
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
