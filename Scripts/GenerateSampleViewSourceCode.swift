// Copyright 2022 Esri
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

// This script recursively iterates through the samples directory and generates
// a string that is the array representation of type `[Sample]`, and replaces
// the code stub in the template file, so that all the sample SwiftUI Views
// are available when the project compiles.
//
// It takes 3 arguments.
// The first is a path to the samples directory, i.e., $SRCROOT/Shared/Samples.
// The second is a path to the template file, i.e., *.tache.
// The third is a path to the output generated file.

import Foundation

// MARK: Model

/// A sample metadata retrieved from its `README.metadata.json` file.
/// - Note: More about the schema at `common-samples/wiki/README.metadata.json`.
private struct SampleMetadata: Decodable {
    /// The title of the sample.
    let title: String
    /// The description of the sample.
    let description: String
    /// The relative paths to the code snippets.
    let snippets: [String]
    /// The ArcGIS Online Portal Item IDs.
    let offlineData: [String]?
    /// The tags and relevant APIs of the sample.
    let keywords: [String]
}

extension SampleMetadata {
    /// The SwiftUI View name of the root view of the sample. It is the same as
    /// the first filename without extension in the snippets array.
    var viewName: Substring {
        // E.g., ["DisplayMapView.swift", "SomeView.swift"] -> DisplayMapView
        snippets.first!.dropLast(6)
    }
    
    /// The struct name of a sample which is derived by dropping "View" from
    /// the name of the root view.
    var structName: Substring {
        // E.g., DisplayMapView -> DisplayMap
        viewName.dropLast(4)
    }
}

// MARK: Script Entry

private let arguments = CommandLine.arguments

guard arguments.count == 4 else {
    print("Invalid number of arguments.")
    exit(1)
}

let samplesDirectoryURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
let templateURL = URL(fileURLWithPath: arguments[2], isDirectory: false)
let outputFileURL = URL(fileURLWithPath: arguments[3], isDirectory: false)

private let sampleMetadata: [SampleMetadata] = {
    do {
        // Finds all subdirectories under the root samples directory.
        let decoder = JSONDecoder()
        // Converts snake-case key "offline_data" to camel-case "offlineData".
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        // Does a shallow traverse of the top level of samples directory.
        return try FileManager.default.contentsOfDirectory(at: samplesDirectoryURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            .filter(\.hasDirectoryPath)
            .compactMap { url in
                // Try to access the metadata file under a subdirectory.
                guard let data = try? Data(contentsOf: url.appendingPathComponent("README.metadata.json")) else {
                    return nil
                }
                return try? decoder.decode(SampleMetadata.self, from: data)
            }
            .sorted { $0.title < $1.title }
    } catch {
        print("Error decoding Samples: \(error.localizedDescription)")
        exit(1)
    }
}()

private let sampleStructs = sampleMetadata
    .map { sample in
        let portalItemIDs = (sample.offlineData ?? [])
            .map { #"PortalItem.ID("\#($0)")!"# }
        return """
        struct \(sample.structName): Sample {
            var name: String { \"\(sample.title)\" }
            var description: String { \"\(sample.description)\" }
            var dependencies: Set<PortalItem.ID> { [\(portalItemIDs.joined(separator: ", "))] }
            var tags: Set<String> { \(sample.keywords) }
            var hasDependency: Bool { \(portalItemIDs.isEmpty) }
            
            func makeBody() -> AnyView { .init(\(sample.viewName)()) }
        }
        """
    }
    .joined(separator: "\n")

private let entries = sampleMetadata
    .map { sample in "\(sample.structName)()" }
    .joined(separator: ",\n        ")
private let arrayRepresentation = """
    [
            \(entries)
        ]
    """

do {
    let templateFile = try String(contentsOf: templateURL, encoding: .utf8)
    // Replaces the empty array code stub, i.e. [], with the array representation.
    let content = templateFile
        .replacingOccurrences(of: "[/* samples */]", with: arrayRepresentation)
        .replacingOccurrences(of: "/* structs */", with: sampleStructs)
    try content.write(to: outputFileURL, atomically: true, encoding: .utf8)
} catch {
    print("Error reading or writing template file: \(error.localizedDescription)")
    exit(1)
}
