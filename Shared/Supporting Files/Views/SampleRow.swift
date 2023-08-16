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

struct SampleRow: View {
    /// The name string of the sample with attributes.
    let name: AttributedString
    
    /// The description string of the sample with attributes.
    let description: AttributedString
    
    /// A Boolean value that indicates whether to show the sample's description.
    @State private var isShowingDescription = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name)
                
                if isShowingDescription {
                    Text(description)
                        .font(.caption)
                        .opacity(0.75)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            Spacer()
            Label {} icon: {
                Image(systemName: "info.circle")
                    .symbolVariant(isShowingDescription ? .fill : .none)
            }
            .onTapGesture {
                isShowingDescription.toggle()
            }
        }
        .animation(.easeOut(duration: 0.2), value: isShowingDescription)
    }
}

extension SampleRow {
    /// Creates a sample row.
    /// - Parameters:
    ///   - sample: The sample to display.
    ///   - query: A string to be bolded in the sample's name or description.
    init(sample: Sample, query: String) {
        self.init(
            name: sample.name.boldingFirstOccurrence(of: query),
            description: sample.description.boldingFirstOccurrence(of: query)
        )
    }
}

private extension String {
    /// Bolds the first occurrence of substring within the string using markdown.
    /// - Parameter substring: The substring to bold.
    /// - Returns: The attributed string with the bolded substring.
    func boldingFirstOccurrence(of substring: String) -> AttributedString {
        if let range = localizedStandardRange(of: substring.trimmingCharacters(in: .whitespacesAndNewlines)),
           let boldedString = try? AttributedString(markdown: replacingCharacters(in: range, with: "**\(self[range])**")) {
            return boldedString
        } else {
            return AttributedString(self)
        }
    }
}
