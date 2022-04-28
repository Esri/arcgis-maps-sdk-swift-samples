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
    /// The search term in the search bar.
    @Binding var searchTerm: String
    /// The samples to display in the list. Searching adjusts this value.
    private var displayedSamples: [Sample] {
        if searchTerm.isEmpty {
            return samples
        } else {
            return samples.filter { $0.name.localizedCaseInsensitiveContains(searchTerm) }
        }
    }
    
    var body: some View {
        List(displayedSamples) { sample in
            NavigationLink(sample.name, destination: SampleDetailView(sample: sample))
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    print("Info button was tapped")
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
    }
}
