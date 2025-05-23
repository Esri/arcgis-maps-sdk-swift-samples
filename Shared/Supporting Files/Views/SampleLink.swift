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

struct SampleLink: View {
    /// The sample to present.
    private let sample: Sample
    
    /// The text to bold in the sample's name and description.
    private let textToBold: String
    
    /// Creates a link that presents a given sample.
    /// - Parameters:
    ///   - sample: The sample to present.
    ///   - textToBold: The text to bold in the sample's name and description.
    init(_ sample: Sample, textToBold: String = "") {
        self.sample = sample
        self.textToBold = textToBold
    }
    
    var body: some View {
        NavigationLink {
            SampleDetailView(sample: sample)
                .id(sample.name)
        } label: {
            SampleRow(sample, textToBold: textToBold)
        }
    }
}

private extension SampleLink {
    struct SampleRow: View {
        /// The sample for the row.
        private let sample: Sample
        
        /// The name of the sample with attributes.
        private let attributedName: AttributedString
        
        /// The description of the sample with attributes.
        private let attributedDescription: AttributedString
        
        /// A Boolean value indicating whether the sample's description is showing.
        @State private var isShowingDescription = false
        
        /// The names of the favorite samples loaded from user defaults.
        @AppFavorites private var favoriteNames
        
        init(_ sample: Sample, textToBold: String) {
            self.sample = sample
            self.attributedName = sample.name.boldingFirstOccurrence(of: textToBold)
            self.attributedDescription = sample.description.boldingFirstOccurrence(of: textToBold)
        }
        
        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text(attributedName)
                    
                    if isShowingDescription {
                        Text(attributedDescription)
                            .font(.caption)
                            .opacity(0.75)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                Spacer()
                
                if favoriteNames.contains(sample.name) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
                
                Label {} icon: {
                    Image(systemName: "info.circle")
                        .symbolVariant(isShowingDescription ? .fill : .none)
                        .imageScale(.medium)
                }
                .onTapGesture {
                    isShowingDescription.toggle()
                }
            }
            .contextMenu {
                SampleMenuButtons(sample: sample)
            }
            .animation(.easeOut(duration: 0.2), value: isShowingDescription)
        }
    }
}

private extension String {
    /// Bolds the first occurrence of substring within the string using markdown.
    /// - Parameter substring: The substring to bold.
    /// - Returns: The attributed string with the bolded substring.
    func boldingFirstOccurrence(of substring: String) -> AttributedString {
        var attributedString = AttributedString(self)
        
        let trimmedSubstring = substring.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = localizedStandardRange(of: trimmedSubstring),
           let boldedSubstring = try? AttributedString(markdown: "**\(self[range])**"),
           let attributedRange = attributedString.range(of: self[range]) {
            attributedString.replaceSubrange(attributedRange, with: boldedSubstring)
        }
        
        return attributedString
    }
}
