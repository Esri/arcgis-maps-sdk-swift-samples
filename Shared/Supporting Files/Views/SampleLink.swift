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
            SampleRow(
                name: sample.name.boldingFirstOccurrence(of: textToBold),
                description: sample.description.boldingFirstOccurrence(of: textToBold)
            )
        }
    }
}

private extension SampleLink {
    struct SampleRow: View {
        /// The name of the sample.
        private let name: String
        
        /// The name of the sample with attributes.
        private let attributedName: AttributedString
        
        /// The description of the sample with attributes.
        private let attributedDescription: AttributedString
        
        /// A Boolean value indicating whether the sample's description is showing.
        @State private var isShowingDescription = false
        
        /// The names of the favorite samples loaded from user defaults.
        @AppStorage(.favoriteSampleNames) private var favoriteNames: [String] = []
        
        /// A Boolean value indicating whether the sample is a favorite.
        private var sampleIsFavorite: Bool {
            favoriteNames.contains(name)
        }
        
        init(name: AttributedString, description: AttributedString) {
            self.name = String(name.characters)
            self.attributedName = name
            self.attributedDescription = description
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
                
                if sampleIsFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
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
                Button {
                    if sampleIsFavorite {
                        favoriteNames.removeAll { $0 == name }
                    } else {
                        favoriteNames.append(name)
                    }
                } label: {
                    Label(sampleIsFavorite ? "Unfavorite" : "Favorite", systemImage: "star")
                        .symbolVariant(sampleIsFavorite ? .slash : .none)
                }
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
        if let range = localizedStandardRange(of: substring.trimmingCharacters(in: .whitespacesAndNewlines)),
           let boldedString = try? AttributedString(markdown: replacingCharacters(in: range, with: "**\(self[range])**")) {
            return boldedString
        } else {
            return AttributedString(self)
        }
    }
}
