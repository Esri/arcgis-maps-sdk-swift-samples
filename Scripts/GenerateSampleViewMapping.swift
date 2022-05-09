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
import OSLog

// MARK: Model

/// A sample metadata retrieved from its `README.metadata.json` file.
/// - Note: More about the schema at `common-samples/wiki/README.metadata.json`.
private struct SampleMetadata {
    /// The title of the sample.
    let title: String
    /// The description of the sample.
    let description: String
    /// The relative paths to the code snippets.
    let snippets: [String]
    /// The ArcGIS Online Portal Item IDs.
    let offline_data: [String]
    /// The tags and relevant APIs of the sample.
    let keywords: [String]
}

extension SampleMetadata {
    /// The SwiftUI View name of the root view of the sample. It is the same as
    /// the first filename without extension in the snippets array.
    var viewName: String {
        // E.g., ["DisplayMapView.swift", "SomeView.swift"] -> DisplayMapView
        snippets.first!.components(separatedBy: ".").first!
    }
}

// MARK: Methods

/// Generate a string representation of an array.
/// - Parameter array: An array of strings.
/// - Returns: A Swift code representation of a string array.
private func arrayRepresentation(from array: [String]) -> String {
    "[\(array.map { "\"\($0)\"" }.joined(separator: ", "))]"
}



// MARK: Script Entry

private let arguments = CommandLine.arguments
private let logger = Logger()

guard arguments.count == 4 else {
    logger.error("Invalid number of arguments.")
    exit(1)
}

let samplesDirectoryURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
let templateURL = URL(fileURLWithPath: arguments[2], isDirectory: false)
let outputFileURL = URL(fileURLWithPath: arguments[3], isDirectory: false)

private let samples: [Sample] = {
    do {
        // Find all subdirectories under the root Samples directory.
        let sampleSubDirectories = try FileManager.default.contentsOfDirectory(at: samplesDirectoryURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).filter(\.hasDirectoryPath)
        
        let decoder = JSONDecoder()
        func parseJSON(at url: URL) -> Sample? {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(SampleMetadata.self, from: data)
        }
        
        let samples = sampleSubDirectories.map { $0.appendingPathComponent("README.metadata.json") }.compactMap(parseJSON(at:))
        return samples
    } catch {
        logger.error("Error decoding Samples: \(error.localizedDescription)")
        exit(1)
    }
}()

private let entries = samples.map { sample in "AnySample(name: \"\(sample.name)\", description: \"\(sample.description)\", dependencies: \(sample.dependencies), tags: \(sample.tags), content: \(sample.viewName)())" }.joined(separator: ", ")
private let arrayRepresentation = "[\(entries)]"

do {
    let templateFile = try String(contentsOf: templateURL, encoding: .utf8)
    // Replace the empty array code stub, i.e. [], with the array representation.
    let content = templateFile.replacingOccurrences(of: "[]", with: arrayRepresentation)
    try content.write(to: outputFileURL, atomically: true, encoding: .utf8)
} catch {
    logger.error("Error reading or writing template file: \(error.localizedDescription)")
    exit(1)
}
