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
struct Sample {
    /// The name of the sample.
    let name: String
    /// The category in which the sample belongs.
    let category: String
    /// A brief description of the sample's functionalities.
    let description: String
    /// The relative paths to the code snippets.
    let snippets: [String]
    /// The tags of the sample.
    let tags: Set<String>
    /// A Boolean value that indicates whether a sample has offline data dependencies.
    let hasDependencies: Bool
    /// A Boolean value indicating whether a sample has an action that needs to
    /// be performed when its view disappears.
    let hasTeardown: Bool
    /// The view for this example.
    var view: AnyView { content() }
    
    /// A closure that builds the view for this example.
    private let content: () -> AnyView
    
    init<Content: View>(
        name: String,
        category: String,
        description: String,
        snippets: [String],
        tags: Set<String>,
        hasDependencies: Bool,
        hasTeardown: Bool,
        content: @autoclosure @escaping () -> Content
    ) {
        self.name = name
        self.category = category
        self.description = description
        self.snippets = snippets
        self.tags = tags
        self.hasDependencies = hasDependencies
        self.hasTeardown = hasTeardown
        self.content = { .init(content()) }
    }
}

extension Sample: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.name == rhs.name
    }
}

extension Sample: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

extension Sample: Identifiable {
    var id: String { name }
}

// MARK: Computed Properties

extension Sample {
    /// The web URL to the sample's Esri Developer page.
    var esriDeveloperURL: URL {
        let dashedName = name
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
        return URL(string: "https://developers.arcgis.com/swift/sample-code")!
            .appending(component: dashedName)
    }
    
    /// The URL to a sample's sub-directory on GitHub main branch.
    var gitHubURL: URL {
        URL(string: "https://github.com/Esri/arcgis-maps-sdk-swift-samples/tree/main/Shared/Samples")!
            .appending(component: name)
    }
    
    /// The URL to a sample's `README.md` file.
    var readmeURL: URL {
        Bundle.main.url(
            forResource: "README",
            withExtension: "md",
            subdirectory: "Samples/\(name)"
        )!
    }
    
    /// The URLs to a sample's source code files.
    var snippetURLs: [URL] {
        snippets.compactMap { snippet in
            Bundle.main.url(
                forResource: snippet,
                withExtension: nil,
                subdirectory: "Samples/\(name)"
            )
        }
    }
    
    /// The on-demand resource tags for this sample.
    var odrTags: Set<String> {
        guard hasDependencies else { return [] }
        return [name.upperCamelCased()]
    }
}
