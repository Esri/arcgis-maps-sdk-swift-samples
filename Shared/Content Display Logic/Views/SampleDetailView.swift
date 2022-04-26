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

struct SampleDetailView: View {
    /// The sample to display in the view.
    var sample: Sample?
    
    var body: some View {
        if let sample = sample {
            sample.view
                .navigationTitle(sample.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            print("Info button was tapped")
                        } label: {
                            Image(systemName: "info.circle")
                        }
                    }
                }
        } else {
            Text("Select a sample from the list.")
        }
    }
}

extension SampleDetailView: Identifiable {
    var id: String { sample?.name ?? "" }
}
