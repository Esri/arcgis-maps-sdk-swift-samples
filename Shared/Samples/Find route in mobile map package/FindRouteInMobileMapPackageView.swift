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
import UniformTypeIdentifiers

struct FindRouteInMobileMapPackageView: View {
    /// The view model for the view.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether the file importer interface is showing.
    @State private var fileImporterIsShowing = false
    
    /// The file URL to a local "mmpk" file imported from the file importer.
    @State private var importedFileURL: URL?
    
    var body: some View {
        List {
            // Create a list section for each map package.
            ForEach(model.mapPackages.enumeratedArray(), id: \.offset) { (offset, mapPackage) in
                Section {
                    MobileMapListView(mapPackage: mapPackage)
                } header: {
                    Text(mapPackage.item?.title ?? "Mobile Map Package \(offset + 1)")
                }
            }
        }
        .toolbar {
            // The button used to import mobile map packages.
            ToolbarItem(placement: .bottomBar) {
                Button("Add Package") {
                    fileImporterIsShowing = true
                }
                .fileImporter(
                    isPresented: $fileImporterIsShowing,
                    allowedContentTypes: [.mmpk]
                ) { result in
                    switch result {
                    case .success(let fileURL):
                        importedFileURL = fileURL
                    case .failure(let error):
                        model.error = error
                    }
                }
            }
        }
        .task {
            // Load the San Francisco mobile map package from the bundle when the sample loads.
            guard model.mapPackages.isEmpty else { return }
            await model.addMapPackage(from: .sanFranciscoPackage)
        }
        .task(id: importedFileURL) {
            // Load the new mobile map package when a file URL is imported.
            guard let importedFileURL else { return }
            await model.importMapPackage(from: importedFileURL)
            self.importedFileURL = nil
        }
        .errorAlert(presentingError: $model.error)
    }
}

private extension FindRouteInMobileMapPackageView {
    /// A list of the maps in a given map package.
    struct MobileMapListView: View {
        /// The mobile map package containing the maps.
        @State var mapPackage: MobileMapPackage
        
        var body: some View {
            // Create a list row for each map in the map package.
            ForEach(mapPackage.maps.enumeratedArray(), id: \.offset) { (offset, map) in
                let mapName = map.item?.name ?? "Map \(offset + 1)"
                
                // The navigation link to the map.
                NavigationLink {
                    Group {
                        if let locatorTask = mapPackage.locatorTask {
                            MobileMapView(map: map, locatorTask: locatorTask)
                        } else {
                            MapView(map: map)
                        }
                    }
                    .navigationTitle(mapName)
                } label: {
                    HStack {
                        // The image of the map for the row.
                        Image(uiImage: map.item?.thumbnail?.image ?? UIImage(
                            systemName: "questionmark"
                        )!)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 50)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mapName)
                            
                            HStack {
                                // The symbol indicating whether the map can geocode.
                                if mapPackage.locatorTask != nil {
                                    HStack(spacing: 2) {
                                        Image(systemName: "mappin.circle")
                                        Text("Geocoding")
                                    }
                                }
                                
                                // The symbol indicating whether the map can route.
                                if !map.transportationNetworks.isEmpty {
                                    HStack(spacing: 2) {
                                        Image(systemName: "arrow.triangle.turn.up.right.circle")
                                        Text("Routing")
                                    }
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private extension Collection {
    /// Enumerates a collection as an array of (n, x) pairs, where n represents a consecutive integer
    /// starting at zero and x represents an element of the collection.
    /// - Returns: An array of pairs enumerating the collection.
    func enumeratedArray() -> [(offset: Int, element: Self.Element)] {
        return Array(self.enumerated())
    }
}

private extension UTType {
    /// A type that represents a mobile map package file.
    static let mmpk = UTType(filenameExtension: "mmpk")!
}

private extension URL {
    /// The URL to the local San Francisco mobile map package file.
    static var sanFranciscoPackage: URL {
        Bundle.main.url(forResource: "SanFrancisco", withExtension: "mmpk")!
    }
}
