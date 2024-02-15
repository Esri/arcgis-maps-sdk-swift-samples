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

struct ListSpatialReferenceTransformationsView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    /// The visible area of the map view.
    @State private var visibleArea: ArcGIS.Polygon?
    
    /// A Boolean value indicating whether the transformations list should be filtered using the current map extent.
    @State private var filterByMapExtent = false
    
    /// A Boolean value indicating whether the file importer interface is presented.
    @State private var fileImporterIsPresented = false
    
    /// The error shown in the error alert.
    @State private var error: Error?
    
    var body: some View {
        VStack(spacing: 0) {
            MapView(map: model.map, graphicsOverlays: [model.graphicsOverlay])
                .onVisibleAreaChanged { visibleArea = $0 }
                .task {
                    // Set the transformations list once the map's spatial reference has loaded.
                    do {
                        try await model.map.load()
                        model.updateTransformationsList()
                    } catch {
                        self.error = error
                    }
                }
                .errorAlert(presentingError: $error)
            
            NavigationView {
                TransformationsList(model: model)
                    .navigationTitle("Transformations")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            transformationsMenu
                        }
                    }
            }
            .navigationViewStyle(.stack)
        }
    }
    
    /// A menu containing actions relating to the list of transformations.
    private var transformationsMenu: some View {
        Menu("Transformations", systemImage: "ellipsis") {
            Picker("Filter Transformations", selection: $filterByMapExtent) {
                Label("All Transformations", systemImage: "square.grid.2x2")
                    .tag(false)
                Label("Suitable for Extent", systemImage: "line.3.horizontal.decrease.circle")
                    .tag(true)
            }
            .pickerStyle(.inline)
            .onChange(of: filterByMapExtent) { newValue in
                model.updateTransformationsList(withExtent: newValue ? visibleArea?.extent : nil)
            }
            
            Link(destination: .projectionEngineDataDownloads) {
                Label("Download Data", systemImage: "arrow.down.circle")
            }
            
            Button("Set Data Directory", systemImage: "folder") {
                fileImporterIsPresented = true
            }
        }
        .fileImporter(
            isPresented: $fileImporterIsPresented,
            allowedContentTypes: [.folder]
        ) { result in
            do {
                switch result {
                case .success(let fileURL):
                    try model.setProjectionEngineDataURL(fileURL)
                case .failure(let error):
                    throw error
                }
            } catch {
                self.error = error
            }
        }
    }
}

private extension ListSpatialReferenceTransformationsView {
    struct TransformationsList: View {
        /// The view model for the sample.
        @ObservedObject var model: Model
        
        /// The missing Projection Engine filenames for the tapped transformation.
        @State private var missingFilenames: [String] = []
        
        var body: some View {
            List(model.transformations, id: \.self) { transformation in
                Button {
                    if transformation.isMissingProjectionEngineFiles {
                        missingFilenames = model.missingProjectionEngineFilenames(
                            for: transformation
                        )
                    } else {
                        model.selectTransformation(transformation)
                    }
                } label: {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(transformation.name.replacingOccurrences(of: "_", with: " "))
                            Spacer()
                            if transformation == model.selectedTransformation {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        
                        if transformation.isMissingProjectionEngineFiles {
                            Text("Missing Grid Files")
                                .font(.caption)
                                .opacity(0.75)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .alert(
                "Missing Grid Files:",
                isPresented: Binding(
                    get: { !missingFilenames.isEmpty },
                    set: { _ in missingFilenames = [] }),
                presenting: missingFilenames,
                actions: { _ in },
                message: { filenames in
                    let message = """
                    \(filenames.joined(separator: ",\n"))
                    
                    See the README file for instructions on adding Projection Engine data to the app.
                    """
                    
                    Text(message)
                }
            )
        }
    }
}

private extension URL {
    /// A URL to the Projection Engine Data Downloads on ArcGIS for Developers.
    static var projectionEngineDataDownloads: URL {
        URL(string: "https://developers.arcgis.com/downloads/#pedata")!
    }
}

#Preview {
    ListSpatialReferenceTransformationsView()
}
