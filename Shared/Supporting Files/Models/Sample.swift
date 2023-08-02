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

import SwiftUI

/// A type that represents a sample in the sample viewer.
protocol Sample {
    /// The name of the sample.
    var name: String { get }
    
    /// The category in which the sample belongs.
    var category: String { get }
    
    /// A brief description of the sample's functionalities.
    var description: String { get }
    
    /// The relative paths to the code snippets.
    var snippets: [String] { get }
    
    /// The tags and relevant APIs of the sample.
    var tags: Set<String> { get }
    
    /// A Boolean value that indicates whether a sample has offline data dependencies.
    var hasDependencies: Bool { get }
    
    /// Creates the view for the sample.
    func makeBody() -> AnyView
}

// MARK: Computed Variables

extension Sample {
    /// The URL to a sample's `README.md` file.
    var readmeURL: URL {
        Bundle.main.url(forResource: name, withExtension: "md", subdirectory: "READMEs")!
    }
    
    /// The URLs to a sample's source code files.
    var snippetURLs: [URL] {
        snippets.compactMap { Bundle.main.url(forResource: $0, withExtension: nil) }
    }
    
    /// The sample's name in UpperCamelCase.
    /// - Note: For example, "Display map" -> "DisplayMap".
    var nameInUpperCamelCase: String {
        name.capitalized.filter { !$0.isWhitespace }
    }
    
    /// By default, a sample doesn't have dependencies.
    var hasDependencies: Bool { false }
    
    /// A Boolean value that indicates whether the sample is favorited.
    var isFavorited: Bool {
        get {
            UserDefaults.standard.favoriteSamples.contains(name)
        }
        nonmutating set {
            if newValue {
                UserDefaults.standard.favoriteSamples.append(name)
            } else {
                UserDefaults.standard.favoriteSamples.removeAll(where: { $0 == name })
            }
        }
    }
}

extension UserDefaults {
    /// The user defaults key for the favorite samples.
    static let favoriteSamplesKey = "favoriteSamples"
    
    /// The names of the favorite samples.
    var favoriteSamples: [String] {
        get {
            Array(rawValue: string(forKey: Self.favoriteSamplesKey) ?? "") ?? []
        }
        set {
            set(newValue.rawValue, forKey: Self.favoriteSamplesKey)
        }
    }
}

extension Array: RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else { return nil }
        self = result
    }

    /// The raw value of the array.
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else { return "[]" }
        return result
    }
}
