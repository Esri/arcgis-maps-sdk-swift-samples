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

extension CreateDynamicBasemapGalleryView {
    /// A view for selecting a basemap.
    struct BasemapGallery: View {
        /// The view model for the sample.
        @ObservedObject var model: Model
        
        var body: some View {
            Form {
                Picker("Style", selection: $model.basemapStyle) {
                    ForEach(model.stylesInfo, id: \.style) { styleInfo in
                        HStack {
                            if let image = styleInfo.thumbnail?.image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 50)
                            }
                            
                            Text(styleInfo.styleName)
                        }
                        .tag(styleInfo.style)
                    }
                }
                .pickerStyle(.navigationLink)
                
                Picker("Language", selection: $model.basemapStyleLanguage) {
                    Section("Strategy") {
                        ForEach(model.languageStrategies, id: \.self) { strategy in
                            Text(strategy.label)
                                .tag(BasemapStyleLanguage.strategic(strategy))
                        }
                    }
                    
                    Section("Specific") {
                        ForEach(model.languages, id: \.self) { language in
                            Text(language.label ?? "Unknown")
                                .tag(BasemapStyleLanguage.specific(language))
                        }
                    }
                }
                .disabled(model.basemapStyleInfo?.languageStrategies.isEmpty ?? true)
                
                Picker("Worldview", selection: $model.worldviewCode) {
                    ForEach(model.worldviews, id: \.?.code) { worldview in
                        Text(worldview?.displayName ?? "")
                            .tag(worldview?.code)
                    }
                }
                .disabled(model.basemapStyleInfo?.worldviews.isEmpty ?? true)
            }
        }
    }
}

private extension BasemapStyleLanguageStrategy {
    /// A human-readable label for the basemap style language strategy.
    var label: String {
        switch self {
        case .default: "Default"
        case .global: "Global"
        case .local: "Local"
        case .applicationLocale: "System Locale"
        @unknown default:
            fatalError("Unknown basemap style language strategy.")
        }
    }
}

private extension Locale.Language {
    /// A human-readable label for the language.
    var label: String? {
        Locale.current.localizedString(forIdentifier: self.maximalIdentifier)
    }
}
