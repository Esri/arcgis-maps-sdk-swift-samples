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
import UniformTypeIdentifiers
import SwiftUI

struct CreateAndSaveKMLView: View {
    /// The view model for this sample.
    @StateObject var model = Model()
        
    var body: some View {
        MapView(map: model.map)
            .geometryEditor(model.geometryEditor)
            .errorAlert(presentingError: $model.error)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Menu {
                        if !model.isStarted {
                            // If the geometry editor is not started, show the main menu.
                            mainMenuContent
                        } else {
                            // If the geometry editor is started, show the edit menu.
                            editMenuContent
                        }
                    }  label: {
                        Label("Geometry Editor", systemImage: "pencil.tip.crop.circle")
                    }
                    
                    Spacer()
                    
                    Button {
                        model.showingFileExporter = true
                    } label: {
                        Label("Export File", systemImage: "square.and.arrow.up")
                    }
                    .disabled(model.fileExporterButtonIsDisabled)
                }
            }
            .task {
                for await geometry in model.geometryEditor.$geometry {
                    model.geometry = geometry
                }
            }
            .fileExporter(isPresented: $model.showingFileExporter, document: model.kmzFile, contentType: .kmz) { result in
                switch result {
                case .success:
                    // We no longer need the file locally.
                    model.kmzFile.deleteFile()
                    
                    // We no longer have a local file so disable file exporter button.
                    model.fileExporterButtonIsDisabled = true
                case .failure(let error):
                    model.error = error
                }
            }
    }
}

/// A KMZ file that can be used with the native file exporter.
final class KMZFile: FileDocument {
    /// The KML document that is used to create the KMZ file.
    private let document: KMLDocument
    
    /// The temporary directory where the KMZ file will be stored.
    private var temporaryDirectory: URL?
    
    /// The temporary URL to the KMZ file.
    private var temporaryDocumentURL: URL?
    
    static var readableContentTypes = [UTType.kmz]
    
    /// Creates a KMZ file with a KML document.
    /// - Parameter document: The KML document that is used when creating the KMZ file.
    init(document: KMLDocument) {
        self.document = document
    }
    
    // This initializer loads data that has been saved previously.
    init(configuration: ReadConfiguration) throws {
        fatalError("Loading KML files is not supported by this sample")
    }
    
    // This will be called when the system wants to write our data to disk
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let temporaryDocumentURL else { return FileWrapper() }
        return try FileWrapper(url: temporaryDocumentURL)
    }
    
    /// Deletes the temporarily stored KMZ file.
    func deleteFile() {
        guard let url = temporaryDirectory else { return }
        try? FileManager.default.removeItem(at: url)
    }
    
    /// Saves the KML document as a KMZ file to a temporary location.
    func saveFile() async throws {
        temporaryDirectory = FileManager.createTemporaryDirectory()
        
        if document.name.isEmpty {
            document.name = "Untitled"
        }
        
        temporaryDocumentURL = temporaryDirectory?.appendingPathComponent("\(document.name).kmz")
        
        try await document.save(to: temporaryDocumentURL!)
    }
}

private extension FileManager {
    /// Creates a temporary directory and returns the URL of the created directory.
    static func createTemporaryDirectory() -> URL {
        // swiftlint:disable:next force_try
        try! FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: FileManager.default.temporaryDirectory,
            create: true
        )
    }
}

private extension UTType {
    /// A type that represents a KMZ file.
    static let kmz = UTType(filenameExtension: "kmz")!
}

#Preview {
    NavigationView {
        CreateAndSaveKMLView()
    }
}
