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
    /// Searches the samples using the sample's name and the query.
    /// - Returns: The samples whose name partially matches the query.
    func searchSamplesNames() -> [Sample] {
        // Return all the samples when query is empty.
        guard !query.isEmpty else { return samples }
        
        // Preform a partial text search using the sample's name and the query.
        let nameSearchResults = samples.filter { sample in
            sample.name.localizedCaseInsensitiveContains(query)
        }
        return nameSearchResults
    }
    
    /// Searches the samples using the sample's description and the query.
    /// - Returns: The samples whose description partially matches the query.
    func searchSamplesDescriptions() -> [Sample] {
        // The samples already found by name with query.
        let previousSearchResults = searchSamplesNames()
        
        // Preform a partial text search using the sample's description and
        // the query for the samples that are not already found.
        let descriptionSearchResults = samples.filter { sample in
            sample.description.localizedCaseInsensitiveContains(query) &&
            !previousSearchResults.contains { searchResultSample in
                searchResultSample.name == sample.name
            }
        }
        return descriptionSearchResults
    }
    
    /// Searches the samples using the sample's tags and the query.
    /// - Returns: The samples which have a tag that fully matches the query.
    func searchSamplesTags() -> [Sample] {
        // The samples already found by name or description with query.
        let previousSearchResults = searchSamplesNames() + searchSamplesDescriptions()
        
        // Preform a full text search using the sample's tags and the query for
        // the samples that are not already found.
        let tagsSearchResults = samples.filter { sample in
            sample.tags.contains { tag in
                tag.localizedCaseInsensitiveCompare(query) == .orderedSame
            } && !previousSearchResults.contains { searchResultSample in
                searchResultSample.name == sample.name
            }
        }
        return tagsSearchResults
    }
}
