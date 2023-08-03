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

struct SampleListView: View {
    /// All samples that will be displayed in the list.
    let samples: [Sample]
    
    /// The search query from the search bar.
    let query: String
    
    init(samples: [Sample], query: String = "") {
        self.samples = samples
        self.query = query
    }
    
    var body: some View {
        ForEach(samples, id: \.name) { sample in
            SampleRow(sample: sample, boldedText: query)
        }
    }
}

private extension SampleListView {
    struct SampleRow: View {
        /// The sample displayed in the row.
        let sample: Sample
        
        /// The text to bold.
        let boldedText: String
        
        /// A Boolean value that indicates whether to show the sample's description.
        @State private var isShowingDescription = false
        
        var body: some View {
            NavigationLink {
                SampleDetailView(sample: sample)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(.init(boldSubstring(sample.name, substring: boldedText)))
                        
                        if isShowingDescription {
                            Text(.init(boldSubstring(sample.description, substring: boldedText)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    Spacer()
                    Button {
                        isShowingDescription.toggle()
                    } label: {
                        Image(systemName: isShowingDescription ? "info.circle.fill" : "info.circle")
                    }
                    .buttonStyle(.borderless)
                }
                .animation(.easeOut(duration: 0.2), value: isShowingDescription)
            }
        }
        
        /// Bolds the first occurrence of substring within a given string using markdown.
        /// - Parameters:
        ///   - text: The `String` containing the substring.
        ///   - substring: The substring to bold.
        /// - Returns: The `String` with the bolded substring.
        private func boldSubstring(_ text: String, substring: String) -> String {
            if let range = text.range(
                of: substring.trimmingCharacters(in: .whitespacesAndNewlines),
                options: .caseInsensitive
            ) {
                var boldedText = text
                boldedText.replaceSubrange(range, with: "**" + text[range] + "**")
                return boldedText
            }
            return text
        }
    }
}
