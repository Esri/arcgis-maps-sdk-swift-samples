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

struct AnySample<Content: View> {
    let name: String
    let description: String
    let dependencies: Set<String>
    let tags: Set<String>
    /// A closure to create the sample's root view.
    let content: () -> Content
    
    init(
        name: String,
        description: String,
        dependencies: [String],
        tags: [String],
        content: @autoclosure @escaping () -> Content
    ) {
        // Make sample name in title case.
        self.name = name.capitalized
        self.description = description
        self.content = content
        self.dependencies = Set(dependencies)
        // Keep a distinct set of lowercased keyword tags.
        self.tags = Set(tags.map { $0.lowercased() })
    }
}

extension AnySample: Sample {
    func makeBody() -> AnyView { AnyView(content()) }
}
