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
import ArcGIS

struct ContentView: View {
    /// All samples decoded from the plist.
    let samples: [Sample]
    /// The search term in the search bar.
    @State private var searchTerm = ""
    
    var body: some View {
        NavigationView {
            SampleListView(samples: samples, searchTerm: $searchTerm)
                .navigationTitle("Samples")
            Text("Select a sample from the list.")
        }
        .searchable(text: $searchTerm, prompt: "Search By Sample Name")
    }
}
