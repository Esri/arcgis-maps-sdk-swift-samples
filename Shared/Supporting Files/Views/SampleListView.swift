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

struct SampleListView: View {
    /// All samples that will be displayed in the list.
    let samples: [Sample]
    
    /// A Boolean value indicating whether the row description should include
    /// the sample's category. We only need this information when the samples
    /// in the list are from different categories.
    let shouldShowCategory: Bool
    
    var body: some View {
        List(samples, id: \.name) { sample in
            SampleRow(sample: sample, shouldShowCategory: shouldShowCategory)
        }
    }
}

private extension SampleListView {
    struct SampleRow: View {
        /// The sample displayed in the row.
        let sample: Sample
        
        /// A Boolean value that indicates whether to show the sample's category.
        let shouldShowCategory: Bool

        var body: some View {
            DisclosureGroup {
                VStack(alignment: .leading) {
                    if shouldShowCategory {
                        Text("Category: \(sample.category)")
                            .bold()
                    }
                    Text(sample.description)
                        .foregroundColor(.secondary)
                }
                .listRowSeparator(.hidden)
                .font(.caption)
            } label: {
                NavigationLink(sample.name) {
                    SampleDetailView(sample: sample)
                }
            }
        }
    }
}
