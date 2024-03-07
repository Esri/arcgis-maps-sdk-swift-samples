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
    @State private var selectedLanguage: BasemapStyleLanguage = .global
    
    /// The selected locale.
    @State private var selectedLocale: Locale = .current
    
    var body: some View {
        MapView(map: model.map)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    languageMenu
                        .onChange(of: selectedLanguage) { newLanguage in
                            model.setBasemapLanguage(newLanguage)
                        }
                    Spacer()
                }
            }
    }
    
    private var languageMenu: some View {
        Menu("Language Settings") {
            Section("Language Strategy") {
                // A picker for specific languages.
                Menu("Specific Language") {
                    Picker(selectedLanguage.label, selection: $selectedLocale) {
                        ForEach(model.languages, id: \.1) { label, code in
                            Text(label).tag(Locale(identifier: code))
                        }
                    }
                    .onChange(of: selectedLocale) { newLocale in
                        selectedLanguage = .specific(newLocale)
                    }
                }
                
                // A series of buttons for general language strategies.
                ForEach(
                    [
                        // Use the default language setting for the basemap style.
                        BasemapStyleLanguage.default,
                        // Use the global language (English) for basemap labels.
                        BasemapStyleLanguage.global,
                        // Uses country-local language for basemap labels.
                        BasemapStyleLanguage.local,
                        // Use the system locale language for basemap labels.
                        BasemapStyleLanguage.applicationLocale
                    ],
                    id: \.label
                ) { basemapStyleLanguage in
                    Button {
                        selectedLanguage = basemapStyleLanguage
                    } label: {
                        HStack {
                            Text(basemapStyleLanguage.label)
                            Spacer()
                            if selectedLanguage == basemapStyleLanguage {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
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
                    parameters: BasemapStyleParameters(language: .global)
                )
            )
            // Start with a viewpoint over Bulgaria, Greece, and Turkey.
            // They use three different alphabets: Cyrillic, Greek, and Latin, respectively.
            map.initialViewpoint = Viewpoint(center: Point(x: 3_000_000, y: 4_500_000), scale: 1e7)
            return map
        }()
        
        /// The language label and Esri language code for the basemap style parameters.
        let languages: KeyValuePairs<String, String> = [
            "🇧🇬 Bulgarian": "bg",
            "🇬🇷 Greek": "el",
            "🇹🇷 Turkish": "tr"
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
        case .specific(let locale):
            return "Specific: \(locale.identifier)"
        @unknown default:
            fatalError("Unknown basemap style language option")
        }
    }
}
