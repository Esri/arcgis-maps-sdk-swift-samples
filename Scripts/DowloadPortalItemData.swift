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

// This script downloads portal item data. It takes 2 arguments.
// - The first is a path to the samples directory, $SRCROOT/Shared/Samples.
// - The second is a path to the download directory, $SRCROOT/Portal Data.
//
// A mapping of item IDs to filenames is maintained in the download directory.
// This mapping efficiently checks whether an item has already been downloaded.
// If an item already exists, it will skip that item.
// To delete and re-downloaded an item, remove its entry from the plist.

import Foundation

// MARK: Model

/// A sample's dependencies retrieved from its `README.metadata.json` file.
struct SampleDependency: Decodable {
    /// The ArcGIS Online Portal Item IDs.
    let offlineData: [PortalItem]
}

/// A Portal Item and its data URL.
struct PortalItem: Hashable {
    static let arcGISOnlinePortalURL = URL(string: "https://www.arcgis.com")!
    
    /// The identifier of the item.
    let identifier: String
    
    /// A URL constructed with the default ArcGIS Portal and portal item ID,
    /// such as `{portalURL}/sharing/rest/content/items/{itemIdentifier}/data`
    /// for the given item in the given portal.
    var dataURL: URL {
        return Self.arcGISOnlinePortalURL
            .appendingPathComponent("sharing")
            .appendingPathComponent("rest")
            .appendingPathComponent("content")
            .appendingPathComponent("items")
            .appendingPathComponent(identifier)
            .appendingPathComponent("data")
    }
}

extension PortalItem: Decodable {
    init(from decoder: Decoder) throws {
        self.init(identifier: try String(from: decoder))
    }
}

// MARK: Helper Functions

/// Parses a `README.metadata.json` to a `SampleDependency` struct.
/// - Parameter url: The URL to the metadata JSON file.
/// - Throws: Exceptions for unable to find or decode JSON data.
/// - Returns: A `SampleDependency` object.
private func parseJSON(at url: URL) throws -> SampleDependency {
    let data = try Data(contentsOf: url)
    // Finds all subdirectories under the root samples directory.
    let decoder = JSONDecoder()
    // Converts snake-case key "offline_data" to camel-case "offlineData".
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(SampleDependency.self, from: data)
}

