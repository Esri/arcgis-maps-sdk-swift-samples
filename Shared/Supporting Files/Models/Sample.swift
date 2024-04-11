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
    
    /// The tags of the sample.
    var tags: Set<String> { get }
    
    /// A Boolean value that indicates whether a sample has offline data dependencies.
    var hasDependencies: Bool { get }
    
    /// Creates the view for the sample.
    func makeBody() -> AnyView
}

// MARK: Computed Variables

extension Sample {
    /// The URL to a sample's sub-directory on GitHub main branch.
    var gitHubURL: URL {
        URL(string: "https://github.com/Esri/arcgis-maps-sdk-swift-samples/tree/main/Shared/Samples")!
            .appendingPathComponent(name)
    }
    
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
}
