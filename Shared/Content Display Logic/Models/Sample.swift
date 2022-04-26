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

struct Sample {
    var name: String
    var description: String
    var viewName: String
    var dependencies: [String]
    
    var view: AnyView {
        SamplesApp.samplesMapping[name]!
    }
}

extension Sample: Decodable {
    enum CodingKeys: String, CodingKey {
        case name = "displayName"
        case description = "descriptionText"
        case viewName = "viewName"
        case dependencies = "dependency"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
        description = try values.decode(String.self, forKey: .description)
        viewName = try values.decode(String.self, forKey: .viewName)
        dependencies = try values.decodeIfPresent([String].self, forKey: .dependencies) ?? []
    }
}

extension Sample: Identifiable {
    var id: String { name }
}

extension Sample {
    var readmeURL: URL? {
        return Bundle.main.url(forResource: "README", withExtension: "md", subdirectory: name)
    }
}