/// Returns the name of the file in a ZIP archive at the given URL.
/// - Parameter url: The URL to a ZIP archive, assuming it only contains 1 file.
/// - Throws: Exceptions when running the `zipinfo` process.
/// - Returns: The filename.
func name(ofFileInArchiveAt url: URL) throws -> String {
    let outputPipe = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/zipinfo", isDirectory: false)
    process.arguments = ["-1", url.path]
    process.standardOutput = outputPipe
    try process.run()
    process.waitUntilExit()
    
    let filenameData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: filenameData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Counts files in a ZIP archive.
/// - Parameter url: The URL to a ZIP archive.
/// - Throws: Exceptions when running the `zipinfo` process.
/// - Returns: The file count in the archive.
func count(ofFilesInArchiveAt url: URL) throws -> Int {
    let outputPipe = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/zipinfo", isDirectory: false)
    process.arguments = ["-t", url.path]
    process.standardOutput = outputPipe
    try process.run()
    process.waitUntilExit()
    
    // The totals info looks something like
    // "28 files, 1382747 bytes uncompressed, 1190007 bytes compressed:  13.9%"
    // To extract the count, cut the string at the first whitespace.
    let totalsInfo = outputPipe.fileHandleForReading.readDataToEndOfFile()
    // `UInt8(32)` is space in ASCII.
    let totalsCount = String(data: totalsInfo.prefix(while: { $0 != 32 }), encoding: .utf8)!
    return Int(totalsCount)!
}

/// Uncompresses a ZIP archive at the source URL into the destination URL.
/// - Parameters:
///   - sourceURL: The URL to a ZIP archive.
///   - destinationURL: The URL at which to uncompress the archive.
/// - Throws: Exceptions when running the `unzip` process.
func uncompressArchive(at sourceURL: URL, to destinationURL: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip", isDirectory: false)
    // Unzips the archive into a specified sub-folder and silence the output.
    process.arguments = ["-q", sourceURL.path, "-d", destinationURL.path]
    try process.run()
    process.waitUntilExit()
}

/// Downloads a file from a URL to a given location.
/// - Parameters:
///   - sourceURL: The portal URL to the resource.
///   - downloadDirectory: The directory to store the downloaded data in.
/// - Throws: Exceptions when downloading, naming, uncompressing, and moving the file.
/// - Returns: The name of the downloaded file.
func downloadFile(from sourceURL: URL, to downloadDirectory: URL) async throws -> String? {
    let (temporaryURL, response) = try await URLSession.shared.download(from: sourceURL)
    
    guard let suggestedFilename = response.suggestedFilename else { return nil }
    let isArchive = NSString(string: suggestedFilename).pathExtension == "zip"
    
    let downloadName: String = try {
        // If the downloaded file is an archive and contains
        //   - 1 file, use the name of that file.
        //   - multiple files, use the server suggested filename (*.zip).
        // If it is not an archive, use the server suggested filename.
        if isArchive,
           try count(ofFilesInArchiveAt: temporaryURL) == 1 {
            return try name(ofFileInArchiveAt: temporaryURL)
        } else {
            return suggestedFilename
        }
    }()
    let downloadURL = downloadDirectory.appendingPathComponent(downloadName, isDirectory: false)
    
    try? FileManager.default.removeItem(at: downloadURL)
    
    if isArchive {
        let extractURL = downloadURL.pathExtension == "zip"
        // Uncompresses to directory named after archive.
        ? downloadURL.deletingPathExtension()
        // Uncompresses to appropriate subdirectory.
        : downloadURL.deletingLastPathComponent()
        
        try uncompressArchive(at: temporaryURL, to: extractURL)
    } else {
        try FileManager.default.moveItem(at: temporaryURL, to: downloadURL)
    }
    
    return downloadName
}

// MARK: Script Entry

let arguments = CommandLine.arguments

guard arguments.count == 3 else {
    print("error: Invalid number of arguments.")
    exit(1)
}

/// The samples directory, i.e., $SRCROOT/Shared/Samples.
let samplesDirectoryURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
/// The download directory, i.e., $SRCROOT/Portal Data.
let downloadDirectoryURL = URL(fileURLWithPath: arguments[2], isDirectory: true)

// If the download directory does not exist, create it.
if !FileManager.default.fileExists(atPath: downloadDirectoryURL.path) {
    do {
        try FileManager.default.createDirectory(at: downloadDirectoryURL, withIntermediateDirectories: false)
    } catch {
        print("error: Error creating download directory: \(error.localizedDescription).")
        exit(1)
    }
}

/// Portal Items created from iterating through all metadata's "offline\_data".
let portalItems: Set<PortalItem> = {
    do {
        // Finds all subdirectories under the root Samples directory.
        let sampleSubDirectories = try FileManager.default
            .contentsOfDirectory(at: samplesDirectoryURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            .filter(\.hasDirectoryPath)
        let sampleJSONs = sampleSubDirectories
            .map { $0.appendingPathComponent("README.metadata.json", isDirectory: false) }
        // Omit the decoding errors from samples that don't have dependencies.
        let sampleDependencies = sampleJSONs
            .compactMap { try? parseJSON(at: $0) }
        return Set(sampleDependencies.lazy.flatMap(\.offlineData))
    } catch {
        print("error: Error decoding Samples dependencies: \(error.localizedDescription)")
        exit(1)
    }
}()

typealias Identifier = String
typealias Filename = String
typealias DownloadedItems = [Identifier: Filename]

/// The URL to a property list that maintains records of downloaded resources.
let downloadedItemsURL = downloadDirectoryURL.appendingPathComponent(".downloaded_items.plist", isDirectory: false)
let previousDownloadedItems: DownloadedItems = {
    do {
        let data = try Data(contentsOf: downloadedItemsURL)
        return try PropertyListDecoder().decode(DownloadedItems.self, from: data)
    } catch {
        return [:]
    }
}()
var downloadedItems = previousDownloadedItems

await withTaskGroup(of: Void.self) { group in
    for portalItem in portalItems {
        let destinationURL = downloadDirectoryURL.appendingPathComponent(
            portalItem.identifier,
            isDirectory: true
        )
        
        // Checks to see if an item needs downloading.
        guard downloadedItems[portalItem.identifier] == nil ||
                !FileManager.default.fileExists(atPath: destinationURL.path) else {
            print("note: Item already downloaded: \(portalItem.identifier)")
            continue
        }
        
        // Deletes the directory when the item is not in the plist.
        try? FileManager.default.removeItem(at: destinationURL)
        
        do {
            // Creates an enclosing directory with the portal item ID as its name.
            try FileManager.default.createDirectory(
                at: destinationURL,
                withIntermediateDirectories: false
            )
        } catch {
            print("error: Error creating download directory: \(error.localizedDescription)")
            exit(1)
        }
        
        group.addTask {
            do {
                guard let downloadName = try await downloadFile(
                    from: portalItem.dataURL,
                    to: destinationURL
                ) else { return }
                print("note: Downloaded item: \(portalItem.identifier)")
                fflush(stdout)
                
                _ = await MainActor.run {
                    downloadedItems.updateValue(downloadName, forKey: portalItem.identifier)
                }
            } catch {
                print("error: Error downloading item \(portalItem.identifier): \(error.localizedDescription)")
                URLSession.shared.invalidateAndCancel()
                exit(1)
            }
        }
    }
}

// Updates the downloaded items property list record if needed.
if downloadedItems != previousDownloadedItems {
    do {
        let data = try PropertyListEncoder().encode(downloadedItems)
        try data.write(to: downloadedItemsURL)
    } catch {
        print("error: Error recording downloaded items: \(error.localizedDescription)")
        exit(1)
    }
}
