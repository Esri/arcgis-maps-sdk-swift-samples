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

struct ConfigureBasemapStyleParametersView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The selected basemap style language strategy.
    @State private var selectedLanguage: BasemapStyleLanguage = .strategic(.global)
    
    var body: some View {
        MapView(map: model.map)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    languageMenu
                    Spacer()
                }
            }
    }
    
    private var languageMenu: some View {
        Menu("Language Settings") {
            Menu("Strategic") {
                ForEach(
                    [BasemapStyleLanguageStrategy.default, .global, .local, .applicationLocale],
                    id: \.label
                ) { strategy in
                    Button {
                        selectedLanguage = .strategic(strategy)
                    } label: {
                        if selectedLanguage.strategy == strategy {
                            Label(strategy.label, systemImage: "checkmark")
                        } else {
                            Text(strategy.label)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Menu("Specific") {
                ForEach(model.languages, id: \.1) { label, languageCode in
                    Button {
                        selectedLanguage = .specific(.init(languageCode: languageCode))
                    } label: {
                        if selectedLanguage.localeLanguage?.languageCode == languageCode {
                            Label(label, systemImage: "checkmark")
                        } else {
                            Text(label)
                        }
                    }
                }
            }
        }
        .menuOrder(.fixed)
        .labelStyle(.titleAndIcon)
        .onChange(of: selectedLanguage) {
            model.setBasemapLanguage(selectedLanguage)
        }
    }
}

private extension ConfigureBasemapStyleParametersView {
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    class Model: ObservableObject {
        /// A map with OpenStreetMap light gray basemap.
        let map: Map = {
            let map = Map(
                basemap: Basemap(
                    // An OpenStreetMap basemap style is used to support localization.
                    style: .osmLightGray,
                    // Set the language strategy to global to use English.
                    parameters: BasemapStyleParameters(language: .strategic(.global))
                )
            )
            // Start with a viewpoint over Bulgaria, Greece, and Turkey.
            // They use three different alphabets: Cyrillic, Greek, and Latin, respectively.
            map.initialViewpoint = Viewpoint(center: Point(x: 3_000_000, y: 4_500_000), scale: 1e7)
            return map
        }()
        
        /// The language label and Esri language code for the basemap style parameters.
        let languages: KeyValuePairs<String, Locale.LanguageCode> = [
            "🇧🇬 Bulgarian": .bulgarian,
            "🇬🇷 Greek": .greek,
            "🇹🇷 Turkish": .turkish
        ]
        
        /// Sets the basemap style parameter with a language strategy.
        /// - Parameter language: The language setting for the basemap.
        func setBasemapLanguage(_ language: BasemapStyleLanguage) {
            let parameters = BasemapStyleParameters(language: language)
            map.basemap = Basemap(style: .osmLightGray, parameters: parameters)
        }
    }
}

private extension BasemapStyleLanguage {
    var localeLanguage: Locale.Language? {
        if case let .specific(language) = self {
            return language
        } else {
            return nil
        }
    }
    
    var strategy: BasemapStyleLanguageStrategy? {
        if case let .strategic(strategy) = self {
            return strategy
        } else {
            return nil
        }
    }
}

private extension BasemapStyleLanguageStrategy {
    /// A human-readable label for the basemap style language.
    var label: String {
        switch self {
        case .default:
            return "Default Language"
        case .global:
            return "Global"
        case .local:
            return "Local"
        case .applicationLocale:
            return "System Locale"
        @unknown default:
            fatalError("Unknown basemap style language strategy")
        }
    }
}
