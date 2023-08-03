// Copyright 2023 Esri
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

extension CategoryView {
    /// Searches through a list of samples using the sample's name and the query.
    /// - Parameters:
    ///   - samples: The `Array` of samples to search through.
    ///   - query: The `String` to search with.
    /// - Returns: The samples whose name partially matches the query.
    func searchNames(in samples: [Sample], with query: String) -> [Sample] {
        // Perform a partial text search using the sample's name and the query.
        samples.filter { sample in
            sample.name.localizedCaseInsensitiveContains(query)
        }
    }
    
    /// Searches through a list of samples using the sample's description and the query.
    /// - Parameters:
    ///   - samples: The `Array` of samples to search through.
    ///   - query: The `String` to search with.
    /// - Returns: The samples whose description partially matches the query.
    func searchDescriptions(in samples: [Sample], with query: String) -> [Sample] {
        // Perform a partial text search using the sample's description and the query.
        samples.filter { sample in
            sample.description.localizedCaseInsensitiveContains(query)
        }
    }
    
    /// Searches through a list of samples using the sample's tags and the query.
    /// - Parameters:
    ///   - samples: The `Array` of samples to search through.
    ///   - query: The `String` to search with.
    /// - Returns: The samples which have a tag that fully matches the query.
    func searchTags(in samples: [Sample], with query: String) -> [Sample] {
        // Perform a full text search using the sample's tags and the query.
        samples.filter { sample in
            sample.tags.contains { tag in
                tag.localizedCaseInsensitiveCompare(query) == .orderedSame
            }
        }
    }
}
