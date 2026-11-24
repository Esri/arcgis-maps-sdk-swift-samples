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
    /// A Boolean value indicating whether a sample has an action that needs to
    /// be performed when its view disappears.
    let hasTeardown: Bool? // swiftlint:disable:this discouraged_optional_boolean
}

extension SampleMetadata {
    /// The name of the static member of the `Sample` type for this sample.
    var memberName: String {
        let upperCamelCase = viewName.dropLast(4)
        return upperCamelCase.first!.lowercased() + upperCamelCase.dropFirst()
    }
    
    /// The SwiftUI View name of the root view of the sample. It is the same as
    /// the first filename without extension in the snippets array.
    var viewName: Substring {
        // E.g., ["DisplayMapView.swift", "SomeView.swift"] -> DisplayMapView
        snippets.first!.dropLast(6)
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

let samplesDirectoryURL = URL(filePath: arguments[1], directoryHint: .isDirectory)
let templateURL = URL(filePath: arguments[2], directoryHint: .notDirectory)
let outputFileURL = URL(filePath: arguments[3], directoryHint: .notDirectory)

private let sampleMetadata: [SampleMetadata] = {
    let decoder = JSONDecoder()
    // Converts snake-case key "offline_data" to camel-case "offlineData".
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    
    let fileManager = FileManager.default
    do {
        // Does a shallow traverse of the top level of samples directory.
        return try fileManager
            .contentsOfDirectory(at: samplesDirectoryURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            .compactMap { url in
                guard url.hasDirectoryPath else { return nil }
                
                // Gets the metadata JSON under each subdirectory.
                let metadataFile = url.appending(component: "README.metadata.json")
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
            .sorted(by: { $0.title < $1.title })
    } catch {
        print("error: Decoding Samples: \(error.localizedDescription)")
        exit(1)
    }
}()

private var sampleExtension: String {
    let staticMembers = sampleMetadata
        .map { sample in
            let member = """
                    static var \(sample.memberName): Self {
                        Self(
                            name: \"\(sample.title)\",
                            category: \"\(sample.category)\",
                            description: \"\(sample.description)\",
                            snippets: \(sample.snippets),
                            tags: \(sample.tags),
                            hasDependencies: \(!(sample.offlineData ?? []).isEmpty),
                            hasTeardown: \(sample.hasTeardown ?? false),
                            content: \(sample.viewName)()
                        )
                    }
                """
            return if sample.category == "Augmented Reality" {
                """
                    @available(macCatalyst, unavailable)
                \(member /* Already indented. */)
                """
            } else {
                member
            }
        }
        .joined(separator: "\n    \n")
    return """
        @MainActor
        private extension Sample {
        \(staticMembers /* Already indented. */)
        }
        """
}

// The set of samples supported on all supported platforms.
private let commonSamples = sampleMetadata
    .filter { $0.category != "Augmented Reality" }
    .map { sample in ".\(sample.memberName)" }
    .joined(separator: ",\n            ")

// The set of samples supported only on iOS.
private let iOSSpecificSamples = sampleMetadata
    .filter { $0.category == "Augmented Reality" }
    .map { "            .\($0.memberName)" }
    .joined(separator: ",\n")

private let commonSamplesArrayRepresentation = """
            [
                \(commonSamples)
            ]
    """

private let iOSSamplesArrayRepresentation = """
    #if !targetEnvironment(macCatalyst) && !targetEnvironment(simulator)
            // Exclude AR samples from Mac Catalyst and Simulator targets
            // as they don't have camera and sensors available.
            [
    \(iOSSpecificSamples /* Already indented. */)
            ]
    #else
            []
    #endif
    """

do {
    let templateFile = try String(contentsOf: templateURL, encoding: .utf8)
    // Replaces the empty array code stub, i.e. [], with the array representation.
    let content = templateFile
        .replacingOccurrences(of: "/* common_samples */", with: commonSamplesArrayRepresentation)
        .replacingOccurrences(of: "/* ios_samples */", with: iOSSamplesArrayRepresentation)
        .replacingOccurrences(of: "/* samples */", with: sampleExtension)
    try content.write(to: outputFileURL, atomically: true, encoding: .utf8)
} catch {
    print("error: Reading or writing template file: \(error.localizedDescription)")
    exit(1)
}
