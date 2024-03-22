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
    /// The category of the sample.
    let category: String
    /// The description of the sample.
    let description: String
    /// The relative paths to the code snippets.
    let snippets: [String]
    /// The ArcGIS Online Portal Item IDs.
    let offlineData: [String]?
    /// The tags and relevant APIs of the sample.
    let keywords: [String]
    /// The relevant APIs of the sample.
    let relevantApis: [String]
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
    
    /// The tags of a sample.
    /// - Note: See common-samples/wiki/README.metadata.json#keywords.
    /// The keywords in the sample metadata combines Tags and Relevant APIs
    /// from the README. This is done in Scripts/CI/common.py by appending the
    /// relevant APIs to the tags. Therefore, dropping the relevant APIs will
    /// give the tags.
    var tags: Array<String>.SubSequence {
        keywords.dropLast(relevantApis.count)
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
    let decoder = JSONDecoder()
    // Converts snake-case key "offline_data" to camel-case "offlineData".
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    
    let fileManager = FileManager.default
    do {
        // Does a shallow traverse of the top level of samples directory.
        return try fileManager.contentsOfDirectory(at: samplesDirectoryURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            .filter(\.hasDirectoryPath)
            .compactMap { url in
                // Gets the metadata JSON under each subdirectory.
                let metadataFile = url.appendingPathComponent("README.metadata.json")
                guard fileManager.fileExists(atPath: metadataFile.path) else {
                    // Sometimes when Git switches branches, it leaves an empty directory
                    // that causes the decoder to throw an error. Here we skip the directories
                    // that don't have the metadata JSON file.
                    return nil
                }
                do {
                    let data = try Data(contentsOf: metadataFile)
                    return try decoder.decode(SampleMetadata.self, from: data)
                } catch {
                    print("error: '\(url.lastPathComponent)' sample couldn’t be decoded.")
                    exit(1)
                }
            }
            .sorted { $0.title < $1.title }
    } catch {
        print("error: Decoding Samples: \(error.localizedDescription)")
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
            var category: String { \"\(sample.category)\" }
            var description: String { \"\(sample.description)\" }
            var snippets: [String] { \(sample.snippets) }
            var tags: Set<String> { \(sample.tags) }
            \(portalItemIDs.isEmpty ? "" : "var hasDependencies: Bool { true }\n")
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
    #if targetEnvironment(macCatalyst) || targetEnvironment(simulator)
        // Exclude AR samples from Mac Catalyst and Simulator targets
        // as they don't have camera and sensors available.
        .filter { $0.category != "Augmented Reality" }
    #endif
    """

do {
    let templateFile = try String(contentsOf: templateURL, encoding: .utf8)
    // Replaces the empty array code stub, i.e. [], with the array representation.
    let content = templateFile
        .replacingOccurrences(of: "[/* samples */]", with: arrayRepresentation)
        .replacingOccurrences(of: "/* structs */", with: sampleStructs)
    try content.write(to: outputFileURL, atomically: true, encoding: .utf8)
} catch {
    print("error: Reading or writing template file: \(error.localizedDescription)")
    exit(1)
}
